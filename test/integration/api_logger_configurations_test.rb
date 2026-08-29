require "test_helper"

class ApiLoggerConfigurationsTest < ActionDispatch::IntegrationTest
  setup do
    @key = "f" * 64
    @other_key = "e" * 64
    Collector.find_or_create_for_ingest(@key)
    Collector.find_or_create_for_ingest(@other_key)
  end

  test "config returns three empty slots" do
    get "/api/v1/loggers/ATOM%20Lite%20Logger/config", headers: authorization(@key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "atom_lite_logger", body.fetch("logger")
    assert_equal [ 1, 2, 3 ], body.fetch("slots").pluck("position")
    assert body.fetch("slots").none? { |slot| slot.fetch("configured") }
    assert body.fetch("slots").none? { |slot| slot.fetch("managed") }
  end

  test "slot configuration is normalized and isolated by collector" do
    put "/api/v1/loggers/atom_lite_logger/slots/2",
      params: {
        name: "Motorhome Hardwired Charger",
        device_identifier: "Motorhome Hardwired Charger",
        mac_address: "AA-BB-CC-DD-EE-FF",
        bind_key: "A1" * 16
      },
      headers: authorization(@key),
      as: :json

    assert_response :success
    slot = JSON.parse(response.body).fetch("slot")
    assert_equal "motorhome_hardwired_charger", slot.fetch("device_identifier")
    assert_equal "aa:bb:cc:dd:ee:ff", slot.fetch("mac_address")
    assert_equal "a1" * 16, slot.fetch("bind_key")

    get "/api/v1/loggers/atom_lite_logger/config", headers: authorization(@other_key)
    assert_response :success
    assert JSON.parse(response.body).fetch("slots").none? { |candidate| candidate.fetch("configured") }
  end

  test "invalid positions mac addresses and bind keys are rejected" do
    put "/api/v1/loggers/atom_lite_logger/slots/4",
      params: valid_slot,
      headers: authorization(@key),
      as: :json
    assert_response :not_found

    put "/api/v1/loggers/atom_lite_logger/slots/1",
      params: valid_slot.merge(mac_address: "invalid", bind_key: "short"),
      headers: authorization(@key),
      as: :json
    assert_response :unprocessable_entity
  end

  test "slots can be cleared" do
    put "/api/v1/loggers/atom_lite_logger/slots/1",
      params: valid_slot,
      headers: authorization(@key),
      as: :json
    assert_response :success

    delete "/api/v1/loggers/atom_lite_logger/slots/1", headers: authorization(@key)
    assert_response :success
    assert_equal false, JSON.parse(response.body).dig("slot", "configured")
    assert_equal true, JSON.parse(response.body).dig("slot", "managed")

    get "/api/v1/loggers/atom_lite_logger/config", headers: authorization(@key)
    assert_response :success
    assert_equal true, JSON.parse(response.body).dig("slots", 0, "managed")
  end

  test "discovery reports are upserted and identify configured devices" do
    2.times do |index|
      post "/api/v1/loggers/atom_lite_logger/discoveries",
        params: { mac_address: "AA:BB:CC:DD:EE:FF", product_id: 413, rssi: -70 + index },
        headers: authorization(@key),
        as: :json
      assert_response :created
    end

    assert_equal 1, Collector.find_by_key(@key).victron_discoveries.count

    put "/api/v1/loggers/atom_lite_logger/slots/1",
      params: valid_slot,
      headers: authorization(@key),
      as: :json
    assert_response :success

    get "/api/v1/loggers/atom_lite_logger/discoveries", headers: authorization(@key)
    assert_response :success
    discovery = JSON.parse(response.body).fetch("discoveries").sole
    assert_equal(-69, discovery.fetch("rssi"))
    assert_equal true, discovery.fetch("configured")
  end

  private

  def valid_slot
    {
      name: "Utility Lithium Charger",
      device_identifier: "utility_lithium_charger",
      mac_address: "AA:BB:CC:DD:EE:FF",
      bind_key: "12" * 16
    }
  end

  def authorization(key)
    { "Authorization" => "Bearer #{key}" }
  end
end
