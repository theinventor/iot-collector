class Reading < ApplicationRecord
  belongs_to :device
  has_many :measurements, dependent: :destroy

  validates :recorded_at, :payload, presence: true

  scope :recent, -> { order(recorded_at: :desc, id: :desc) }

  def payload_hash
    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end
end
