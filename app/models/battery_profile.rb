class BatteryProfile < ApplicationRecord
  CHEMISTRIES = {
    "lifepo4" => "Lithium iron phosphate (LiFePO4)",
    "agm" => "AGM lead-acid",
    "flooded" => "Flooded lead-acid",
    "gel" => "Gel lead-acid",
    "other" => "Other / custom"
  }.freeze

  belongs_to :device

  validates :chemistry, inclusion: { in: CHEMISTRIES.keys }
  validates :nominal_voltage, :rated_capacity_ah,
    numericality: { greater_than: 0 }, allow_nil: true
  validates :usable_capacity_percent,
    numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :reserve_percent,
    numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :low_voltage_warning, :low_voltage_critical,
    numericality: { greater_than: 0 }, allow_nil: true
  validate :critical_voltage_is_below_warning

  def chemistry_name
    CHEMISTRIES.fetch(chemistry)
  end

  def usable_capacity_ah
    return unless rated_capacity_ah

    rated_capacity_ah * usable_capacity_percent / 100
  end

  def estimated_remaining_ah(state_of_charge)
    return unless rated_capacity_ah && state_of_charge

    rated_capacity_ah * BigDecimal(state_of_charge.to_s) / 100
  end

  private

  def critical_voltage_is_below_warning
    return if low_voltage_warning.blank? || low_voltage_critical.blank?
    return if low_voltage_critical < low_voltage_warning

    errors.add(:low_voltage_critical, "must be below the warning voltage")
  end
end
