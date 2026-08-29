class VictronSlot < ApplicationRecord
  POSITIONS = (1..3).freeze
  MAC_PATTERN = /\A(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\z/
  BIND_KEY_PATTERN = /\A[0-9a-f]{32}\z/

  belongs_to :collector

  before_validation :normalize_attributes

  validates :logger_identifier, presence: true, length: { maximum: 80 }
  validates :position, inclusion: { in: POSITIONS }
  validates :enabled, inclusion: { in: [ true, false ] }
  validates :device_identifier, presence: true, length: { maximum: 80 }, if: :enabled?
  validates :name, presence: true, length: { maximum: 64 }, if: :enabled?
  validates :mac_address, presence: true, format: { with: MAC_PATTERN }, if: :enabled?
  validates :bind_key, presence: true, format: { with: BIND_KEY_PATTERN }, if: :enabled?
  validates :position, uniqueness: { scope: [ :collector_id, :logger_identifier ] }

  def self.normalize_mac(value)
    value.to_s.strip.downcase.tr("-", ":")
  end

  def disable
    assign_attributes(
      enabled: false,
      device_identifier: nil,
      name: nil,
      mac_address: nil,
      bind_key: nil
    )
  end

  private

  def normalize_attributes
    self.logger_identifier = Device.normalize_identifier(logger_identifier)
    return unless enabled?

    self.device_identifier = Device.normalize_identifier(device_identifier.presence || name)
    self.name = name.to_s.strip
    self.mac_address = self.class.normalize_mac(mac_address)
    self.bind_key = bind_key.to_s.strip.downcase
  end
end
