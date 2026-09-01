class MissingDataAlertEvaluator
  def initialize(now: Time.current, collector: nil)
    @now = now
    @collector = collector
  end

  def call
    rules.find_each { |rule| evaluate(rule) }
  end

  private

  def rules
    scope = AlertRule.enabled.where(rule_type: "missing_data").includes(device: :collector)
    @collector ? scope.where(devices: { collector_id: @collector.id }) : scope
  end

  def evaluate(rule)
    state = rule.state_record
    last_seen_at = rule.device.last_seen_at || rule.device.created_at
    return unless last_seen_at && @now >= last_seen_at + rule.trigger_after_seconds

    state.with_lock do
      return if state.status == "active"

      if state.active_incident
        state.update!(status: "active", recovering_since: nil, recovery_samples: 0)
      else
        AlertIncidentManager.activate!(
          rule: rule,
          state: state,
          started_at: last_seen_at,
          triggered_at: @now,
          value: nil,
          now: @now
        )
      end
    end
  rescue StandardError => error
    Rails.logger.error("Missing-data evaluation failed for rule #{rule.id}: #{error.class}: #{error.message}")
  end
end
