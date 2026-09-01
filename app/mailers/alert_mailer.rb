class AlertMailer < ApplicationMailer
  EVENT_LABELS = {
    "trigger" => "Alert",
    "reminder" => "Alert reminder",
    "recovery" => "Recovered",
    "test" => "Test notification"
  }.freeze

  def notification
    @delivery = params.fetch(:delivery)
    @payload = @delivery.payload_hash.deep_symbolize_keys
    @channel = @delivery.notification_channel
    @event_label = EVENT_LABELS.fetch(@delivery.event_type)

    mail(
      to: @channel.destination,
      subject: subject_line
    )
  end

  private

  def subject_line
    return "[IoT Collector] Test notification" if @delivery.event_type == "test"

    severity = @payload.fetch(:severity).to_s.upcase
    device = @payload.dig(:device, :name)
    rule = @payload.dig(:alert, :rule)
    "[#{severity}] #{device}: #{rule} #{@delivery.event_type == "recovery" ? "recovered" : ""}".strip
  end
end
