class AlertProcessor
  def initialize(now: Time.current, collector: nil)
    @now = now
    @collector = collector
  end

  def call
    MissingDataAlertEvaluator.new(now: @now, collector: @collector).call
    AlertReminderScheduler.new(now: @now, collector: @collector).call
    NotificationDispatcher.new(now: @now, collector: @collector).call
  end
end
