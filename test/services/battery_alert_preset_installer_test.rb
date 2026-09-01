require "test_helper"

class BatteryAlertPresetInstallerTest < ActiveSupport::TestCase
  setup do
    collector = Collector.create!(key_digest: Collector.digest_key("p" * 64))
    @device = collector.devices.create!(identifier: "motorhome_shunt")
    @device.create_battery_profile!(
      chemistry: "lifepo4",
      nominal_voltage: 12,
      rated_capacity_ah: 400,
      reserve_percent: 20,
      low_voltage_warning: 12.2,
      low_voltage_critical: 11.8
    )
  end

  test "installs idempotent battery, capacity, voltage, alarm, and telemetry presets" do
    2.times { BatteryAlertPresetInstaller.new(@device).call }

    assert_equal 7, @device.alert_rules.count
    assert_equal @device.alert_rules.count, @device.alert_rules.distinct.count

    reserve = @device.alert_rules.find_by!(preset_key: "capacity_reserve")
    assert_equal BigDecimal("-320"), reserve.threshold
    assert_equal "critical", reserve.severity

    telemetry = @device.alert_rules.find_by!(preset_key: "telemetry_missing")
    assert_equal 30.minutes.to_i, telemetry.trigger_after_seconds

    voltage = @device.alert_rules.find_by!(preset_key: "low_voltage_warning")
    assert_equal BigDecimal("12.2"), voltage.threshold
    assert_operator voltage.recovery_threshold, :>, voltage.threshold
  end

  test "missing telemetry preset ignores brief Bluetooth reception gaps" do
    BatteryAlertPresetInstaller.new(@device).call
    last_seen_at = Time.zone.parse("2026-09-01 12:00:00")
    @device.update!(last_seen_at: last_seen_at)
    rule = @device.alert_rules.find_by!(preset_key: "telemetry_missing")

    MissingDataAlertEvaluator.new(now: last_seen_at + 25.minutes).call
    assert_equal "normal", rule.state_record.reload.status

    MissingDataAlertEvaluator.new(now: last_seen_at + 30.minutes + 1.second).call
    assert_equal "active", rule.state_record.reload.status
  end
end
