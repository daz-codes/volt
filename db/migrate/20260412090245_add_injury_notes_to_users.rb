class AddInjuryNotesToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :injury_notes, :text
  end
end
