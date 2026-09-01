class AlertEvaluator
  def initialize(reading:, measurements:, now: Time.current)
    @reading = reading
    @measurements = measurements.index_by(&:name)
    @now = now
  end

  def call
    @reading.device.alert_rules.enabled.find_each do |rule|
      rule.threshold_rule? ? evaluate_threshold(rule) : evaluate_data_return(rule)
    rescue StandardError => error
      Rails.logger.error("Alert evaluation failed for rule #{rule.id}: #{error.class}: #{error.message}")
    end
  end

  private

  def evaluate_threshold(rule)
    measurement = @measurements[rule.metric_name]
    return unless measurement&.numeric_value

    state = rule.state_record
    value = measurement.numeric_value
    recorded_at = measurement.recorded_at

    state.with_lock do
      return if state.last_sample_at && recorded_at <= state.last_sample_at

      condition = AlertCondition.new(rule: rule, value: value).call
      case state.status
      when "normal"
        condition.breached? ? start_pending(rule, state, value, recorded_at) : record_sample(state, value, recorded_at)
      when "pending"
        condition.breached? ? continue_pending(rule, state, value, recorded_at) : reset_pending(state, value, recorded_at)
      when "active"
        handle_active(rule, state, condition, value, recorded_at)
      when "recovering"
        handle_recovering(rule, state, condition, value, recorded_at)
      end
    end
  end

  def evaluate_data_return(rule)
    state = rule.state_record
    return unless %w[active recovering].include?(state.status)

    recorded_at = @reading.recorded_at
    state.with_lock do
      return if state.last_sample_at && recorded_at <= state.last_sample_at

      if state.status == "active"
        state.update!(
          status: "recovering",
          recovering_since: recorded_at,
          recovery_samples: 1,
          last_sample_at: recorded_at
        )
      else
        state.update!(recovery_samples: state.recovery_samples + 1, last_sample_at: recorded_at)
      end

      resolve_if_recovered(rule, state, nil, recorded_at)
    end
  end

  def start_pending(rule, state, value, recorded_at)
    state.update!(
      status: "pending",
      pending_since: recorded_at,
      consecutive_samples: 1,
      last_sample_at: recorded_at,
      last_value: value
    )
    activate_if_ready(rule, state, value, recorded_at)
  end

  def continue_pending(rule, state, value, recorded_at)
    state.update!(
      consecutive_samples: state.consecutive_samples + 1,
      last_sample_at: recorded_at,
      last_value: value
    )
    activate_if_ready(rule, state, value, recorded_at)
  end

  def activate_if_ready(rule, state, value, recorded_at)
    elapsed = recorded_at - state.pending_since
    return if elapsed < rule.trigger_after_seconds || state.consecutive_samples < rule.minimum_samples

    AlertIncidentManager.activate!(
      rule: rule,
      state: state,
      started_at: state.pending_since,
      triggered_at: recorded_at,
      value: value,
      now: @now
    )
  end

  def reset_pending(state, value, recorded_at)
    state.update!(
      status: "normal",
      pending_since: nil,
      consecutive_samples: 0,
      last_sample_at: recorded_at,
      last_value: value
    )
  end

  def handle_active(rule, state, condition, value, recorded_at)
    AlertIncidentManager.update_value!(state.active_incident, value)

    if condition.recovered?
      state.update!(
        status: "recovering",
        recovering_since: recorded_at,
        recovery_samples: 1,
        last_sample_at: recorded_at,
        last_value: value
      )
      resolve_if_recovered(rule, state, value, recorded_at)
    else
      record_sample(state, value, recorded_at)
    end
  end

  def handle_recovering(rule, state, condition, value, recorded_at)
    AlertIncidentManager.update_value!(state.active_incident, value)

    if condition.recovered?
      state.update!(
        recovery_samples: state.recovery_samples + 1,
        last_sample_at: recorded_at,
        last_value: value
      )
      resolve_if_recovered(rule, state, value, recorded_at)
    else
      state.update!(
        status: "active",
        recovering_since: nil,
        recovery_samples: 0,
        last_sample_at: recorded_at,
        last_value: value
      )
    end
  end

  def resolve_if_recovered(rule, state, value, recorded_at)
    elapsed = recorded_at - state.recovering_since
    return if elapsed < rule.recovery_after_seconds || state.recovery_samples < rule.minimum_samples

    AlertIncidentManager.resolve!(state: state, resolved_at: recorded_at, value: value, now: @now)
  end

  def record_sample(state, value, recorded_at)
    state.update!(last_sample_at: recorded_at, last_value: value)
  end
end
