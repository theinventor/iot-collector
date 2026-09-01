require "test_helper"

class NotificationChannelTest < ActiveSupport::TestCase
  setup do
    @collector = Collector.create!(
      key_digest: Collector.digest_key("q" * 64),
      time_zone: "Pacific Time (US & Canada)"
    )
  end

  test "defers warnings through overnight quiet hours" do
    channel = @collector.notification_channels.create!(
      kind: "email",
      label: "Owner",
      destination: "owner@example.com",
      quiet_start: "22:00",
      quiet_end: "07:00"
    )
    at_night = Time.utc(2026, 9, 2, 6, 0, 0) # 11 PM Pacific

    assert_equal Time.utc(2026, 9, 2, 14, 0, 0), channel.next_allowed_at(at_night, severity: "warning")
    assert_equal at_night, channel.next_allowed_at(at_night, severity: "critical")
  end

  test "validates channel destinations and complete quiet hours" do
    channel = @collector.notification_channels.new(
      kind: "webhook",
      label: "Bad",
      destination: "not-a-url",
      quiet_start: "22:00"
    )

    assert_not channel.valid?
    assert channel.errors[:destination].any?
    assert channel.errors[:quiet_hours_end].any?
  end
end
