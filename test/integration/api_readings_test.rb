require "test_helper"

class ApiReadingsTest < ActionDispatch::IntegrationTest
  setup do
    @original_key = Rails.application.config.x.iot_collector_ingest_key
    Rails.application.config.x.iot_collector_ingest_key = "test-key"
  end

  teardown do
    Rails.application.config.x.iot_collector_ingest_key = @original_key
  end

  test "accepts JSON readings with metric objects" do
    post "/api/v1/readings?key=test-key",
      params: {
        device: "RV Charger",
        name: "RV Charger",
        recorded_at: "2026-08-29T09:00:00-07:00",
        metrics: {
          voltage: { value: 14.39, unit: "V" },
          current: { value: 2.3, unit: "A" },
          charge_state: "absorption"
        }
      },
      as: :json

    assert_response :created

    body = JSON.parse(response.body)
    assert_equal true, body.fetch("ok")
    assert_equal "rv_charger", body.fetch("device")
    assert_equal 3, body.fetch("metrics")

    device = Device.find_by!(identifier: "rv_charger")
    assert_equal "RV Charger", device.name
    assert_equal 1, device.readings.count
    assert_equal BigDecimal("14.39"), device.measurements.find_by!(name: "voltage").numeric_value
    assert_equal "absorption", device.measurements.find_by!(name: "charge_state").text_value
  end

  test "accepts query string readings from simple clients" do
    get "/api/v1/readings",
      params: {
        key: "test-key",
        device: "atom-lite-test",
        voltage: "13.38",
        current: "3.0",
        rssi: "-99",
        charge_state: "bulk"
      }

    assert_response :created

    device = Device.find_by!(identifier: "atom_lite_test")
    assert_equal 4, device.measurements.count
    assert_equal BigDecimal("13.38"), device.measurements.find_by!(name: "voltage").numeric_value
    assert_equal "bulk", device.measurements.find_by!(name: "charge_state").text_value
  end

  test "rejects bad keys" do
    post "/api/v1/readings?key=wrong",
      params: { device: "rv_charger", metrics: { voltage: 12.7 } },
      as: :json

    assert_response :unauthorized
    assert_equal 0, Reading.count
  end

  test "rejects payloads with no metrics" do
    post "/api/v1/readings?key=test-key",
      params: { device: "rv_charger" },
      as: :json

    assert_response :unprocessable_entity
    assert_equal 0, Reading.count
  end

  test "rejects malformed JSON cleanly" do
    post "/api/v1/readings?key=test-key",
      params: '{"device":"rv_charger","metrics":{"ac_current":{"value":nan}}}',
      headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_equal({ "ok" => false, "error" => "malformed JSON" }, JSON.parse(response.body))
    assert_equal 0, Reading.count
  end
end
