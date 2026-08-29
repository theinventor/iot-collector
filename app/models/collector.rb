require "digest"

class Collector < ApplicationRecord
  MINIMUM_KEY_LENGTH = 32
  MAXIMUM_KEY_LENGTH = 256

  has_many :devices, dependent: :destroy
  has_many :readings, through: :devices
  has_many :measurements, through: :devices
  has_many :victron_slots, dependent: :destroy
  has_many :victron_discoveries, dependent: :destroy

  validates :key_digest, presence: true, uniqueness: true

  def self.find_by_key(key)
    normalized_key = key.to_s
    return if normalized_key.blank? || normalized_key.length > MAXIMUM_KEY_LENGTH

    find_by(key_digest: digest_key(normalized_key))
  end

  def self.find_or_create_for_ingest(key)
    normalized_key = key.to_s
    existing = find_by_key(normalized_key)
    return existing if existing
    return unless valid_key?(normalized_key)

    digest = digest_key(normalized_key)
    create_or_find_by!(key_digest: digest) do |collector|
      collector.name = "Collector #{digest.first(8)}"
    end
  end

  def self.digest_key(key)
    Digest::SHA256.hexdigest(key.to_s)
  end

  def self.valid_key?(key)
    key.length.between?(MINIMUM_KEY_LENGTH, MAXIMUM_KEY_LENGTH)
  end
end
