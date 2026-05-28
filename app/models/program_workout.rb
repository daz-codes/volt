class ProgramWorkout < ApplicationRecord
  belongs_to :program
  belongs_to :workout,  optional: true
  belongs_to :activity, optional: true  # per-session override of program.activity

  STATUSES = %w[pending generating complete failed].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :intensity_style, inclusion: { in: %w[low medium high], allow_nil: true }
  validates :duration_mins, numericality: { greater_than: 0 }, allow_nil: true

  def pending?    = status == "pending"
  def generating? = status == "generating"
  def complete?   = status == "complete"
  def failed?     = status == "failed"

  def turbo_dom_id = "program_workout_#{id}"

  # The activity actually used to generate this session. Per-session override
  # if set; otherwise falls back to the program's primary activity.
  def effective_activity
    activity || program.activity
  end

  # The duration used to generate this session. Per-session override if set;
  # otherwise falls back to the program's default duration.
  def effective_duration_mins
    duration_mins.presence || program.duration_mins
  end
end
