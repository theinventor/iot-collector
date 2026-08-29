class AddVictronDeviceManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :victron_slots do |t|
      t.references :collector, null: false, foreign_key: true
      t.string :logger_identifier, null: false
      t.integer :position, null: false
      t.boolean :enabled, null: false, default: true
      t.string :device_identifier
      t.string :name
      t.string :mac_address
      t.string :bind_key
      t.timestamps
    end
    add_index :victron_slots,
      [ :collector_id, :logger_identifier, :position ],
      unique: true,
      name: "index_victron_slots_on_collector_logger_position"

    create_table :victron_discoveries do |t|
      t.references :collector, null: false, foreign_key: true
      t.string :logger_identifier, null: false
      t.string :mac_address, null: false
      t.integer :product_id, null: false
      t.integer :rssi, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :victron_discoveries,
      [ :collector_id, :logger_identifier, :mac_address ],
      unique: true,
      name: "index_victron_discoveries_on_collector_logger_mac"
  end
end
