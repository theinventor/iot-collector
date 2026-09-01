class BatteryProfilesController < ApplicationController
  before_action :authenticate_collector!
  before_action :set_device

  def create
    profile = @device.build_battery_profile(profile_params)
    save(profile)
  end

  def update
    profile = @device.battery_profile || @device.build_battery_profile
    profile.assign_attributes(profile_params)
    save(profile)
  end

  def destroy
    @device.battery_profile&.destroy!
    redirect_to device_path(@device, anchor: "battery-profile"), notice: "Battery profile removed."
  end

  private

  def set_device
    @device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:device_identifier]))
  end

  def profile_params
    params.require(:battery_profile).permit(
      :chemistry,
      :nominal_voltage,
      :rated_capacity_ah,
      :usable_capacity_percent,
      :reserve_percent,
      :low_voltage_warning,
      :low_voltage_critical
    )
  end

  def save(profile)
    if profile.save
      redirect_to device_path(@device, anchor: "battery-profile"), notice: "Battery profile updated."
    else
      load_device_page(profile)
      render "devices/show", status: :unprocessable_entity
    end
  end

  def load_device_page(profile)
    @range = TelemetryRange.new(params[:range])
    @report = DeviceReport.new(device: @device, range: @range)
    @latest_measurements = @device.latest_measurements
    @readings = @range.apply(@device.readings).recent.includes(:measurements).limit(100)
    @numeric_metric_names = @report.series.map(&:name)
    @battery_profile = profile
    @alert_rules = @device.alert_rules.includes(:alert_rule_state).order(enabled: :desc, severity: :desc, name: :asc)
    @active_incidents = @device.active_alert_incidents.includes(:alert_rule)
    @incidents = @device.alert_incidents.includes(:alert_rule).recent.limit(25)
  end
end
