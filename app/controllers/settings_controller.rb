class SettingsController < ApplicationController
  before_action :authenticate_collector!

  def show
    @notification_channels = collector.notification_channels.order(enabled: :desc, label: :asc)
  end

  def update
    if collector.update(settings_params)
      redirect_to settings_path, notice: "Settings updated."
    else
      @notification_channels = collector.notification_channels.order(enabled: :desc, label: :asc)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:collector).permit(:time_zone)
  end
end
