class DeviceReport
  MAX_CHART_POINTS = 240
  METRIC_PRIORITY = %w[
    state_of_charge
    voltage
    battery_voltage
    current
    battery_current
    power
    battery_power
    consumed_ah
    ac_current
  ].freeze

  Point = Data.define(:recorded_at, :value)
  Series = Data.define(:name, :unit, :points, :latest, :minimum, :maximum, :average, :change)

  attr_reader :device, :range

  def initialize(device:, range:)
    @device = device
    @range = range
  end

  def series
    @series ||= grouped_numeric_measurements.map do |name, measurements|
      values = measurements.map { |measurement| measurement.fetch(:value) }
      points = measurements.map { |measurement| Point.new(**measurement.slice(:recorded_at, :value)) }

      Series.new(
        name: name,
        unit: measurements.reverse_each.find { |measurement| measurement[:unit].present? }&.fetch(:unit),
        points: downsample(points),
        latest: values.last,
        minimum: values.min,
        maximum: values.max,
        average: values.sum / values.size,
        change: values.last - values.first
      )
    end.sort_by { |metric| metric_sort_key(metric.name) }
  end

  def reading_count
    @reading_count ||= range.apply(device.readings).count
  end

  private

  def grouped_numeric_measurements
    rows = range.apply(device.measurements.where.not(numeric_value: nil))
      .order(:recorded_at, :id)
      .pluck(:name, :numeric_value, :unit, :recorded_at)

    rows.each_with_object({}) do |(name, value, unit, recorded_at), groups|
      groups[name] ||= []
      groups[name] << { value: value.to_f, unit: unit, recorded_at: recorded_at }
    end
  end

  def downsample(points)
    return points if points.size <= MAX_CHART_POINTS

    step = (points.size - 1).fdiv(MAX_CHART_POINTS - 1)
    Array.new(MAX_CHART_POINTS) { |index| points[(index * step).round] }.uniq
  end

  def metric_sort_key(name)
    priority = METRIC_PRIORITY.index(name)
    [ priority ? 0 : 1, priority || name ]
  end
end
