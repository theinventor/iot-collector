require "test_helper"

class DeviceReportTest < ActiveSupport::TestCase
  test "calculates numeric series statistics and ignores text metrics" do
    key = "2" * 64
    collector = Collector.find_or_create_for_ingest(key)
    device = collector.devices.create!(identifier: "shunt")
    now = Time.zone.parse("2026-08-29 12:00:00")

    [ 10.0, 12.0, 14.0 ].each_with_index do |voltage, index|
      recorded_at = now - (2 - index).minutes
      reading = device.readings.create!(recorded_at: recorded_at, payload: "{}")
      reading.measurements.create!(device: device, name: "voltage", numeric_value: voltage, unit: "V", recorded_at: recorded_at)
      reading.measurements.create!(device: device, name: "state", text_value: "on", recorded_at: recorded_at)
    end

    range = TelemetryRange.new("1h", now: now)
    report = DeviceReport.new(device: device, range: range)
    series = report.series.fetch(0)

    assert_equal "voltage", series.name
    assert_equal 14.0, series.latest
    assert_equal 10.0, series.minimum
    assert_equal 14.0, series.maximum
    assert_equal 12.0, series.average
    assert_equal 4.0, series.change
    assert_equal 3, report.reading_count
  end
end
