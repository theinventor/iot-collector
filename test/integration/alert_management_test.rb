require "test_helper"

class AlertManagementTest < ActionDispatch::IntegrationTest
  setup do
    @key = "z" * 64
    post api_v1_readings_path,
      params: {
        key: @key,
        device: "motorhome_shunt",
        name: "Motorhome Shunt",
        metrics: {
          state_of_charge: { value: 98.8, unit: "%" },
          battery_voltage: { value: 13.3, unit: "V" },
          consumed_ah: { value: -9.4, unit: "Ah" },
          alarm_reason_code: 0
        }
      },
      as: :json
    assert_response :created
    @device = Collector.find_by_key(@key).devices.find_by!(identifier: "motorhome_shunt")
    login
  end

  test "configures a battery profile and installs recommended rules" do
    post device_battery_profile_path(@device), params: {
      battery_profile: {
        chemistry: "lifepo4",
        nominal_voltage: 12,
        rated_capacity_ah: 400,
        usable_capacity_percent: 100,
        reserve_percent: 20,
        low_voltage_warning: 12.2,
        low_voltage_critical: 11.8
      }
    }
    assert_redirected_to device_path(@device, anchor: "battery-profile")

    post device_alert_presets_path(@device)
    assert_redirected_to device_path(@device, anchor: "alerts")
    assert_equal 7, @device.alert_rules.count

    follow_redirect!
    assert_response :success
    assert_select "#battery-profile input[name='battery_profile[rated_capacity_ah]'][value='400.0']"
    assert_select "#alerts tbody tr", count: 7
    assert_select "td", text: /Low battery/
  end

  test "creates and edits a custom rule using minute-based windows" do
    post device_alert_rules_path(@device), params: {
      alert_rule: {
        name: "Short remaining time",
        rule_type: "threshold",
        metric_name: "time_to_go",
        comparison: "below",
        threshold: 120,
        recovery_threshold: 180,
        severity: "critical",
        trigger_after_minutes: 5,
        recovery_after_minutes: 15,
        minimum_samples: 2,
        reminder_minutes: "15, 60, 240",
        notify_recovery: "1"
      }
    }

    rule = @device.alert_rules.find_by!(name: "Short remaining time")
    assert_equal 300, rule.trigger_after_seconds
    assert_equal 900, rule.recovery_after_seconds
    assert_equal [ 900, 3_600, 14_400 ], rule.reminder_intervals_seconds

    patch device_alert_rule_path(@device, rule), params: {
      alert_rule: {
        name: "Time remaining",
        rule_type: "threshold",
        metric_name: "time_to_go",
        comparison: "below",
        threshold: 90,
        recovery_threshold: 150,
        severity: "warning",
        trigger_after_minutes: 10,
        recovery_after_minutes: 20,
        minimum_samples: 3,
        reminder_minutes: "60, 360, 1440",
        notify_recovery: "1"
      }
    }

    assert_redirected_to device_path(@device, anchor: "alerts")
    assert_equal "Time remaining", rule.reload.name
    assert_equal 600, rule.trigger_after_seconds
  end

  test "manages collector-scoped notification settings" do
    patch settings_path, params: { collector: { time_zone: "Pacific Time (US & Canada)" } }
    assert_redirected_to settings_path

    post notification_channels_path, params: {
      notification_channel: {
        kind: "email",
        label: "Owner",
        destination: "owner@example.com",
        minimum_severity: "warning",
        quiet_start: "22:00",
        quiet_end: "07:00",
        critical_bypass: "1",
        enabled: "1"
      }
    }
    assert_redirected_to settings_path

    follow_redirect!
    assert_select ".channel-row", count: 1
    assert_select ".channel-row", text: /Owner/
    assert_select ".channel-row", text: /22:00-07:00/
  end

  test "does not expose another collector's alert records" do
    other = Collector.create!(key_digest: Collector.digest_key("y" * 64))
    other_device = other.devices.create!(identifier: "private_shunt")
    other_rule = other_device.alert_rules.create!(
      name: "Private alert",
      metric_name: "voltage",
      comparison: "below",
      threshold: 10
    )

    get edit_device_alert_rule_path(@device, other_rule)
    assert_response :not_found
    get device_path(other_device)
    assert_response :not_found
  end

  test "snoozes and acknowledges an active incident and toggles its rule" do
    rule = @device.alert_rules.create!(
      name: "Low battery",
      metric_name: "state_of_charge",
      comparison: "below",
      threshold: 30,
      recovery_threshold: 35
    )
    incident = rule.alert_incidents.create!(started_at: Time.current, triggered_at: Time.current)
    rule.state_record.update!(status: "active", active_incident: incident, active_since: Time.current)

    post snooze_device_alert_incident_path(@device, incident), params: { minutes: 240 }
    assert_redirected_to device_path(@device, anchor: "active-alerts")
    assert_in_delta 4.hours.from_now, incident.reload.snoozed_until, 2.seconds

    post acknowledge_device_alert_incident_path(@device, incident)
    assert_redirected_to device_path(@device, anchor: "active-alerts")
    assert incident.reload.acknowledged_at
    assert_nil incident.next_notification_at

    post toggle_device_alert_rule_path(@device, rule)
    assert_redirected_to device_path(@device, anchor: "alerts")
    assert_not rule.reload.enabled?
    assert incident.reload.resolved_at
    assert_equal "rule_disabled", incident.resolution_reason

    post toggle_device_alert_rule_path(@device, rule)
    assert rule.reload.enabled?
  end

  private

  def login
    post access_path, params: { key: @key }
    assert_response :see_other
  end
end
