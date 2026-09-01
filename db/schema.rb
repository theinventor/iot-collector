# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_01_131000) do
  create_table "alert_incidents", force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.integer "alert_rule_id", null: false
    t.datetime "created_at", null: false
    t.decimal "last_value", precision: 18, scale: 6
    t.datetime "next_notification_at"
    t.integer "reminder_step", default: 0, null: false
    t.string "resolution_reason"
    t.datetime "resolved_at"
    t.datetime "snoozed_until"
    t.datetime "started_at", null: false
    t.decimal "trigger_value", precision: 18, scale: 6
    t.datetime "triggered_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "worst_value", precision: 18, scale: 6
    t.index ["alert_rule_id", "resolved_at"], name: "index_alert_incidents_on_alert_rule_id_and_resolved_at"
    t.index ["alert_rule_id"], name: "index_alert_incidents_on_alert_rule_id"
    t.index ["next_notification_at"], name: "index_alert_incidents_on_next_notification_at"
  end

  create_table "alert_rule_states", force: :cascade do |t|
    t.integer "active_incident_id"
    t.datetime "active_since"
    t.integer "alert_rule_id", null: false
    t.integer "consecutive_samples", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "last_sample_at"
    t.decimal "last_value", precision: 18, scale: 6
    t.datetime "pending_since"
    t.datetime "recovering_since"
    t.integer "recovery_samples", default: 0, null: false
    t.string "status", default: "normal", null: false
    t.datetime "updated_at", null: false
    t.index ["active_incident_id"], name: "index_alert_rule_states_on_active_incident_id"
    t.index ["alert_rule_id"], name: "index_alert_rule_states_on_alert_rule_id", unique: true
  end

  create_table "alert_rules", force: :cascade do |t|
    t.string "comparison"
    t.datetime "created_at", null: false
    t.integer "device_id", null: false
    t.boolean "enabled", default: true, null: false
    t.string "metric_name"
    t.integer "minimum_samples", default: 2, null: false
    t.string "name", null: false
    t.boolean "notify_recovery", default: true, null: false
    t.string "preset_key"
    t.integer "recovery_after_seconds", default: 600, null: false
    t.decimal "recovery_threshold", precision: 18, scale: 6
    t.decimal "recovery_upper_threshold", precision: 18, scale: 6
    t.text "reminder_intervals", default: "[]", null: false
    t.string "rule_type", default: "threshold", null: false
    t.string "severity", default: "warning", null: false
    t.decimal "threshold", precision: 18, scale: 6
    t.integer "trigger_after_seconds", default: 300, null: false
    t.datetime "updated_at", null: false
    t.decimal "upper_threshold", precision: 18, scale: 6
    t.index ["device_id", "enabled"], name: "index_alert_rules_on_device_id_and_enabled"
    t.index ["device_id", "preset_key"], name: "index_alert_rules_on_device_id_and_preset_key", unique: true
    t.index ["device_id"], name: "index_alert_rules_on_device_id"
  end

  create_table "battery_profiles", force: :cascade do |t|
    t.string "chemistry", default: "other", null: false
    t.datetime "created_at", null: false
    t.integer "device_id", null: false
    t.decimal "low_voltage_critical", precision: 8, scale: 3
    t.decimal "low_voltage_warning", precision: 8, scale: 3
    t.decimal "nominal_voltage", precision: 8, scale: 2
    t.decimal "rated_capacity_ah", precision: 10, scale: 2
    t.decimal "reserve_percent", precision: 5, scale: 2, default: "20.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "usable_capacity_percent", precision: 5, scale: 2, default: "100.0", null: false
    t.index ["device_id"], name: "index_battery_profiles_on_device_id", unique: true
  end

  create_table "collectors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key_digest", null: false
    t.string "name"
    t.string "time_zone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["key_digest"], name: "index_collectors_on_key_digest", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.integer "collector_id", null: false
    t.datetime "created_at", null: false
    t.string "identifier", null: false
    t.string "last_ip"
    t.datetime "last_seen_at"
    t.string "last_user_agent"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["collector_id", "identifier"], name: "index_devices_on_collector_id_and_identifier", unique: true
    t.index ["collector_id"], name: "index_devices_on_collector_id"
  end

  create_table "measurements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "device_id", null: false
    t.string "name", null: false
    t.decimal "numeric_value", precision: 18, scale: 6
    t.integer "reading_id", null: false
    t.datetime "recorded_at", null: false
    t.string "text_value"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["device_id", "name", "recorded_at"], name: "index_measurements_on_device_id_and_name_and_recorded_at"
    t.index ["device_id"], name: "index_measurements_on_device_id"
    t.index ["reading_id"], name: "index_measurements_on_reading_id"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.integer "collector_id", null: false
    t.datetime "created_at", null: false
    t.boolean "critical_bypass", default: true, null: false
    t.string "destination", null: false
    t.boolean "enabled", default: true, null: false
    t.string "kind", null: false
    t.string "label", null: false
    t.string "minimum_severity", default: "warning", null: false
    t.integer "quiet_hours_end"
    t.integer "quiet_hours_start"
    t.datetime "updated_at", null: false
    t.index ["collector_id", "enabled"], name: "index_notification_channels_on_collector_id_and_enabled"
    t.index ["collector_id"], name: "index_notification_channels_on_collector_id"
  end

  create_table "notification_deliveries", force: :cascade do |t|
    t.integer "alert_incident_id"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "event_type", null: false
    t.string "idempotency_key", null: false
    t.text "last_error"
    t.datetime "next_attempt_at", null: false
    t.integer "notification_channel_id", null: false
    t.text "payload", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_incident_id"], name: "index_notification_deliveries_on_alert_incident_id"
    t.index ["idempotency_key"], name: "index_notification_deliveries_on_idempotency_key", unique: true
    t.index ["notification_channel_id"], name: "index_notification_deliveries_on_notification_channel_id"
    t.index ["status", "next_attempt_at"], name: "index_notification_deliveries_on_status_and_next_attempt_at"
  end

  create_table "readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "device_id", null: false
    t.text "payload", null: false
    t.datetime "recorded_at", null: false
    t.string "remote_ip"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["device_id", "recorded_at"], name: "index_readings_on_device_id_and_recorded_at"
    t.index ["device_id"], name: "index_readings_on_device_id"
  end

  create_table "victron_discoveries", force: :cascade do |t|
    t.integer "collector_id", null: false
    t.datetime "created_at", null: false
    t.datetime "last_seen_at", null: false
    t.string "logger_identifier", null: false
    t.string "mac_address", null: false
    t.integer "product_id", null: false
    t.integer "rssi", null: false
    t.datetime "updated_at", null: false
    t.index ["collector_id", "logger_identifier", "mac_address"], name: "index_victron_discoveries_on_collector_logger_mac", unique: true
    t.index ["collector_id"], name: "index_victron_discoveries_on_collector_id"
  end

  create_table "victron_slots", force: :cascade do |t|
    t.string "bind_key"
    t.integer "collector_id", null: false
    t.datetime "created_at", null: false
    t.string "device_identifier"
    t.boolean "enabled", default: true, null: false
    t.string "logger_identifier", null: false
    t.string "mac_address"
    t.string "name"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["collector_id", "logger_identifier", "position"], name: "index_victron_slots_on_collector_logger_position", unique: true
    t.index ["collector_id"], name: "index_victron_slots_on_collector_id"
  end

  add_foreign_key "alert_incidents", "alert_rules"
  add_foreign_key "alert_rule_states", "alert_incidents", column: "active_incident_id"
  add_foreign_key "alert_rule_states", "alert_rules"
  add_foreign_key "alert_rules", "devices"
  add_foreign_key "battery_profiles", "devices"
  add_foreign_key "devices", "collectors"
  add_foreign_key "measurements", "devices"
  add_foreign_key "measurements", "readings"
  add_foreign_key "notification_channels", "collectors"
  add_foreign_key "notification_deliveries", "alert_incidents"
  add_foreign_key "notification_deliveries", "notification_channels"
  add_foreign_key "readings", "devices"
  add_foreign_key "victron_discoveries", "collectors"
  add_foreign_key "victron_slots", "collectors"
end
