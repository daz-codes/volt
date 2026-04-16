class AddUnitSystemToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :unit_system, :string, default: "metric"
  end
end
