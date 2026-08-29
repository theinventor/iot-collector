class DashboardController < ApplicationController
  before_action :authenticate_collector!

  def index
    @devices = collector.devices.order(Arel.sql("last_seen_at IS NULL ASC"), last_seen_at: :desc, identifier: :asc)
    @latest_reading = collector.readings.recent.first
    @total_readings = collector.readings.count
    @total_measurements = collector.measurements.count
  end
end
