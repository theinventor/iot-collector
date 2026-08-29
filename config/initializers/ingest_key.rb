key = ENV["IOT_COLLECTOR_INGEST_KEY"].presence || Rails.application.credentials.dig(:iot_collector, :ingest_key).presence

if key.blank?
  if Rails.env.production?
    raise "Set IOT_COLLECTOR_INGEST_KEY before booting production"
  end

  key = "dev-secret"
end

Rails.application.config.x.iot_collector_ingest_key = key
