require "csv"

class DeviceCsvExport
  MAX_READINGS = 50_000

  def initialize(device:, range:)
    @device = device
    @range = range
  end

  def generate
    metric_names = @range.apply(@device.measurements).distinct.order(:name).pluck(:name)
    readings = @range.apply(@device.readings).order(:recorded_at, :id).includes(:measurements).limit(MAX_READINGS)

    CSV.generate(headers: true) do |csv|
      csv << [ "recorded_at", *metric_names ]
      readings.each do |reading|
        measurements = reading.measurements.index_by(&:name)
        csv << [
          reading.recorded_at.iso8601,
          *metric_names.map { |name| export_value(measurements[name]) }
        ]
      end
    end
  end

  private

  def export_value(measurement)
    return if measurement.nil?

    measurement.numeric_value&.to_f || measurement.text_value
  end
end
