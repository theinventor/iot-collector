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

ActiveRecord::Schema[8.1].define(version: 2026_08_29_205000) do
  create_table "collectors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key_digest", null: false
    t.string "name"
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

  add_foreign_key "devices", "collectors"
  add_foreign_key "measurements", "devices"
  add_foreign_key "measurements", "readings"
  add_foreign_key "readings", "devices"
end
