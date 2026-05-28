class AddPerSessionActivityAndIntensityToProgramWorkouts < ActiveRecord::Migration[8.2]
  def change
    add_reference :program_workouts, :activity, null: true, foreign_key: true
    add_column :program_workouts, :intensity_style, :string
  end
end
