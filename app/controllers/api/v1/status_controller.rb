class Api::V1::StatusController < Api::V1::BaseController
  def show
    latest_reading = collector.readings.recent.first

    render json: {
      ok: true,
      collector: {
        devices_count: collector.devices.count,
        readings_count: collector.readings.count,
        measurements_count: collector.measurements.count,
        last_reading_at: latest_reading&.recorded_at&.iso8601
      }
    }
  end
end
