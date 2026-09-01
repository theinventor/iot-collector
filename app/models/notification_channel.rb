require "uri"

class NotificationChannel < ApplicationRecord
  KINDS = { "email" => "Email", "webhook" => "Webhook" }.freeze
  SEVERITIES = %w[warning critical].freeze

  belongs_to :collector
  has_many :notification_deliveries, dependent: :destroy

  before_validation :normalize_fields

  validates :kind, inclusion: { in: KINDS.keys }
  validates :label, presence: true, length: { maximum: 100 }
  validates :destination, presence: true, length: { maximum: 1_000 }
  validates :minimum_severity, inclusion: { in: SEVERITIES }
  validates :quiet_hours_start, :quiet_hours_end,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 1.day.to_i / 60 },
    allow_nil: true
  validate :destination_matches_kind
  validate :quiet_hours_are_complete
  validate :quiet_time_inputs_are_valid

  def accepts_severity?(severity)
    minimum_severity == "warning" || severity == "critical"
  end

  def quiet_start
    format_minutes(quiet_hours_start)
  end

  def quiet_start=(value)
    @quiet_start_invalid = value.present? && parse_minutes(value).nil?
    self.quiet_hours_start = parse_minutes(value)
  end

  def quiet_end
    format_minutes(quiet_hours_end)
  end

  def quiet_end=(value)
    @quiet_end_invalid = value.present? && parse_minutes(value).nil?
    self.quiet_hours_end = parse_minutes(value)
  end

  def next_allowed_at(time, severity:)
    return time unless quiet_hours?
    return time if severity == "critical" && critical_bypass?

    zone = Time.find_zone!(collector.time_zone)
    local = time.in_time_zone(zone)
    minute = local.hour * 60 + local.min
    return time unless quiet_at_minute?(minute)

    end_hour, end_minute = quiet_hours_end.divmod(60)
    quiet_end = local.change(hour: end_hour, min: end_minute, sec: 0)
    quiet_end += 1.day if quiet_hours_start > quiet_hours_end && minute >= quiet_hours_start
    quiet_end.utc
  end

  def masked_destination
    return destination unless kind == "email"

    local, domain = destination.split("@", 2)
    return destination unless local && domain

    "#{local.first}***@#{domain}"
  end

  private

  def normalize_fields
    self.label = label.to_s.strip
    self.destination = destination.to_s.strip
  end

  def destination_matches_kind
    case kind
    when "email"
      errors.add(:destination, "must be a valid email address") unless destination.match?(URI::MailTo::EMAIL_REGEXP)
    when "webhook"
      uri = URI.parse(destination)
      errors.add(:destination, "must be an HTTP or HTTPS URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
    end
  rescue URI::InvalidURIError
    errors.add(:destination, "must be a valid URL")
  end

  def quiet_hours?
    quiet_hours_start.present? && quiet_hours_end.present? && quiet_hours_start != quiet_hours_end
  end

  def quiet_at_minute?(minute)
    if quiet_hours_start < quiet_hours_end
      minute >= quiet_hours_start && minute < quiet_hours_end
    else
      minute >= quiet_hours_start || minute < quiet_hours_end
    end
  end

  def parse_minutes(value)
    return if value.blank?

    match = value.to_s.match(/\A(\d{1,2}):(\d{2})\z/)
    return unless match

    hour = match[1].to_i
    minute = match[2].to_i
    hour * 60 + minute if hour < 24 && minute < 60
  end

  def format_minutes(value)
    return if value.nil?

    hour, minute = value.divmod(60)
    format("%02d:%02d", hour, minute)
  end

  def quiet_hours_are_complete
    return if quiet_hours_start.nil? == quiet_hours_end.nil?

    errors.add(:quiet_hours_end, "must be set with a start time")
  end

  def quiet_time_inputs_are_valid
    errors.add(:quiet_hours_start, "is invalid") if @quiet_start_invalid
    errors.add(:quiet_hours_end, "is invalid") if @quiet_end_invalid
  end
end
