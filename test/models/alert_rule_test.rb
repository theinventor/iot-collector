require "test_helper"

class AlertRuleTest < ActiveSupport::TestCase
  setup do
    collector = Collector.create!(key_digest: Collector.digest_key("r" * 64))
    @device = collector.devices.create!(identifier: "battery")
  end

  test "validates recovery thresholds against the comparison direction" do
    below = build_rule(comparison: "below", threshold: 30, recovery_threshold: 25)
    assert_not below.valid?
    assert_includes below.errors[:recovery_threshold], "must be at or above the trigger threshold"

    above = build_rule(comparison: "above", threshold: 14.5, recovery_threshold: 15)
    assert_not above.valid?
    assert_includes above.errors[:recovery_threshold], "must be at or below the trigger threshold"
  end

  test "validates an outside recovery band inside the trigger band" do
    rule = build_rule(
      comparison: "outside",
      threshold: 11,
      upper_threshold: 15,
      recovery_threshold: 12,
      recovery_upper_threshold: 14
    )
    assert rule.valid?

    rule.recovery_upper_threshold = 16
    assert_not rule.valid?
    assert_includes rule.errors[:recovery_upper_threshold], "must be at or below the upper trigger threshold"
  end

  private

  def build_rule(attributes)
    @device.alert_rules.new({
      name: "Battery range",
      metric_name: "battery_voltage",
      severity: "warning"
    }.merge(attributes))
  end
end
