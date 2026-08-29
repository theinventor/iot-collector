class Api::V1::DeviceReadingsController < Api::V1::BaseController
  MAX_LIMIT = 500

  def index
    device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:device_id]))
    range = TelemetryRange.new(params[:range])
    limit = params.fetch(:limit, 100).to_i.clamp(1, MAX_LIMIT)
    readings = range.apply(device.readings).recent.includes(:measurements).limit(limit)

    render json: {
      ok: true,
      device: device.identifier,
      range: range.key,
      readings: readings.map { |reading| reading_json(reading) }
    }
  end

  private

  def reading_json(reading)
    metrics = reading.measurements.each_with_object({}) do |measurement, result|
      result[measurement.name] = {
        value: measurement.numeric_value&.to_f || measurement.text_value,
        unit: measurement.unit
      }.compact
    end

    {
      id: reading.id,
      recorded_at: reading.recorded_at.iso8601,
      metrics: metrics
    }
  end
end
