class BatteryAlertPresetInstaller
  def initialize(device)
    @device = device
    @profile = device.battery_profile
  end

  def call
    install(
      "low_soc_warning",
      name: "Low battery",
      metric_name: "state_of_charge",
      comparison: "below",
      threshold: 30,
      recovery_threshold: 35,
      severity: "warning",
      trigger_after_seconds: 5.minutes.to_i,
      recovery_after_seconds: 10.minutes.to_i,
      minimum_samples: 2
    )
    install(
      "low_soc_critical",
      name: "Critical battery",
      metric_name: "state_of_charge",
      comparison: "below",
      threshold: 15,
      recovery_threshold: 20,
      severity: "critical",
      trigger_after_seconds: 3.minutes.to_i,
      recovery_after_seconds: 10.minutes.to_i,
      minimum_samples: 2
    )
    install(
      "telemetry_missing",
      name: "Shunt telemetry missing",
      rule_type: "missing_data",
      severity: "warning",
      trigger_after_seconds: 30.minutes.to_i,
      recovery_after_seconds: 5.minutes.to_i,
      minimum_samples: 2
    )
    install(
      "victron_alarm",
      name: "Victron alarm",
      metric_name: "alarm_reason_code",
      comparison: "not_equal",
      threshold: 0,
      recovery_threshold: 0,
      severity: "critical",
      trigger_after_seconds: 0,
      recovery_after_seconds: 1.minute.to_i,
      minimum_samples: 1
    )
    install_capacity_rule if @profile&.rated_capacity_ah
    install_voltage_rules if @profile

    @device.alert_rules.where.not(preset_key: nil)
  end

  private

  def install(preset_key, attributes)
    rule = @device.alert_rules.find_or_initialize_by(preset_key: preset_key)
    return rule if rule.persisted?

    rule.assign_attributes({
      name: attributes.fetch(:name),
      rule_type: "threshold",
      severity: "warning",
      notify_recovery: true,
      enabled: true
    }.merge(attributes))
    rule.save!
    rule
  end

  def install_capacity_rule
    consumed_limit = -(@profile.rated_capacity_ah * (100 - @profile.reserve_percent) / 100)
    recovery_margin = @profile.rated_capacity_ah * 5 / 100
    install(
      "capacity_reserve",
      name: "Battery reserve reached",
      metric_name: "consumed_ah",
      comparison: "below",
      threshold: consumed_limit,
      recovery_threshold: consumed_limit + recovery_margin,
      severity: "critical",
      trigger_after_seconds: 5.minutes.to_i,
      recovery_after_seconds: 10.minutes.to_i,
      minimum_samples: 2
    )
  end

  def install_voltage_rules
    margin = voltage_recovery_margin
    if @profile.low_voltage_warning
      install(
        "low_voltage_warning",
        name: "Low battery voltage",
        metric_name: "battery_voltage",
        comparison: "below",
        threshold: @profile.low_voltage_warning,
        recovery_threshold: @profile.low_voltage_warning + margin,
        severity: "warning",
        trigger_after_seconds: 5.minutes.to_i,
        recovery_after_seconds: 10.minutes.to_i,
        minimum_samples: 2
      )
    end

    return unless @profile.low_voltage_critical

    install(
      "low_voltage_critical",
      name: "Critical battery voltage",
      metric_name: "battery_voltage",
      comparison: "below",
      threshold: @profile.low_voltage_critical,
      recovery_threshold: @profile.low_voltage_critical + margin,
      severity: "critical",
      trigger_after_seconds: 3.minutes.to_i,
      recovery_after_seconds: 10.minutes.to_i,
      minimum_samples: 2
    )
  end

  def voltage_recovery_margin
    nominal = @profile.nominal_voltage || 12
    [ nominal * BigDecimal("0.015"), BigDecimal("0.1") ].max
  end
end
