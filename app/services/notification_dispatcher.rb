class NotificationDispatcher
  RETRY_INTERVALS = [ 1.minute, 5.minutes, 15.minutes, 1.hour ].freeze

  def initialize(now: Time.current, collector: nil, limit: 100)
    @now = now
    @collector = collector
    @limit = limit
  end

  def call
    recover_abandoned_deliveries
    deliveries.limit(@limit).find_each { |delivery| deliver(delivery) }
  end

  def deliver(delivery)
    delivery.with_lock do
      return unless %w[pending failed].include?(delivery.status)
      return if delivery.next_attempt_at > @now

      delivery.update!(status: "delivering", attempts: delivery.attempts + 1, last_error: nil)
    end

    NotificationSender.new(delivery).call
    delivery.update!(status: "sent", delivered_at: Time.current, last_error: nil)
  rescue StandardError => error
    retry_interval = RETRY_INTERVALS[[ delivery.attempts - 1, RETRY_INTERVALS.length - 1 ].min]
    delivery.update!(
      status: "failed",
      next_attempt_at: @now + retry_interval,
      last_error: "#{error.class}: #{error.message}".first(2_000)
    )
  end

  private

  def deliveries
    scope = NotificationDelivery.due(@now).includes(notification_channel: :collector)
    @collector ? scope.where(notification_channels: { collector_id: @collector.id }) : scope
  end

  def recover_abandoned_deliveries
    scope = NotificationDelivery.where(status: "delivering", updated_at: ...10.minutes.ago)
    scope = scope.joins(:notification_channel).where(notification_channels: { collector_id: @collector.id }) if @collector
    scope.update_all(status: "failed", next_attempt_at: @now, last_error: "delivery worker interrupted")
  end
end
