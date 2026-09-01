class AddPresetKeyToAlertRules < ActiveRecord::Migration[8.1]
  def change
    add_column :alert_rules, :preset_key, :string
    add_index :alert_rules, [ :device_id, :preset_key ], unique: true
  end
end
