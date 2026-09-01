class AlertIncidentsController < ApplicationController
  SNOOZE_MINUTES = [ 15, 60, 240, 1_440 ].freeze

  before_action :authenticate_collector!
  before_action :set_device_and_incident

  def acknowledge
    @incident.update!(acknowledged_at: Time.current, next_notification_at: nil)
    redirect_to device_path(@device, anchor: "active-alerts"), notice: "Alert acknowledged."
  end

  def snooze
    minutes = params[:minutes].to_i
    minutes = 60 unless SNOOZE_MINUTES.include?(minutes)
    snoozed_until = Time.current + minutes.minutes
    @incident.update!(snoozed_until: snoozed_until, next_notification_at: snoozed_until)
    redirect_to device_path(@device, anchor: "active-alerts"), notice: "Alert snoozed."
  end

  private

  def set_device_and_incident
    @device = collector.devices.find_by!(identifier: Device.normalize_identifier(params[:device_identifier]))
    @incident = @device.alert_incidents.active.find(params[:id])
  end
end
