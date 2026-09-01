class AddAlerting < ActiveRecord::Migration[8.1]
  def change
    add_column :collectors, :time_zone, :string, null: false, default: "UTC"

    create_table :battery_profiles do |t|
      t.references :device, null: false, foreign_key: true, index: { unique: true }
      t.string :chemistry, null: false, default: "other"
      t.decimal :nominal_voltage, precision: 8, scale: 2
      t.decimal :rated_capacity_ah, precision: 10, scale: 2
      t.decimal :usable_capacity_percent, precision: 5, scale: 2, null: false, default: 100
      t.decimal :reserve_percent, precision: 5, scale: 2, null: false, default: 20
      t.decimal :low_voltage_warning, precision: 8, scale: 3
      t.decimal :low_voltage_critical, precision: 8, scale: 3
      t.timestamps
    end

    create_table :alert_rules do |t|
      t.references :device, null: false, foreign_key: true
      t.string :name, null: false
      t.string :rule_type, null: false, default: "threshold"
      t.string :metric_name
      t.string :comparison
      t.decimal :threshold, precision: 18, scale: 6
      t.decimal :upper_threshold, precision: 18, scale: 6
      t.decimal :recovery_threshold, precision: 18, scale: 6
      t.decimal :recovery_upper_threshold, precision: 18, scale: 6
      t.string :severity, null: false, default: "warning"
      t.integer :trigger_after_seconds, null: false, default: 300
      t.integer :recovery_after_seconds, null: false, default: 600
      t.integer :minimum_samples, null: false, default: 2
      t.text :reminder_intervals, null: false, default: "[]"
      t.boolean :notify_recovery, null: false, default: true
      t.boolean :enabled, null: false, default: true
      t.timestamps

      t.index [ :device_id, :enabled ]
    end

    create_table :alert_incidents do |t|
      t.references :alert_rule, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :triggered_at, null: false
      t.datetime :resolved_at
      t.datetime :acknowledged_at
      t.datetime :snoozed_until
      t.decimal :trigger_value, precision: 18, scale: 6
      t.decimal :last_value, precision: 18, scale: 6
      t.decimal :worst_value, precision: 18, scale: 6
      t.datetime :next_notification_at
      t.integer :reminder_step, null: false, default: 0
      t.string :resolution_reason
      t.timestamps

      t.index [ :alert_rule_id, :resolved_at ]
      t.index :next_notification_at
    end

    create_table :alert_rule_states do |t|
      t.references :alert_rule, null: false, foreign_key: true, index: { unique: true }
      t.references :active_incident, foreign_key: { to_table: :alert_incidents }
      t.string :status, null: false, default: "normal"
      t.datetime :pending_since
      t.datetime :active_since
      t.datetime :recovering_since
      t.integer :consecutive_samples, null: false, default: 0
      t.integer :recovery_samples, null: false, default: 0
      t.datetime :last_sample_at
      t.decimal :last_value, precision: 18, scale: 6
      t.timestamps
    end

    create_table :notification_channels do |t|
      t.references :collector, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :label, null: false
      t.string :destination, null: false
      t.boolean :enabled, null: false, default: true
      t.string :minimum_severity, null: false, default: "warning"
      t.integer :quiet_hours_start
      t.integer :quiet_hours_end
      t.boolean :critical_bypass, null: false, default: true
      t.timestamps

      t.index [ :collector_id, :enabled ]
    end

    create_table :notification_deliveries do |t|
      t.references :notification_channel, null: false, foreign_key: true
      t.references :alert_incident, foreign_key: true
      t.string :event_type, null: false
      t.string :status, null: false, default: "pending"
      t.text :payload, null: false
      t.string :idempotency_key, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: false
      t.datetime :delivered_at
      t.text :last_error
      t.timestamps

      t.index :idempotency_key, unique: true
      t.index [ :status, :next_attempt_at ]
    end
  end
end
