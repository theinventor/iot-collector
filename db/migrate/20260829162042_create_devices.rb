class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.string :identifier, null: false
      t.string :name
      t.datetime :last_seen_at
      t.string :last_ip
      t.string :last_user_agent

      t.timestamps
    end
    add_index :devices, :identifier, unique: true
  end
end
