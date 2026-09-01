class AlertNotificationPlanner
  def initialize(incident)
    @incident = incident
    @rule = incident.alert_rule
    @collector = @rule.device.collector
  end

  def enqueue!(event_type, now: Time.current, sequence: nil)
    payload = AlertNotificationPayload.new(
      incident: @incident,
      event_type: event_type,
      occurred_at: now
    ).as_json.to_json

    @collector.notification_channels.where(enabled: true).find_each do |channel|
      next unless channel.accepts_severity?(@rule.severity)

      key_parts = [ @incident.id, event_type, sequence, channel.id ].compact
      channel.notification_deliveries.create_or_find_by!(idempotency_key: key_parts.join(":")) do |delivery|
        delivery.alert_incident = @incident
        delivery.event_type = event_type
        delivery.status = "pending"
        delivery.payload = payload
        delivery.next_attempt_at = channel.next_allowed_at(now, severity: @rule.severity)
      end
    end
  end
end
