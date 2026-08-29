class CreateReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :readings do |t|
      t.references :device, null: false, foreign_key: true
      t.datetime :recorded_at, null: false
      t.string :remote_ip
      t.string :user_agent
      t.text :payload, null: false

      t.timestamps
    end
    add_index :readings, [ :device_id, :recorded_at ]
  end
end
