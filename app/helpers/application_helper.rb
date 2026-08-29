module ApplicationHelper
  CHART_WIDTH = 800.0
  CHART_HEIGHT = 220.0
  CHART_PADDING_X = 24.0
  CHART_PADDING_Y = 20.0

  def telemetry_chart(points, starts_at:, ends_at:)
    values = points.map(&:value)
    time_min = starts_at.to_f
    time_max = ends_at.to_f
    value_min, value_max = values.minmax

    time_span = [ time_max - time_min, 1.0 ].max
    value_padding = value_min == value_max ? [ value_min.abs * 0.02, 0.5 ].max : 0.0
    value_min -= value_padding
    value_max += value_padding
    value_span = [ value_max - value_min, 0.001 ].max
    plot_width = CHART_WIDTH - (CHART_PADDING_X * 2)
    plot_height = CHART_HEIGHT - (CHART_PADDING_Y * 2)

    coordinates = points.map do |point|
      x = CHART_PADDING_X + ((point.recorded_at.to_f - time_min) / time_span * plot_width)
      y = CHART_HEIGHT - CHART_PADDING_Y - ((point.value - value_min) / value_span * plot_height)
      [ x.round(2), y.round(2) ]
    end

    {
      line: coordinates.map { |x, y| "#{x},#{y}" }.join(" "),
      area: ([ [ coordinates.first.first, CHART_HEIGHT - CHART_PADDING_Y ] ] + coordinates +
        [ [ coordinates.last.first, CHART_HEIGHT - CHART_PADDING_Y ] ]).map { |x, y| "#{x},#{y}" }.join(" "),
      latest_x: coordinates.last.first,
      latest_y: coordinates.last.last
    }
  end

  def metric_value(value, unit = nil)
    formatted = number_with_precision(value, precision: 3, strip_insignificant_zeros: true, delimiter: ",")
    unit.present? ? "#{formatted} #{unit}" : formatted
  end
end
