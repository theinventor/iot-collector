require "digest"

class AddCollectors < ActiveRecord::Migration[8.1]
  def up
    create_table :collectors do |t|
      t.string :key_digest, null: false
      t.string :name

      t.timestamps
    end
    add_index :collectors, :key_digest, unique: true

    add_reference :devices, :collector, foreign_key: true
    remove_index :devices, :identifier

    key = ENV.fetch("IOT_COLLECTOR_INGEST_KEY", "dev-secret")
    digest = Digest::SHA256.hexdigest(key)
    now = Time.current.to_fs(:db)
    execute <<~SQL.squish
      INSERT INTO collectors (key_digest, name, created_at, updated_at)
      VALUES (#{connection.quote(digest)}, 'Primary collector', #{connection.quote(now)}, #{connection.quote(now)})
    SQL

    collector_id = select_value("SELECT id FROM collectors WHERE key_digest = #{connection.quote(digest)}")
    execute "UPDATE devices SET collector_id = #{connection.quote(collector_id)}"

    change_column_null :devices, :collector_id, false
    add_index :devices, [ :collector_id, :identifier ], unique: true
  end

  def down
    remove_index :devices, [ :collector_id, :identifier ]
    remove_reference :devices, :collector, foreign_key: true
    add_index :devices, :identifier, unique: true
    drop_table :collectors
  end
end
