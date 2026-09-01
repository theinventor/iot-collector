class AlertRuleDisabler
  def initialize(rule, now: Time.current)
    @rule = rule
    @now = now
  end

  def call
    @rule.update!(enabled: false)
    state = @rule.state_record

    state.with_lock do
      incident = state.active_incident
      if incident&.active?
        incident.update!(
          resolved_at: @now,
          next_notification_at: nil,
          resolution_reason: "rule_disabled"
        )
      end
      state.reset_to_normal!
    end
  end
end
