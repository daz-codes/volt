class AddSpeedUnitToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :speed_unit, :string, default: "kmh"
  end
end
