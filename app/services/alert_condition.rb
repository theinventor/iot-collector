class AlertCondition
  Result = Data.define(:breached?, :recovered?)

  def initialize(rule:, value:)
    @rule = rule
    @value = BigDecimal(value.to_s)
  end

  def call
    case @rule.comparison
    when "below"
      Result.new(@value <= @rule.threshold, @value >= @rule.recovery_threshold)
    when "above"
      Result.new(@value >= @rule.threshold, @value <= @rule.recovery_threshold)
    when "outside"
      Result.new(
        @value <= @rule.threshold || @value >= @rule.upper_threshold,
        @value >= @rule.recovery_threshold && @value <= @rule.recovery_upper_threshold
      )
    when "equal"
      Result.new(@value == @rule.threshold, @value != @rule.threshold)
    when "not_equal"
      Result.new(@value != @rule.threshold, @value == @rule.threshold)
    else
      Result.new(false, false)
    end
  end
end
