class CreateShares < ActiveRecord::Migration[8.2]
  def change
    create_table :shares do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :shareable, polymorphic: true, null: false
      t.text :message

      t.timestamps
    end
  end
end
