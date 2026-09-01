require "test_helper"

class PublicHttpEndpointTest < ActiveSupport::TestCase
  test "accepts a public address and pins the resolved IP" do
    endpoint = PublicHttpEndpoint.new(
      "https://hooks.example.com/alerts",
      resolver: ->(_host) { [ "93.184.216.34" ] }
    )

    assert_equal "hooks.example.com", endpoint.uri.host
    assert_equal "93.184.216.34", endpoint.ip_address
  end

  test "rejects private, loopback, link-local, and mixed DNS answers" do
    %w[127.0.0.1 10.0.0.1 169.254.169.254 ::1 fc00::1].each do |address|
      assert_raises(PublicHttpEndpoint::UnsafeAddress) do
        PublicHttpEndpoint.new("https://hooks.example.com", resolver: ->(_host) { [ address ] })
      end
    end

    assert_raises(PublicHttpEndpoint::UnsafeAddress) do
      PublicHttpEndpoint.new(
        "https://hooks.example.com",
        resolver: ->(_host) { [ "93.184.216.34", "127.0.0.1" ] }
      )
    end
  end
end
