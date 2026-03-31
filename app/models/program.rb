class Program < ApplicationRecord
  include Program::Broadcasting
  include Program::WorkoutBuilder

  belongs_to :user
  belongs_to :activity, optional: true
  has_many :program_workouts, dependent: :destroy
  has_many :workouts, through: :program_workouts
  has_many :shares, as: :shareable, dependent: :destroy

  STATUSES     = %w[pending building complete failed].freeze
  DIFFICULTIES = %w[beginner intermediate advanced].freeze

  validates :name,              presence: true
  validates :weeks_count,       inclusion: { in: 2..16 }
  validates :sessions_per_week, inclusion: { in: 2..5 }
  validates :duration_mins,     numericality: { greater_than: 0 }
  validates :difficulty,        inclusion: { in: DIFFICULTIES }
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
end
