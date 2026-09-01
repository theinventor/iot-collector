class AlertPresetsController < ApplicationController
  before_action :authenticate_collector!

  def create
    device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:device_identifier]))
    BatteryAlertPresetInstaller.new(device).call
    redirect_to device_path(device, anchor: "alerts"), notice: "Recommended battery alerts installed."
  end
end
