require "net/http"
require "uri"

class NotificationSender
  class DeliveryError < StandardError; end

  def initialize(delivery)
    @delivery = delivery
    @channel = delivery.notification_channel
  end

  def call
    case @channel.kind
    when "email" then deliver_email
    when "webhook" then deliver_webhook
    else raise DeliveryError, "unsupported notification channel"
    end
  end

  private

  def deliver_email
    if Rails.env.production? && ENV["SMTP_ADDRESS"].blank?
      raise DeliveryError, "SMTP_ADDRESS is not configured"
    end

    AlertMailer.with(delivery: @delivery).notification.deliver_now
  end

  def deliver_webhook
    endpoint = PublicHttpEndpoint.new(@channel.destination)
    uri = endpoint.uri
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "IoT-Collector-Alerts/1.0"
    request["X-IoT-Collector-Event"] = @delivery.event_type
    request.body = @delivery.payload

    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = endpoint.ip_address
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10
    response = http.start { |client| client.request(request) }

    return if response.is_a?(Net::HTTPSuccess)

    raise DeliveryError, "webhook returned HTTP #{response.code}"
  rescue URI::InvalidURIError, PublicHttpEndpoint::UnsafeAddress => error
    raise DeliveryError, error.message
  end
end
