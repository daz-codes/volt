class Program < ApplicationRecord
  include Program::Broadcasting
  include Program::WorkoutBuilder
  include Program::WeeklyShape
  include Program::SessionFocus

  belongs_to :user
  belongs_to :activity, optional: true
  has_many :program_workouts, dependent: :destroy
  has_many :workouts, through: :program_workouts
  has_many :shares, as: :shareable, dependent: :destroy

  STATUSES     = %w[pending building complete failed].freeze
  validates :name,              presence: true
  validates :weeks_count,       inclusion: { in: 2..8 }
  validates :sessions_per_week, inclusion: { in: 1..10 }
  validates :duration_mins,     numericality: { greater_than: 0 }
  validates :status,            inclusion: { in: STATUSES }

  before_destroy :cleanup_workouts, prepend: true

  scope :for_user, ->(user) { where(user: user).order(created_at: :desc) }

  def complete? = status == "complete"
  def building? = status == "building"
  def failed?   = status == "failed"

  def grid
    program_workouts.includes(:workout)
                    .order(:week_number, :session_number)
                    .group_by(&:week_number)
  end

  # Build the per-session prescriptions from the session focus text supplied
  # by the user (possibly pre-filled in the form). Each text entry is parsed
  # via Program::SessionFocus: keywords drive the activity override and
  # intensity_style; blank entries fall back to the program's primary
  # activity with no intensity directive. The same shape repeats every week
  # — Week-2+ remix from Week-1's matching session.
  def create_workout_placeholders(session_notes = [], custom_activity: nil, session_durations: [])
    activity_cache = {}
    primary_name   = activity&.name
    rows = []

    (1..weeks_count).each do |week|
      (1..sessions_per_week).each do |session|
        raw = session_notes[session - 1].to_s
        parsed = self.class.parse_session_focus(raw, default_activity_name: primary_name)

        activity_id = nil
        if parsed[:activity_name].present? && parsed[:activity_name] != primary_name
          activity_cache[parsed[:activity_name]] ||= Activity.find_or_create_by!(name: parsed[:activity_name])
          activity_id = activity_cache[parsed[:activity_name]].id
        end

        notes = parsed[:notes]
        notes = [ custom_activity, notes ].compact_blank.join(" — ").presence if custom_activity

        # Per-session duration override — nil means "use program's duration"
        per_session_duration = session_durations[session - 1].to_i
        per_session_duration = nil if per_session_duration <= 0 || per_session_duration == duration_mins

        rows << {
          program_id: id,
          week_number: week,
          session_number: session,
          activity_id: activity_id,
          intensity_style: parsed[:intensity_style],
          session_notes: notes,
          duration_mins: per_session_duration,
          status: "pending",
          created_at: Time.current, updated_at: Time.current
        }
      end
    end
    ProgramWorkout.insert_all!(rows)
  end

  def build_later
    BuildProgramJob.perform_later(id)
  end

  def build!
    update!(status: "building")

    week1_workouts = {}
    program_workouts.where(week_number: 1).order(:session_number).each do |pw|
      generate_slot(pw, source: nil)
      week1_workouts[pw.session_number] = pw.reload.workout
    end

    if weeks_count > 1
      program_workouts.where.not(week_number: 1).order(:week_number, :session_number).each do |pw|
        generate_slot(pw, source: week1_workouts[pw.session_number])
      end
    end

    update!(status: "complete")
    broadcast_program_complete
  rescue => e
    Rails.logger.error "Program#build! failed for #{id}: #{e.message}"
    update(status: "failed")
  end

  private

  def cleanup_workouts
    workout_ids = program_workouts.where.not(workout_id: nil).pluck(:workout_id)
    return if workout_ids.empty?

    deletable_ids = Workout.where(id: workout_ids)
                           .left_joins(:workout_logs)
                           .where(workout_logs: { id: nil })
                           .pluck(:id)
    return if deletable_ids.empty?

    program_workouts.where(workout_id: deletable_ids).destroy_all
    Workout.where(id: deletable_ids).destroy_all
  end

  def generate_slot(pw, source:)
    pw.update!(status: "generating")
    broadcast_slot(pw)

    duration = pw.effective_duration_mins
    workout = if source
      WorkoutLLMGenerator.call(
        user: user, source_workout: source, duration_mins: duration,
        session_notes: pw.session_notes, intensity_style: pw.intensity_style
      )
    else
      WorkoutLLMGenerator.call(
        user: user, activity: pw.effective_activity&.name, duration_mins: duration,
        session_notes: pw.session_notes, intensity_style: pw.intensity_style
      )
    end

    pw.update!(workout: workout, status: "complete")
    broadcast_slot(pw)
  rescue => e
    Rails.logger.error "Program #{id} slot #{pw.id} failed: #{e.message}"
    pw.update!(status: "failed")
    broadcast_slot(pw)
  end

  def broadcast_slot(pw)
    pw_fresh = pw.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      "program_#{id}", target: pw_fresh.turbo_dom_id,
      partial: "programs/program_workout_slot", locals: { program_workout: pw_fresh }
    )
  end

  def broadcast_program_complete
    Turbo::StreamsChannel.broadcast_replace_to(
      "program_#{id}", target: "program_header_#{id}",
      partial: "programs/program_header", locals: { program: reload }
    )
  end
end
