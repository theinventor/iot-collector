class NotificationDelivery < ApplicationRecord
  STATUSES = %w[pending delivering sent failed].freeze
  EVENT_TYPES = %w[trigger reminder recovery test].freeze

  belongs_to :notification_channel
  belongs_to :alert_incident, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :payload, :idempotency_key, :next_attempt_at, presence: true
  validates :idempotency_key, uniqueness: true

  scope :due, ->(now = Time.current) {
    where(status: %w[pending failed]).where(next_attempt_at: ..now).order(:next_attempt_at, :id)
  }

  def payload_hash
    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end
end
