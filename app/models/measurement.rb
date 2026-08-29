class Measurement < ApplicationRecord
  belongs_to :device
  belongs_to :reading

  validates :name, :recorded_at, presence: true

  def display_value
    value = numeric_value.nil? ? text_value : numeric_value.to_f.round(4).to_s.sub(/\.0\z/, "")
    unit.present? ? "#{value} #{unit}" : value
  end
end
