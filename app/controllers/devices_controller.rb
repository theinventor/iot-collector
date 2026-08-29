class DevicesController < ApplicationController
  def show
    @device = Device.find(params[:id])
    @latest_measurements = @device.latest_measurements
    @readings = @device.readings.recent.includes(:measurements).limit(100)
    @numeric_metric_names = @device.measurements.where.not(numeric_value: nil).distinct.order(:name).limit(12).pluck(:name)
  end
end
