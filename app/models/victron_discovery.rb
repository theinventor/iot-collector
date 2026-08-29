class VictronDiscovery < ApplicationRecord
  belongs_to :collector

  before_validation :normalize_attributes

  validates :logger_identifier, presence: true, length: { maximum: 80 }
  validates :mac_address,
    presence: true,
    format: { with: VictronSlot::MAC_PATTERN },
    uniqueness: { scope: [ :collector_id, :logger_identifier ] }
  validates :product_id, numericality: { only_integer: true, in: 0..65_535 }
  validates :rssi, numericality: { only_integer: true, in: -127..20 }
  validates :last_seen_at, presence: true

  private

  def normalize_attributes
    self.logger_identifier = Device.normalize_identifier(logger_identifier)
    self.mac_address = VictronSlot.normalize_mac(mac_address)
  end
end
