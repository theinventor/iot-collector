class Api::V1::DevicesController < Api::V1::BaseController
  def index
    devices = collector.devices.order(Arel.sql("last_seen_at IS NULL ASC"), last_seen_at: :desc, identifier: :asc)

    render json: {
      ok: true,
      devices: devices.map { |device| device_json(device) }
    }
  end

  def show
    device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:id]))

    render json: {
      ok: true,
      device: device_json(device, include_metric_names: true)
    }
  end

  private

  def device_json(device, include_metric_names: false)
    latest = device.latest_measurements.transform_values do |measurement|
      {
        value: measurement.numeric_value&.to_f || measurement.text_value,
        unit: measurement.unit,
        recorded_at: measurement.recorded_at.iso8601
      }.compact
    end

    {
      identifier: device.identifier,
      name: device.display_name,
      last_seen_at: device.last_seen_at&.iso8601,
      online: device.last_seen_at&.after?(15.minutes.ago) || false,
      readings_count: device.readings.count,
      latest: latest
    }.tap do |result|
      if include_metric_names
        result[:metric_names] = device.measurements.distinct.order(:name).pluck(:name)
      end
    end
  end
end
