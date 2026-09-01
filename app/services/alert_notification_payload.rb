class AlertNotificationPayload
  def initialize(incident:, event_type:, occurred_at: Time.current)
    @incident = incident
    @rule = incident.alert_rule
    @event_type = event_type
    @occurred_at = occurred_at
  end

  def as_json
    {
      event: @event_type,
      occurred_at: @occurred_at.utc.iso8601,
      severity: @rule.severity,
      collector: @rule.device.collector.name,
      device: {
        identifier: @rule.device.identifier,
        name: @rule.device.display_name
      },
      alert: {
        id: @incident.id,
        rule: @rule.name,
        metric: @rule.metric_name,
        condition: @rule.condition_description,
        trigger_value: decimal(@incident.trigger_value),
        current_value: decimal(@incident.last_value),
        worst_value: decimal(@incident.worst_value),
        started_at: @incident.started_at.utc.iso8601,
        triggered_at: @incident.triggered_at.utc.iso8601,
        resolved_at: @incident.resolved_at&.utc&.iso8601
      }
    }
  end

  private

  def decimal(value)
    value&.to_f
  end
end
