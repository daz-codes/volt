class AddDurationMinsToProgramWorkouts < ActiveRecord::Migration[8.2]
  def change
    # Per-session duration; falls back to program.duration_mins when nil.
    add_column :program_workouts, :duration_mins, :integer
  end
end
