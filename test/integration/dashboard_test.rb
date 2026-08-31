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
    assert_select "form.key-form[action=?]", access_path
    assert_select "input[name=key]"
  end

  test "valid access persists in an encrypted permanent cookie" do
    post access_path, params: { key: @key }

    assert_response :see_other
    assert_redirected_to root_path
    cookie = response.headers.fetch("Set-Cookie")
    assert_includes cookie, "iot_collector_key="
    assert_match(/expires=/i, cookie)
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)
    assert_not_includes cookie, @key

    follow_redirect!
    assert_response :success
    assert_select ".logout-button", text: "Log out"

    get root_path
    assert_response :success
    assert_includes response.headers.fetch("Set-Cookie"), "iot_collector_key="
    assert_select "h2", text: "rv_charger"
  end

  test "dashboard and device reports remain collector scoped without tokenized links" do
    login(@key)

    assert_response :success
    assert_select "h2", text: "rv_charger"
    assert_select ".device-identifier", text: "rv_charger"
    assert_select "a[href*='key=']", count: 0
    assert_no_match "hidden_device", response.body

    get device_path(identifier: "rv_charger", range: "24h")

    assert_response :success
    assert_select ".chart-card", count: 2
    assert_select "polyline.chart-line", count: 2
    assert_select ".range-control a.active", text: "24 hours"
    assert_select "a[href*='key=']", count: 0

    get device_path(identifier: "hidden_device")
    assert_response :not_found
  end

  test "CSV export uses remembered access" do
    login(@key)
    get device_path(identifier: "rv_charger", range: "24h", format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "recorded_at,current,voltage", response.body
    assert_match "2.1,13.4", response.body
  end

  test "invalid keys are rejected and not remembered" do
    post access_path, params: { key: "not-a-valid-key" }

    assert_response :unauthorized
    assert_select ".form-error", text: "That collector key was not recognized."

    get root_path
    assert_response :unauthorized
  end

  test "legacy query tokens are remembered and removed from the URL" do
    get device_path(identifier: "rv_charger", key: @key, range: "7d")

    assert_response :see_other
    assert_redirected_to device_path(identifier: "rv_charger", range: "7d")

    follow_redirect!
    assert_response :success
    assert_select ".range-control a.active", text: "7 days"
  end

  test "logout forgets access" do
    login(@key)

    delete access_path
    assert_response :see_other
    assert_redirected_to root_path

    follow_redirect!
    assert_response :unauthorized
    assert_select "form.key-form"
  end

  private

  def upload(key, device, metrics)
    post "/api/v1/readings",
      params: { key: key, device: device, metrics: metrics },
      as: :json
    assert_response :created
  end

  def login(key)
    post access_path, params: { key: key }
    assert_response :see_other
    follow_redirect!
  end
end
