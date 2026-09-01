class DevicesController < ApplicationController
  before_action :authenticate_collector!

  def show
    @device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:identifier]))
    @range = TelemetryRange.new(params[:range])
    @report = DeviceReport.new(device: @device, range: @range)
    @latest_measurements = @device.latest_measurements
    @readings = @range.apply(@device.readings).recent.includes(:measurements).limit(100)
    @numeric_metric_names = @report.series.map(&:name)
    @battery_profile = @device.battery_profile || @device.build_battery_profile
    @alert_rules = @device.alert_rules.includes(:alert_rule_state, alert_incidents: :notification_deliveries).order(enabled: :desc, severity: :desc, name: :asc)
    @active_incidents = @device.active_alert_incidents.includes(:alert_rule)
    @incidents = @device.alert_incidents.includes(:alert_rule).recent.limit(25)

    respond_to do |format|
      format.html
      format.csv do
        send_data DeviceCsvExport.new(device: @device, range: @range).generate,
          filename: "#{@device.identifier}-#{@range.key}.csv",
          type: "text/csv"
      end
    end
  end
end
