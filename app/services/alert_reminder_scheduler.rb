class AlertReminderScheduler
  def initialize(now: Time.current, collector: nil)
    @now = now
    @collector = collector
  end

  def call
    incidents.find_each { |incident| schedule(incident) }
  end

  private

  def incidents
    scope = AlertIncident.active.where(next_notification_at: ..@now).includes(alert_rule: { device: :collector })
    @collector ? scope.where(devices: { collector_id: @collector.id }) : scope
  end

  def schedule(incident)
    incident.with_lock do
      return unless incident.active? && incident.next_notification_at&.<=(@now)

      if incident.acknowledged?
        incident.update!(next_notification_at: nil)
        return
      end

      if incident.snoozed?(@now)
        incident.update!(next_notification_at: incident.snoozed_until)
        return
      end

      sequence = incident.reminder_step + 1
      AlertNotificationPlanner.new(incident).enqueue!("reminder", now: @now, sequence: sequence)
      incident.update!(reminder_step: sequence)
      AlertIncidentManager.schedule_next_reminder!(incident, from: @now)
    end
  rescue StandardError => error
    Rails.logger.error("Alert reminder failed for incident #{incident.id}: #{error.class}: #{error.message}")
  end
end
