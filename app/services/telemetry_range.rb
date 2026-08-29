class TelemetryRange
  OPTIONS = {
    "1h" => { duration: 1.hour, label: "1 hour" },
    "6h" => { duration: 6.hours, label: "6 hours" },
    "24h" => { duration: 24.hours, label: "24 hours" },
    "7d" => { duration: 7.days, label: "7 days" },
    "30d" => { duration: 30.days, label: "30 days" }
  }.freeze
  DEFAULT_KEY = "24h"

  attr_reader :key, :starts_at, :ends_at

  def initialize(key, now: Time.current)
    @key = OPTIONS.key?(key.to_s) ? key.to_s : DEFAULT_KEY
    @ends_at = now
    @starts_at = now - OPTIONS.fetch(@key).fetch(:duration)
  end

  def label
    OPTIONS.fetch(key).fetch(:label)
  end

  def apply(scope)
    scope.where(recorded_at: starts_at..ends_at)
  end
end
