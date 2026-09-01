class AlertRulesController < ApplicationController
  before_action :authenticate_collector!
  before_action :set_device
  before_action :set_rule, only: [ :edit, :update, :toggle ]

  def new
    @alert_rule = @device.alert_rules.new(
      rule_type: params[:rule_type].presence || "threshold",
      severity: "warning",
      trigger_after_seconds: 5.minutes.to_i,
      recovery_after_seconds: 10.minutes.to_i,
      minimum_samples: 2,
      notify_recovery: true,
      enabled: true
    )
    @alert_rule.metric_name = metric_names.first
    @alert_rule.reminder_intervals_seconds = AlertRule::DEFAULT_REMINDERS.fetch(@alert_rule.severity)
  end

  def create
    @alert_rule = @device.alert_rules.new(rule_params)
    if @alert_rule.save
      redirect_to device_path(@device, anchor: "alerts"), notice: "Alert rule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @alert_rule.update(rule_params)
      redirect_to device_path(@device, anchor: "alerts"), notice: "Alert rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle
    if @alert_rule.enabled?
      AlertRuleDisabler.new(@alert_rule).call
      message = "Alert rule disabled."
    else
      @alert_rule.update!(enabled: true)
      message = "Alert rule enabled."
    end
    redirect_to device_path(@device, anchor: "alerts"), notice: message
  end

  private

  def set_device
    @device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:device_identifier]))
  end

  def set_rule
    @alert_rule = @device.alert_rules.find(params[:id])
  end

  def metric_names
    @metric_names ||= @device.measurements.where.not(numeric_value: nil).distinct.order(:name).pluck(:name)
  end
  helper_method :metric_names

  def rule_params
    params.require(:alert_rule).permit(
      :name,
      :rule_type,
      :metric_name,
      :comparison,
      :threshold,
      :upper_threshold,
      :recovery_threshold,
      :recovery_upper_threshold,
      :severity,
      :trigger_after_minutes,
      :recovery_after_minutes,
      :minimum_samples,
      :reminder_minutes,
      :notify_recovery
    )
  end
end
