require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    @key = "f" * 64
    @other_key = "1" * 64
    upload(@key, "rv_charger", voltage: { value: 13.4, unit: "V" }, current: { value: 2.1, unit: "A" })
    upload(@other_key, "hidden_device", voltage: 48.0)
  end

  test "dashboard requires an existing collector key" do
    get root_path

    assert_response :unauthorized
    assert_select "form.key-form"
    assert_select "input[name=key]"
  end

  test "dashboard and device reports remain collector scoped" do
    get root_path(key: @key)

    assert_response :success
    assert_select "h2", text: "rv_charger"
    assert_select ".device-identifier", text: "rv_charger"
    assert_no_match "hidden_device", response.body

    get device_path(identifier: "rv_charger", key: @key, range: "24h")

    assert_response :success
    assert_select ".chart-card", count: 2
    assert_select "polyline.chart-line", count: 2
    assert_select ".range-control a.active", text: "24 hours"
  end

  test "CSV export uses the same key" do
    get device_path(identifier: "rv_charger", key: @key, range: "24h", format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "recorded_at,current,voltage", response.body
    assert_match "2.1,13.4", response.body
  end

  private

  def upload(key, device, metrics)
    post "/api/v1/readings",
      params: { key: key, device: device, metrics: metrics },
      as: :json
    assert_response :created
  end
end
