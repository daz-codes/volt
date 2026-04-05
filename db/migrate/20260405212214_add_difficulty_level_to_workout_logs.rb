class AddDifficultyLevelToWorkoutLogs < ActiveRecord::Migration[8.2]
  def change
    add_column :workout_logs, :difficulty_level, :integer, default: 3, null: false
  end
end
