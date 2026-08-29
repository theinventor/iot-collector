class DashboardController < ApplicationController
  def index
    @devices = Device.order(Arel.sql("last_seen_at IS NULL ASC"), last_seen_at: :desc, identifier: :asc)
    @latest_reading = Reading.recent.first
    @total_readings = Reading.count
    @total_measurements = Measurement.count
  end
end
