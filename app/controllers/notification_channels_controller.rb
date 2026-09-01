class NotificationChannelsController < ApplicationController
  before_action :authenticate_collector!
  before_action :set_channel, only: [ :edit, :update, :destroy, :test ]

  def new
    @notification_channel = collector.notification_channels.new(
      kind: params[:kind].presence || "email",
      minimum_severity: "warning",
      enabled: true,
      critical_bypass: true
    )
  end

  def create
    @notification_channel = collector.notification_channels.new(channel_params)
    if @notification_channel.save
      redirect_to settings_path, notice: "Notification channel created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @notification_channel.update(channel_params)
      redirect_to settings_path, notice: "Notification channel updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @notification_channel.destroy!
    redirect_to settings_path, notice: "Notification channel removed."
  end

  def test
    delivery = @notification_channel.notification_deliveries.create!(
      event_type: "test",
      status: "pending",
      payload: {
        event: "test",
        occurred_at: Time.current.utc.iso8601,
        collector: collector.name
      }.to_json,
      idempotency_key: "test:#{SecureRandom.uuid}",
      next_attempt_at: Time.current
    )
    NotificationDispatcher.new(now: Time.current).deliver(delivery)

    if delivery.reload.status == "sent"
      redirect_to settings_path, notice: "Test notification sent."
    else
      redirect_to settings_path, alert: "Test failed: #{delivery.last_error}"
    end
  end

  private

  def set_channel
    @notification_channel = collector.notification_channels.find(params[:id])
  end

  def channel_params
    params.require(:notification_channel).permit(
      :kind,
      :label,
      :destination,
      :enabled,
      :minimum_severity,
      :quiet_start,
      :quiet_end,
      :critical_bypass
    )
  end
end
