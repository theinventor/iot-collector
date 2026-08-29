class DevicesController < ApplicationController
  before_action :authenticate_collector!

  def show
    @device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:identifier]))
    @range = TelemetryRange.new(params[:range])
    @report = DeviceReport.new(device: @device, range: @range)
    @latest_measurements = @device.latest_measurements
    @readings = @range.apply(@device.readings).recent.includes(:measurements).limit(100)
    @numeric_metric_names = @report.series.map(&:name)

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
