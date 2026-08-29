class Device < ApplicationRecord
  has_many :readings, dependent: :destroy
  has_many :measurements, dependent: :destroy

  validates :identifier, presence: true, uniqueness: true, length: { maximum: 80 }

  def self.normalize_identifier(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").presence || "unknown"
  end

  def display_name
    name.presence || identifier
  end

  def latest_reading
    readings.order(recorded_at: :desc, id: :desc).first
  end

  def latest_measurements
    measurements.order(recorded_at: :desc, id: :desc).each_with_object({}) do |measurement, latest|
      latest[measurement.name] ||= measurement
    end
  end
end
