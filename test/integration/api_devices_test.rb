require "test_helper"

class ApiDevicesTest < ActionDispatch::IntegrationTest
  setup do
    @key = "c" * 64
    @other_key = "d" * 64
    upload(@key, "rv_charger", voltage: { value: 13.4, unit: "V" }, charge_state: "bulk")
    upload(@other_key, "private_device", voltage: 48.1)
  end

  test "status reports only the authorized collector" do
    get "/api/v1/status", headers: authorization(@key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body.fetch("ok")
    assert_equal 1, body.dig("collector", "devices_count")
    assert_equal 1, body.dig("collector", "readings_count")
    assert_equal 2, body.dig("collector", "measurements_count")
    assert body.dig("collector", "last_reading_at").present?
  end

  test "device index and details are isolated by key" do
    get "/api/v1/devices", headers: authorization(@key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "rv_charger" ], body.fetch("devices").pluck("identifier")
    assert_equal 13.4, body.dig("devices", 0, "latest", "voltage", "value")

    get "/api/v1/devices/private_device", headers: authorization(@key)
    assert_response :not_found

    get "/api/v1/devices/rv_charger", headers: authorization(@key)
    assert_response :success
    assert_equal [ "charge_state", "voltage" ], JSON.parse(response.body).dig("device", "metric_names")
  end

  test "readings API supports ranges and limits" do
    get "/api/v1/devices/rv_charger/readings",
      params: { range: "7d", limit: 10 },
      headers: authorization(@key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "7d", body.fetch("range")
    assert_equal 1, body.fetch("readings").size
    assert_equal "bulk", body.dig("readings", 0, "metrics", "charge_state", "value")
  end

  test "read APIs reject missing and unknown keys" do
    get "/api/v1/status"
    assert_response :unauthorized

    get "/api/v1/devices?key=#{"e" * 64}"
    assert_response :unauthorized
  end

  private

  def upload(key, device, metrics)
    post "/api/v1/readings",
      params: { key: key, device: device, metrics: metrics },
      as: :json
    assert_response :created
  end

  def authorization(key)
    { "Authorization" => "Bearer #{key}" }
  end
end
