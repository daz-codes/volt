class RemoveDifficultyFromWorkouts < ActiveRecord::Migration[8.2]
  def change
    remove_column :workouts, :difficulty, :string
  end
end
