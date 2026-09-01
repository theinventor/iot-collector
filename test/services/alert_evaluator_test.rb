require "test_helper"

class AlertEvaluatorTest < ActiveSupport::TestCase
  setup do
    @collector = Collector.create!(key_digest: Collector.digest_key("a" * 64), name: "Test collector")
    @device = @collector.devices.create!(identifier: "motorhome_shunt", name: "Motorhome Shunt")
    @channel = @collector.notification_channels.create!(
      kind: "email",
      label: "Owner",
      destination: "owner@example.com"
    )
    @rule = @device.alert_rules.create!(
      name: "Low battery",
      metric_name: "state_of_charge",
      comparison: "below",
      threshold: 30,
      recovery_threshold: 35,
      severity: "warning",
      trigger_after_seconds: 120,
      recovery_after_seconds: 120,
      minimum_samples: 2,
      reminder_intervals: [ 60 ].to_json
    )
    @base = Time.zone.parse("2026-09-01 12:00:00")
  end

  test "requires a sustained breach and hysteresis recovery" do
    sample(@base, state_of_charge: 25)
    assert_equal "pending", @rule.state_record.reload.status

    sample(@base + 60, state_of_charge: 24)
    assert_equal "pending", @rule.state_record.reload.status

    sample(@base + 120, state_of_charge: 23)
    state = @rule.state_record.reload
    incident = state.active_incident
    assert_equal "active", state.status
    assert_equal BigDecimal("23"), incident.trigger_value
    assert_equal BigDecimal("23"), incident.worst_value
    assert_equal 1, incident.notification_deliveries.where(event_type: "trigger").count

    sample(@base + 180, state_of_charge: 32)
    assert_equal "active", state.reload.status

    sample(@base + 240, state_of_charge: 36)
    assert_equal "recovering", state.reload.status

    sample(@base + 300, state_of_charge: 34)
    assert_equal "active", state.reload.status

    sample(@base + 360, state_of_charge: 36)
    sample(@base + 480, state_of_charge: 37)

    assert_equal "normal", state.reload.status
    assert_equal @base + 480, incident.reload.resolved_at
    assert_equal 1, incident.notification_deliveries.where(event_type: "recovery").count
  end

  test "acknowledgment suppresses reminders and a later breach creates a new incident" do
    activate_rule
    incident = @rule.alert_incidents.active.first
    incident.update!(acknowledged_at: @base + 121)

    AlertReminderScheduler.new(now: @base + 181).call
    assert_nil incident.reload.next_notification_at
    assert_equal 0, incident.notification_deliveries.where(event_type: "reminder").count

    sample(@base + 240, state_of_charge: 36)
    sample(@base + 360, state_of_charge: 37)
    assert incident.reload.resolved_at

    sample(@base + 500, state_of_charge: 20)
    sample(@base + 620, state_of_charge: 19)

    assert_equal 2, @rule.alert_incidents.count
    assert_equal "active", @rule.state_record.reload.status
    assert_not @rule.alert_incidents.active.first.acknowledged?
  end

  test "out of order samples do not change current alert state" do
    sample(@base, state_of_charge: 25)
    sample(@base - 1.minute, state_of_charge: 10)

    state = @rule.state_record.reload
    assert_equal 1, state.consecutive_samples
    assert_equal BigDecimal("25"), state.last_value
  end

  test "missing telemetry activates, recovers with samples, and reuses an incident if data disappears during recovery" do
    @device.update!(last_seen_at: @base)
    rule = @device.alert_rules.create!(
      name: "Shunt telemetry missing",
      rule_type: "missing_data",
      severity: "warning",
      trigger_after_seconds: 600,
      recovery_after_seconds: 120,
      minimum_samples: 2
    )

    MissingDataAlertEvaluator.new(now: @base + 601).call
    state = rule.state_record.reload
    incident = state.active_incident
    assert_equal "active", state.status

    sample(@base + 620, battery_voltage: 13.1)
    assert_equal "recovering", state.reload.status

    MissingDataAlertEvaluator.new(now: @base + 1_221).call
    assert_equal "active", state.reload.status
    assert_equal incident, state.active_incident
    assert_equal 1, rule.alert_incidents.count

    sample(@base + 1_240, battery_voltage: 13.2)
    sample(@base + 1_360, battery_voltage: 13.3)
    assert_equal "normal", state.reload.status
    assert incident.reload.resolved_at
  end

  private

  def activate_rule
    sample(@base, state_of_charge: 25)
    sample(@base + 120, state_of_charge: 20)
  end

  def sample(recorded_at, metrics)
    reading = @device.readings.create!(recorded_at: recorded_at, payload: metrics.to_json)
    measurements = metrics.map do |name, value|
      reading.measurements.create!(
        device: @device,
        name: name,
        numeric_value: value,
        recorded_at: recorded_at
      )
    end
    @device.update!(last_seen_at: recorded_at)
    AlertEvaluator.new(reading: reading, measurements: measurements, now: recorded_at).call
  end
end
