class WorkoutsController < ApplicationController
  before_action :require_authentication, except: [ :sunday ]
  before_action :set_owned_workout, only: [ :edit, :update, :clone ]
  rate_limit to: 10, within: 3.minutes, only: :create
  rate_limit to: 20, within: 1.minute, only: :scale

  # GET /library
  def index
    @tab = params[:tab] == "shared" ? "shared" : "mine"

    if @tab == "shared"
      @shared_items = Current.user.shares_received
                             .includes(:sender, :shareable)
                             .order(created_at: :desc)
    else
      @programs  = Current.user.programs.order(created_at: :desc)
      @workouts  = Current.user.workouts
                         .where.not(id: ProgramWorkout.where.not(workout_id: nil).select(:workout_id))
                         .includes(:tags, :activity)
                         .order(created_at: :desc)
      if params[:activity].present?
        @activity_filter = params[:activity]
        @workouts = @workouts.joins(:activity).where(activities: { name: params[:activity] })
      elsif params[:tag_id].present?
        @tag = Tag.find_by(id: params[:tag_id])
        @workouts = @workouts.joins(:tags).where(tags: { id: params[:tag_id] }) if @tag
      end
    end

    @shared_count = Current.user.shares_received.count
  end

  # GET /workouts/new  — manual builder
  def new
    @workout = Workout.new(duration_mins: 60)
  end

  # POST /workouts
  def create
    if params[:source] == "manual"
      create_manual
    else
      create_with_llm
    end
  end

  # GET /workouts/:id/edit
  def edit
  end

  # PATCH /workouts/:id
  def update
    @workout.assign_attributes(manual_workout_params)
    assign_activity_from_params(@workout)
    @workout.structure = Workout.structure_from_params(params[:sections])

    if @workout.save
      save_workout_tags(@workout)
      redirect_to workout_path(@workout), notice: "Workout updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /workouts/:id/clone
  def clone
    copy = Current.user.workouts.create!(
      name:                "#{@workout.name} (copy)",
      activity_id:         @workout.activity_id,
      session_notes:       @workout.session_notes,
      duration_mins:       @workout.duration_mins,
      status:              "active",
      structure:           @workout.structure,
      original_structure:  @workout.original_structure || @workout.structure,
      source_workout:      @workout
    )
    copy.tags = @workout.tags
    redirect_to edit_workout_path(copy), notice: "Workout cloned — make it your own."
  end

  # POST /workouts/:id/remix
  def remix
    source = Workout.find(params[:id])
    generator = WorkoutLLMGenerator.new(
      user:           Current.user,
      source_workout: source,
      duration_mins:  params[:duration_mins]
    )
    result = generator.generate
    token = SecureRandom.urlsafe_base64(16)
    Rails.cache.write("workout_preview:#{token}", result, expires_in: 1.hour)
    redirect_to preview_workout_path(token: token)
  rescue WorkoutLLMGenerator::WorkoutGenerationError => e
    redirect_back fallback_location: root_path, alert: e.message
  rescue => e
    Rails.logger.error "Remix failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_back fallback_location: root_path, alert: "Something went wrong generating your workout. Please try again."
  end

  # GET /workouts/preview/:token
  def preview
    cached = Rails.cache.read("workout_preview:#{params[:token]}")
    unless cached
      redirect_to root_path, alert: "Preview expired — please generate again."
      return
    end

    attrs = cached[:attrs]
    @workout = Workout.new(attrs)
    @workout.activity = Activity.find_by(id: attrs[:activity_id]) if attrs[:activity_id]
    @preview_token = params[:token]
    @debug_info = cached[:debug_info]
  end

  # POST /workouts/preview/:token/persist
  def persist_preview
    cached = Rails.cache.read("workout_preview:#{params[:token]}")
    unless cached
      redirect_to root_path, alert: "Preview expired — please generate again."
      return
    end

    workout = Current.user.workouts.create!(
      **cached[:attrs],
      status: "active",
      original_structure: cached[:attrs][:structure]
    )

    if cached[:group_tag_name].present?
      tag = Tag.find_or_create_by!(slug: cached[:group_tag_name].parameterize) { |t| t.name = cached[:group_tag_name] }
      workout.tags = [ tag ]
    end

    Rails.cache.delete("workout_preview:#{params[:token]}")

    case params[:intent]
    when "log"
      redirect_to workout_path(workout, do_this: true)
    when "edit"
      redirect_to edit_workout_path(workout)
    else
      redirect_to workout_path(workout), notice: "\"#{workout.name}\" saved to your library."
    end
  end

  # POST /workouts/preview/:token/swap_exercise
  def swap_preview_exercise
    cache_key = "workout_preview:#{params[:token]}"
    cached = Rails.cache.read(cache_key)
    unless cached
      head :gone
      return
    end

    section_index  = params[:section_index].to_i
    exercise_index = params[:exercise_index].to_i
    attrs = cached[:attrs]

    result = ExerciseSwapService.call_without_persist(
      structure:      attrs[:structure],
      activity_name:  Activity.find_by(id: attrs[:activity_id])&.name,
      section_index:  section_index,
      exercise_index: exercise_index,
      reason:         params[:reason].presence
    )

    # Update cached structure
    cached[:attrs][:structure] = result[:updated_structure]
    Rails.cache.write(cache_key, cached, expires_in: 1.hour)

    section = result[:updated_structure]["sections"][section_index]
    render turbo_stream: turbo_stream.replace(
      "preview_exercise_#{params[:token]}_#{section_index}_#{exercise_index}",
      partial: "shared/exercise_row",
      locals: {
        exercise:       result[:replacement],
        workout:        nil,
        section:        section,
        section_index:  section_index,
        exercise_index: exercise_index,
        swappable:      true,
        preview_token:  params[:token]
      }
    )
  rescue ExerciseSwapService::SwapError => e
    Rails.logger.warn "Preview exercise swap failed: #{e.message}"
    render turbo_stream: turbo_stream.replace(
      "preview_exercise_#{params[:token]}_#{section_index}_#{exercise_index}",
      html: "<div id='preview_exercise_#{params[:token]}_#{section_index}_#{exercise_index}' class='px-3 py-2.5 border-t border-zinc-700/50'><p class='text-red-400 text-xs'>Swap failed — please try again.</p></div>".html_safe
    )
  end

  # POST /workouts/:id/save — copy another user's workout to your library
  def save
    source = Workout.find(params[:id])

    if Current.user.workouts.exists?(source_workout: source)
      redirect_to library_path, notice: "\"#{source.name}\" is already in your library."
      return
    end

    copy = Current.user.workouts.create!(
      name:                source.name,
      activity_id:         source.activity_id,
      session_notes:       source.session_notes,
      duration_mins:       source.duration_mins,
      status:              "active",
      structure:           source.structure,
      original_structure:  source.original_structure || source.structure,
      source_workout:      source
    )
    copy.tags = source.tags
    redirect_to library_path, notice: "\"#{copy.name}\" saved to your library."
  end

  # POST /workouts/:id/swap_exercise
  def swap_exercise
    @workout = Current.user.workouts.find(params[:id])
    section_index  = params[:section_index].to_i
    exercise_index = params[:exercise_index].to_i

    replacement = ExerciseSwapService.call(
      workout:        @workout,
      section_index:  section_index,
      exercise_index: exercise_index,
      reason:         params[:reason].presence
    )

    section = Array(@workout.structure["sections"])[section_index]
    render turbo_stream: turbo_stream.replace(
      "exercise_#{@workout.id}_#{section_index}_#{exercise_index}",
      partial: "shared/exercise_row",
      locals: {
        exercise:       replacement,
        workout:        @workout,
        section:        section,
        section_index:  section_index,
        exercise_index: exercise_index,
        swappable:      true
      }
    )
  rescue ExerciseSwapService::SwapError => e
    Rails.logger.warn "Exercise swap failed: #{e.message}"
    render turbo_stream: turbo_stream.replace(
      "exercise_#{@workout.id}_#{section_index}_#{exercise_index}",
      html: "<div id='exercise_#{@workout.id}_#{section_index}_#{exercise_index}' class='px-3 py-2.5 border-t border-zinc-700/50'><p class='text-red-400 text-xs'>Swap failed — please try again.</p></div>".html_safe
    )
  end

  # POST /workouts/:id/regenerate
  def regenerate
    old = Current.user.workouts.find(params[:id])
    generator = WorkoutLLMGenerator.new(
      user:          Current.user,
      activity:      old.activity_name,
      session_notes: old.session_notes,
      duration_mins: old.duration_mins
    )
    result = generator.generate
    token = SecureRandom.urlsafe_base64(16)
    Rails.cache.write("workout_preview:#{token}", result, expires_in: 1.hour)
    redirect_to preview_workout_path(token: token)
  rescue WorkoutLLMGenerator::WorkoutGenerationError => e
    redirect_to workout_path(old), alert: e.message
  rescue => e
    Rails.logger.error "Regenerate failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to workout_path(old), alert: "Something went wrong. Please try again."
  end

  # GET /workouts/:id/export_image
  def export_image
    unless Current.user.pro_features?
      redirect_to workout_path(params[:id]), alert: "Image export is a Pro feature."
      return
    end
    @workout = Workout.find(params[:id])
    image_data = @workout.generate_share_image
    filename = "volt-#{@workout.name.parameterize}-#{Date.today}.png"
    send_data image_data, filename: filename, type: "image/png", disposition: "attachment"
  rescue => e
    Rails.logger.error "Image export failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to workout_path(@workout || params[:id]), alert: "Image export failed. Please try again."
  end

  # GET /workouts/:id/export_pdf
  def export_pdf
    unless Current.user.pro_features?
      redirect_to workout_path(params[:id]), alert: "PDF export is a Pro feature."
      return
    end
    @workout = Workout.find(params[:id])
    pdf_data = WorkoutPdfGenerator.new(@workout).generate
    filename = "volt-workout-#{@workout.name.parameterize}-#{Date.today}.pdf"
    send_data pdf_data, filename: filename, type: "application/pdf", disposition: "attachment"
  end

  def share_card
    @workout = Workout.find(params[:id])
    render layout: false
  end

  # GET /workouts/:id/log
  def log
    @workout = Workout.find(params[:id])
  end

  # GET /workouts/:id  (preview)
  def show
    @workout    = Workout.find(params[:id])
    @liked      = @workout.workout_likes.exists?(user: Current.user)
    @like_count = @workout.workout_likes.count
    @debug_info = Rails.cache.read("workout_llm_debug_#{@workout.id}")
  end

  # POST /workouts/:id/scale
  def scale
    @workout = Workout.find(params[:id])
    current_level = params[:current_level].to_i.clamp(1, 5)
    direction = params[:direction]

    @difficulty_level = if direction == "up"
      [ current_level + 1, 5 ].min
    else
      [ current_level - 1, 1 ].max
    end

    @scaled_structure = @workout.scale_to(@difficulty_level)

    render :scale, layout: false
  end

  # PATCH /workouts/:id/save_template
  def save_template
    @workout = Current.user.workouts.find(params[:id])
    @workout.update!(status: "template")
    redirect_to workout_path(@workout), notice: "Saved as template"
  end

  # DELETE /workouts/:id
  def destroy
    @workout = Current.user.workouts.find(params[:id])
    @workout.destroy!
    redirect_to library_path, notice: "\"#{@workout.name}\" deleted."
  end

  # POST /workouts/scan
  def scan
    unless params[:image].present?
      redirect_to root_path, alert: "Please upload an image."
      return
    end

    if Current.user.generation_limit_reached?
      redirect_to root_path, alert: "You've used all #{Current.user.generation_limit} generations this week. Upgrade to Pro for unlimited workouts."
      return
    end

    workout = Workout.scan_from_image(image: params[:image], user: Current.user)

    token = SecureRandom.urlsafe_base64(16)
    Rails.cache.write("workout_preview:#{token}", {
      attrs: {
        name: workout.name,
        activity_id: workout.activity_id,
        duration_mins: workout.duration_mins,
        structure: workout.structure,
        session_notes: nil
      },
      debug_info: nil,
      group_tag_name: nil
    }, expires_in: 1.hour)

    Current.user.generation_uses.create!
    redirect_to preview_workout_path(token: token)
  rescue Scannable::ScanError => e
    redirect_to root_path, alert: e.message
  rescue => e
    Rails.logger.error "Workout scan failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to root_path, alert: "Something went wrong scanning your workout. Please try again."
  end

  # GET /sunday/workout — one-tap Sunday workout (no login required)
  def sunday
    user = Current.user || User.new

    generator = WorkoutLLMGenerator.new(
      user:          user,
      activity:      "Sunday Workout",
      duration_mins: 60
    )
    result = generator.generate

    attrs = result[:attrs]
    @workout = Workout.new(attrs)
    @workout.activity = Activity.find_by(id: attrs[:activity_id]) if attrs[:activity_id]
    @debug_info = result[:debug_info]

    if Current.user
      token = SecureRandom.urlsafe_base64(16)
      Rails.cache.write("workout_preview:#{token}", result, expires_in: 1.hour)
      Current.user.generation_uses.create!
      @preview_token = token
    end

    render :preview
  rescue WorkoutLLMGenerator::WorkoutGenerationError, StandardError => e
    Rails.logger.error "Sunday workout failed: #{e.class}: #{e.message}" unless e.is_a?(WorkoutLLMGenerator::WorkoutGenerationError)
    @error = "Something went wrong generating your Sunday workout. Please try again."
    render inline: <<~HTML, layout: "application"
      <div class="max-w-2xl mx-auto text-center py-20">
        <p class="text-4xl mb-4">&#9889;</p>
        <h2 class="text-xl font-black mb-2 text-white">Workout Generation Failed</h2>
        <p class="text-gray-400 text-sm mb-6"><%= @error %></p>
        <%= link_to "Try Again", sunday_workout_path, class: "bg-volt hover:bg-volt/80 text-zinc-950 font-black px-6 py-3 rounded-xl transition-colors" %>
      </div>
    HTML
  end

  private

  def set_owned_workout
    @workout = Current.user.workouts.find(params[:id])
  end

  def manual_workout_params
    params.permit(:name, :duration_mins)
  end

  def assign_activity_from_params(workout)
    return unless params.key?(:activity_name)
    name = params[:activity_name].to_s.strip
    workout.activity = name.present? ? Activity.find_or_create_by!(name: name) : nil
  end

  def create_manual
    @workout = Current.user.workouts.build(manual_workout_params)
    assign_activity_from_params(@workout)
    @workout.structure    = Workout.structure_from_params(params[:sections])
    @workout.status       = "active"
    @workout.original_structure = @workout.structure

    if @workout.save
      save_workout_tags(@workout)
      redirect_to log_workout_path(@workout), notice: "Workout built — time to log it!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_with_llm
    if Current.user.generation_limit_reached?
      redirect_to root_path, alert: "You've used all #{Current.user.generation_limit} generations this week. Upgrade to Pro for unlimited workouts."
      return
    end

    activity        = params[:activity].presence || params[:custom_activity].presence
    session_notes   = params[:session_notes].presence
    group_tag_name  = params[:group_code].presence
    equipment       = Array(params[:equipment]).compact_blank.intersection(User::EQUIPMENT_SLUGS)
    injury_notes    = params[:injury_notes].presence
    intensity_style = params[:intensity_style].to_s.presence_in(%w[low medium high])

    generator = WorkoutLLMGenerator.new(
      user:            Current.user,
      activity:        activity,
      session_notes:   session_notes,
      group_tag_name:  group_tag_name,
      duration_mins:   params[:duration_mins],
      equipment:       equipment,
      injury_notes:    injury_notes,
      intensity_style: intensity_style,
    )
    result = generator.generate

    token = SecureRandom.urlsafe_base64(16)
    Rails.cache.write("workout_preview:#{token}", result, expires_in: 1.hour)

    Current.user.generation_uses.create!
    redirect_to preview_workout_path(token: token)
  rescue WorkoutLLMGenerator::WorkoutGenerationError => e
    Rails.logger.warn "LLM generation failed (#{e.message}) — attempting fallback workout"
    fallback = find_fallback_workout(activity)
    if fallback
      redirect_to workout_path(fallback), alert: "#{e.message} Here's a popular workout to get you moving — try generating again when the AI is back."
    else
      redirect_to root_path, alert: "#{e.message} Please try again in a moment."
    end
  rescue => e
    Rails.logger.error "Workout generation failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to root_path, alert: "Something went wrong generating your workout. Please try again."
  end

  # When the LLM is unavailable, find a popular existing workout with the same activity
  # to show the user instead of an error page.
  def find_fallback_workout(activity_name)
    scope = Workout.where(status: "active").where.not(structure: nil)

    if activity_name.present?
      match = scope.joins(:activity).where(activities: { name: activity_name }).order("RANDOM()").first
      return match if match
    end

    scope.order("RANDOM()").first
  end

  def save_workout_tags(workout)
    tag_ids = Array(params[:tag_ids]).reject(&:blank?)
    params[:new_tag_name].to_s.split(",").map(&:strip).reject(&:blank?).each do |name|
      tag = Tag.find_or_create_by!(slug: name.parameterize) { |t| t.name = name }
      tag_ids << tag.id.to_s
    end
    workout.tag_ids = tag_ids
  end

end
