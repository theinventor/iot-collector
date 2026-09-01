class DashboardController < ApplicationController
  before_action :authenticate_collector!

  def index
    @devices = collector.devices.order(Arel.sql("last_seen_at IS NULL ASC"), last_seen_at: :desc, identifier: :asc)
    @latest_reading = collector.readings.recent.first
    @total_readings = collector.readings.count
    @total_measurements = collector.measurements.count
    @active_incidents = collector.alert_incidents.active
      .includes(alert_rule: :device)
      .order(Arel.sql("CASE alert_rules.severity WHEN 'critical' THEN 0 ELSE 1 END"), triggered_at: :desc)
    @active_incidents_by_device = @active_incidents.group_by { |incident| incident.alert_rule.device_id }
  end
end
