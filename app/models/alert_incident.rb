class AlertIncident < ApplicationRecord
  belongs_to :alert_rule
  has_many :notification_deliveries, dependent: :nullify

  scope :active, -> { where(resolved_at: nil) }
  scope :recent, -> { order(triggered_at: :desc, id: :desc) }

  validates :started_at, :triggered_at, presence: true

  delegate :device, to: :alert_rule

  def active?
    resolved_at.nil?
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def snoozed?(now = Time.current)
    snoozed_until&.after?(now) || false
  end

  def display_status
    return "Resolved" unless active?
    return "Snoozed" if snoozed?
    return "Acknowledged" if acknowledged?

    "Active"
  end
end
