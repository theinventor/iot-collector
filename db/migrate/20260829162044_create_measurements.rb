class CreateMeasurements < ActiveRecord::Migration[8.1]
  def change
    create_table :measurements do |t|
      t.references :device, null: false, foreign_key: true
      t.references :reading, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :numeric_value, precision: 18, scale: 6
      t.string :text_value
      t.string :unit
      t.datetime :recorded_at, null: false

      t.timestamps
    end
    add_index :measurements, [ :device_id, :name, :recorded_at ]
  end
end
