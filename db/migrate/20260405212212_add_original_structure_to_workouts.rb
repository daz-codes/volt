class AddOriginalStructureToWorkouts < ActiveRecord::Migration[8.2]
  def change
    add_column :workouts, :original_structure, :json
  end
end
