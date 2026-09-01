class AlertRuleState < ApplicationRecord
  STATUSES = %w[normal pending active recovering].freeze

  belongs_to :alert_rule
  belongs_to :active_incident, class_name: "AlertIncident", optional: true

  validates :status, inclusion: { in: STATUSES }

  def reset_to_normal!
    update!(
      status: "normal",
      pending_since: nil,
      active_since: nil,
      recovering_since: nil,
      consecutive_samples: 0,
      recovery_samples: 0,
      active_incident: nil
    )
  end
end
