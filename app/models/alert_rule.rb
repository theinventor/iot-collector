class AlertRule < ApplicationRecord
  RULE_TYPES = {
    "threshold" => "Metric threshold",
    "missing_data" => "Missing telemetry"
  }.freeze
  COMPARISONS = {
    "below" => "falls below",
    "above" => "rises above",
    "outside" => "moves outside",
    "equal" => "equals",
    "not_equal" => "does not equal"
  }.freeze
  SEVERITIES = %w[warning critical].freeze
  DEFAULT_REMINDERS = {
    "warning" => [ 1.hour.to_i, 6.hours.to_i, 1.day.to_i ],
    "critical" => [ 15.minutes.to_i, 1.hour.to_i, 4.hours.to_i ]
  }.freeze

  belongs_to :device
  has_one :alert_rule_state, dependent: :destroy
  has_many :alert_incidents, dependent: :destroy

  scope :enabled, -> { where(enabled: true) }

  before_validation :normalize_fields
  before_validation :set_default_recovery_thresholds
  before_validation :set_default_reminders, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :rule_type, inclusion: { in: RULE_TYPES.keys }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :trigger_after_seconds, :recovery_after_seconds,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 30.days.to_i }
  validates :minimum_samples,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :metric_name, presence: true, length: { maximum: 80 }, if: :threshold_rule?
  validates :comparison, inclusion: { in: COMPARISONS.keys }, if: :threshold_rule?
  validates :threshold, numericality: true, presence: true, if: :threshold_rule?
  validates :upper_threshold, numericality: true, presence: true, if: :outside_comparison?
  validate :outside_threshold_order
  validate :recovery_thresholds_create_hysteresis
  validate :reminder_schedule_is_valid

  def threshold_rule?
    rule_type == "threshold"
  end

  def missing_data_rule?
    rule_type == "missing_data"
  end

  def outside_comparison?
    threshold_rule? && comparison == "outside"
  end

  def state_record
    alert_rule_state || create_alert_rule_state!
  end

  def reminder_intervals_seconds
    JSON.parse(self[:reminder_intervals].presence || "[]").filter_map do |value|
      Integer(value, exception: false)&.then { |seconds| seconds if seconds.positive? }
    end
  rescue JSON::ParserError
    []
  end

  def reminder_intervals_seconds=(values)
    self[:reminder_intervals] = Array(values).map(&:to_i).select(&:positive?).uniq.to_json
  end

  def reminder_minutes
    reminder_intervals_seconds.map { |seconds| seconds / 60 }.join(", ")
  end

  def reminder_minutes=(value)
    @reminder_schedule_supplied = true
    @invalid_reminder_schedule = false
    values = value.to_s.split(",").map(&:strip).reject(&:blank?)
    minutes = values.map { |entry| Integer(entry, exception: false) }
    @invalid_reminder_schedule = minutes.any?(&:nil?) || minutes.any? { |entry| entry <= 0 }
    self.reminder_intervals_seconds = @invalid_reminder_schedule ? [] : minutes.map { |entry| entry * 60 }
  end

  def trigger_after_minutes
    trigger_after_seconds.to_f / 60
  end

  def trigger_after_minutes=(value)
    self.trigger_after_seconds = (BigDecimal(value.to_s.presence || "0") * 60).to_i
  rescue ArgumentError
    self.trigger_after_seconds = nil
  end

  def recovery_after_minutes
    recovery_after_seconds.to_f / 60
  end

  def recovery_after_minutes=(value)
    self.recovery_after_seconds = (BigDecimal(value.to_s.presence || "0") * 60).to_i
  rescue ArgumentError
    self.recovery_after_seconds = nil
  end

  def next_reminder_interval(step)
    intervals = reminder_intervals_seconds
    intervals[[ step, intervals.length - 1 ].min] if intervals.any?
  end

  def condition_description
    return "No telemetry for #{trigger_after_seconds / 60} minutes" if missing_data_rule?

    comparator = COMPARISONS.fetch(comparison)
    values = outside_comparison? ? "#{threshold} and #{upper_threshold}" : threshold.to_s
    "#{metric_name.humanize} #{comparator} #{values}"
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.metric_name = metric_name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").presence
  end

  def set_default_recovery_thresholds
    return unless threshold_rule?

    self.recovery_threshold ||= threshold
    self.recovery_upper_threshold ||= upper_threshold if outside_comparison?
  end

  def set_default_reminders
    return if @reminder_schedule_supplied || reminder_intervals_seconds.any?

    self.reminder_intervals_seconds = DEFAULT_REMINDERS.fetch(severity, DEFAULT_REMINDERS.fetch("warning"))
  end

  def outside_threshold_order
    return unless outside_comparison? && threshold && upper_threshold
    return if threshold < upper_threshold

    errors.add(:upper_threshold, "must be greater than the lower threshold")
  end

  def recovery_thresholds_create_hysteresis
    return unless threshold_rule? && threshold && recovery_threshold

    case comparison
    when "below"
      errors.add(:recovery_threshold, "must be at or above the trigger threshold") if recovery_threshold < threshold
    when "above"
      errors.add(:recovery_threshold, "must be at or below the trigger threshold") if recovery_threshold > threshold
    when "outside"
      validate_outside_recovery_thresholds
    end
  end

  def validate_outside_recovery_thresholds
    return unless upper_threshold && recovery_upper_threshold

    errors.add(:recovery_threshold, "must be at or above the lower trigger threshold") if recovery_threshold < threshold
    errors.add(:recovery_upper_threshold, "must be at or below the upper trigger threshold") if recovery_upper_threshold > upper_threshold
    errors.add(:recovery_upper_threshold, "must be greater than the lower recovery threshold") if recovery_upper_threshold <= recovery_threshold
  end

  def reminder_schedule_is_valid
    errors.add(:reminder_minutes, "must contain positive whole minutes") if @invalid_reminder_schedule
  end
end
