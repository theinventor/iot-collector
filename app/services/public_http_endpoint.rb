require "ipaddr"
require "socket"
require "uri"

class PublicHttpEndpoint
  class UnsafeAddress < StandardError; end

  BLOCKED_RANGES = %w[
    0.0.0.0/8
    10.0.0.0/8
    100.64.0.0/10
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.0.0.0/24
    192.0.2.0/24
    192.168.0.0/16
    198.18.0.0/15
    198.51.100.0/24
    203.0.113.0/24
    224.0.0.0/4
    240.0.0.0/4
    ::/128
    ::1/128
    ::ffff:0:0/96
    2001:db8::/32
    fc00::/7
    fe80::/10
    ff00::/8
  ].map { |range| IPAddr.new(range) }.freeze

  attr_reader :uri, :ip_address

  def initialize(url, resolver: nil)
    @uri = URI.parse(url)
    raise UnsafeAddress, "webhook must use HTTP or HTTPS" unless uri.is_a?(URI::HTTP) && uri.host.present?

    addresses = Array((resolver || method(:resolve)).call(uri.host)).uniq
    raise UnsafeAddress, "webhook host did not resolve" if addresses.empty?
    raise UnsafeAddress, "webhook host resolves to a non-public address" unless addresses.all? { |address| public_address?(address) }

    @ip_address = addresses.first
  rescue URI::InvalidURIError, SocketError => error
    raise UnsafeAddress, error.message
  end

  private

  def resolve(host)
    Addrinfo.getaddrinfo(host, nil, :UNSPEC, :STREAM).map(&:ip_address)
  end

  def public_address?(address)
    ip = IPAddr.new(address)
    BLOCKED_RANGES.none? { |range| range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end
end
