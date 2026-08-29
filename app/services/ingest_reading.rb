require "bigdecimal"
class IngestReading
  RESERVED_KEYS = %w[key controller action format device device_id name source ts timestamp recorded_at metrics].freeze
  NUMERIC_PATTERN = /\A-?\d+(\.\d+)?\z/

  class Unauthorized < StandardError; end
  class InvalidPayload < StandardError; end

  Result = Data.define(:device, :reading, :measurements)

  def initialize(params:, remote_ip:, user_agent:, now: Time.current)
    @params = normalize_hash(params)
    @remote_ip = remote_ip
    @user_agent = user_agent.to_s.first(255)
    @now = now
  end

  def call
    @collector = authenticate!

    device = find_or_create_device
    recorded_at = parse_time(@params["recorded_at"] || @params["timestamp"] || @params["ts"]) || @now
    metric_specs = extract_metrics
    raise InvalidPayload, "at least one metric is required" if metric_specs.empty?

    reading = nil
    measurements = []

    ApplicationRecord.transaction do
      reading = device.readings.create!(
        recorded_at: recorded_at,
        remote_ip: @remote_ip,
        user_agent: @user_agent,
        payload: JSON.generate(redacted_payload)
      )

      measurements = metric_specs.map do |spec|
        reading.measurements.create!(
          device: device,
          name: spec.fetch(:name),
          numeric_value: spec[:numeric_value],
          text_value: spec[:text_value],
          unit: spec[:unit],
          recorded_at: recorded_at
        )
      end

      device.update!(
        name: @params["name"].presence || device.name,
        last_seen_at: recorded_at,
        last_ip: @remote_ip,
        last_user_agent: @user_agent
      )
    end

    Result.new(device: device, reading: reading, measurements: measurements)
  end

  private

  def authenticate!
    Collector.find_or_create_for_ingest(@params["key"]) || raise(Unauthorized)
  end

  def find_or_create_device
    identifier = Device.normalize_identifier(@params["device"] || @params["device_id"] || @params["source"])
    @collector.devices.find_or_create_by!(identifier: identifier)
  end

  def extract_metrics
    raw_metrics = {}
    metrics_param = @params["metrics"]
    raw_metrics.merge!(normalize_hash(metrics_param)) if metrics_param.is_a?(Hash) || metrics_param.respond_to?(:to_unsafe_h)

    @params.each do |key, value|
      next if RESERVED_KEYS.include?(key.to_s)

      raw_metrics[key] = value
    end

    raw_metrics.filter_map do |name, value|
      normalize_metric(name, value)
    end.first(200)
  end

  def normalize_metric(name, value)
    metric_name = name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    return nil if metric_name.blank?

    value, unit = unpack_metric_value(value)
    return nil if value.nil? || (value.respond_to?(:blank?) && value.blank?)

    numeric_value = numeric_value_for(value)
    {
      name: metric_name.first(80),
      numeric_value: numeric_value,
      text_value: numeric_value.nil? ? value.to_s.first(255) : nil,
      unit: unit.to_s.first(32).presence
    }
  end

  def unpack_metric_value(value)
    return [ value, nil ] unless value.is_a?(Hash) || value.respond_to?(:to_unsafe_h)

    hash = normalize_hash(value)
    [ hash["value"], hash["unit"] ]
  end

  def numeric_value_for(value)
    case value
    when Numeric
      BigDecimal(value.to_s)
    when String
      stripped = value.strip
      BigDecimal(stripped) if stripped.match?(NUMERIC_PATTERN)
    end
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def redacted_payload
    @params.except("key", :key)
  end

  def normalize_hash(value)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    hash.deep_stringify_keys
  end
end
