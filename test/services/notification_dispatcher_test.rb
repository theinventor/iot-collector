require "test_helper"

class NotificationDispatcherTest < ActiveSupport::TestCase
  setup do
    @collector = Collector.create!(key_digest: Collector.digest_key("n" * 64))
    @channel = @collector.notification_channels.create!(
      kind: "email",
      label: "Owner",
      destination: "owner@example.com"
    )
    @delivery = @channel.notification_deliveries.create!(
      event_type: "test",
      payload: { event: "test" }.to_json,
      idempotency_key: SecureRandom.uuid,
      next_attempt_at: Time.current
    )
  end

  test "delivers email through the durable outbox" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      NotificationDispatcher.new(now: Time.current).deliver(@delivery)
    end

    assert_equal "sent", @delivery.reload.status
    assert @delivery.delivered_at
  end

  test "records a failure and backs off" do
    @channel.update!(kind: "webhook", destination: "http://127.0.0.1:1/alerts")
    NotificationDispatcher.new(now: Time.current).deliver(@delivery)

    assert_equal "failed", @delivery.reload.status
    assert_equal 1, @delivery.attempts
    assert_match "non-public address", @delivery.last_error
    assert_operator @delivery.next_attempt_at, :>, Time.current
  end
end
