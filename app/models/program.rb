class Program < ApplicationRecord
  include Program::Broadcasting
  include Program::WorkoutBuilder
  include Program::HyroxWeeklyShape

  belongs_to :user
  belongs_to :activity, optional: true
  has_many :program_workouts, dependent: :destroy
  has_many :workouts, through: :program_workouts
  has_many :shares, as: :shareable, dependent: :destroy

  STATUSES     = %w[pending building complete failed].freeze
  validates :name,              presence: true
  validates :weeks_count,       inclusion: { in: 2..16 }
  validates :sessions_per_week, inclusion: { in: 1..7 }
  validates :duration_mins,     numericality: { greater_than: 0 }
  validates :status,            inclusion: { in: STATUSES }

  # True when the program's primary activity is one whose weekly shape we
  # prescribe explicitly (rather than rotating the generic SESSION_FOCUSES).
  # Currently only Hyrox; other activities fall back to the legacy shape.
  def hyrox_weekly_plan?
    activity&.name.to_s.casecmp("Hyrox").zero?
  end

  SESSION_FOCUSES = [
    "strength and power focus — heavy compound movements, lower rep ranges",
    "cardio engine and endurance focus — sustained effort, machine work, conditioning",
    "mixed modal and full body — variety of formats, balanced across all qualities"
  ].freeze

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

  def create_workout_placeholders(session_notes = [], custom_activity: nil)
    return create_hyrox_weekly_placeholders if hyrox_weekly_plan?

    rows = []
    (1..weeks_count).each do |week|
      (1..sessions_per_week).each do |session|
        notes = session_notes[session - 1].presence
        notes = SESSION_FOCUSES[(session - 1) % SESSION_FOCUSES.size] if week == 1 && notes.nil?
        notes = [ custom_activity, notes ].compact.join(" — ").presence if custom_activity
        rows << {
          program_id: id, week_number: week, session_number: session,
          session_notes: notes, status: "pending",
          created_at: Time.current, updated_at: Time.current
        }
      end
    end
    ProgramWorkout.insert_all!(rows)
  end

  # Hyrox plans use the prescribed weekly shape (Program::HyroxWeeklyShape):
  # each session gets a specific activity (Hyrox / Engine Room / Transformer)
  # and intensity (low / medium / high) per the shape table. The same shape
  # repeats every week — Week-2+ remix from Week-1's matching session.
  def create_hyrox_weekly_placeholders
    shape = self.class.hyrox_weekly_shape(sessions_per_week)
    activity_lookup = shape.map { |s| s[:activity] }.uniq.index_with { |name| Activity.find_or_create_by!(name: name) }

    rows = []
    (1..weeks_count).each do |week|
      shape.each_with_index do |slot, idx|
        rows << {
          program_id: id,
          week_number: week,
          session_number: idx + 1,
          activity_id: activity_lookup[slot[:activity]].id,
          intensity_style: slot[:intensity_style],
          session_notes: slot[:notes],
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

    workout = if source
      WorkoutLLMGenerator.call(
        user: user, source_workout: source, duration_mins: duration_mins,
        session_notes: pw.session_notes, intensity_style: pw.intensity_style
      )
    else
      WorkoutLLMGenerator.call(
        user: user, activity: pw.effective_activity&.name, duration_mins: duration_mins,
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
