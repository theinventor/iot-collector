class AlertIncidentManager
  def self.activate!(rule:, state:, started_at:, triggered_at:, value:, now: Time.current)
    incident = rule.alert_incidents.create!(
      started_at: started_at,
      triggered_at: triggered_at,
      trigger_value: value,
      last_value: value,
      worst_value: value
    )

    state.update!(
      status: "active",
      active_incident: incident,
      active_since: triggered_at,
      pending_since: nil,
      recovering_since: nil,
      consecutive_samples: 0,
      recovery_samples: 0,
      last_sample_at: triggered_at,
      last_value: value
    )

    AlertNotificationPlanner.new(incident).enqueue!("trigger", now: now)
    schedule_next_reminder!(incident, from: now)
    incident
  end

  def self.resolve!(state:, resolved_at:, value:, reason: "condition_cleared", now: Time.current)
    incident = state.active_incident
    return state.reset_to_normal! unless incident

    incident.update!(
      resolved_at: resolved_at,
      last_value: value,
      next_notification_at: nil,
      resolution_reason: reason
    )
    AlertNotificationPlanner.new(incident).enqueue!("recovery", now: now) if incident.alert_rule.notify_recovery?
    state.reset_to_normal!
  end

  def self.update_value!(incident, value)
    return unless incident

    incident.update!(last_value: value, worst_value: worst_value(incident, value))
  end

  def self.schedule_next_reminder!(incident, from:)
    interval = incident.alert_rule.next_reminder_interval(incident.reminder_step)
    incident.update!(next_notification_at: interval ? from + interval : nil)
  end

  def self.worst_value(incident, value)
    return value if incident.worst_value.nil? || value.nil?

    rule = incident.alert_rule
    current = BigDecimal(incident.worst_value.to_s)
    candidate = BigDecimal(value.to_s)

    case rule.comparison
    when "below"
      [ current, candidate ].min
    when "above"
      [ current, candidate ].max
    when "outside"
      outside_distance(rule, candidate) > outside_distance(rule, current) ? candidate : current
    else
      candidate
    end
  end

  def self.outside_distance(rule, value)
    return rule.threshold - value if value < rule.threshold
    return value - rule.upper_threshold if value > rule.upper_threshold

    0
  end

  private_class_method :worst_value, :outside_distance
end
