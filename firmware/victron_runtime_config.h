#pragma once

#include <array>
#include <cmath>
#include <cctype>
#include <cstdint>
#include <string>

#include "esphome/components/victron_ble/victron_ble.h"
#include "esphome/components/json/json_util.h"
#include "lwip/dns.h"
#include "lwip/ip_addr.h"

namespace victron_runtime {

struct CloudSlot {
  bool managed{false};
  bool configured{false};
  std::string device_identifier;
  std::string name;
  std::string mac_address;
  std::string bind_key;
};

inline bool parse_cloud_config(const std::string &body, std::array<CloudSlot, 3> &slots) {
  slots = {};
  return esphome::json::parse_json(body, [&slots](ArduinoJson::JsonObject root) {
    if (!root["ok"].as<bool>() || !root["slots"].is<ArduinoJson::JsonArray>()) return false;

    ArduinoJson::JsonArray slot_items = root["slots"].as<ArduinoJson::JsonArray>();
    for (ArduinoJson::JsonObject item : slot_items) {
      const int position = item["position"] | 0;
      if (position < 1 || position > static_cast<int>(slots.size())) continue;

      auto &slot = slots[position - 1];
      slot.managed = item["managed"] | false;
      slot.configured = item["configured"] | false;
      if (!slot.managed || !slot.configured) continue;

      slot.device_identifier = item["device_identifier"].as<std::string>();
      slot.name = item["name"].as<std::string>();
      slot.mac_address = item["mac_address"].as<std::string>();
      slot.bind_key = item["bind_key"].as<std::string>();
    }
    return true;
  });
}

inline void use_public_dns() {
  const ip_addr_t dhcp_dns = *dns_getserver(0);
  ip_addr_t primary{};
  ip_addr_t secondary{};
  IP_ADDR4(&primary, 1, 1, 1, 1);
  IP_ADDR4(&secondary, 8, 8, 8, 8);
  dns_setserver(0, &primary);
  dns_setserver(1, ip_addr_isany(&dhcp_dns) ? &secondary : &dhcp_dns);
}

inline uint8_t &upload_failures() {
  static uint8_t failures = 0;
  return failures;
}

inline void record_upload_success() { upload_failures() = 0; }

inline bool record_upload_failure() {
  auto &failures = upload_failures();
  if (failures < UINT8_MAX) failures++;
  if (failures < 3) return false;

  failures = 0;
  return true;
}

inline int hex_value(char value) {
  if (value >= '0' && value <= '9') return value - '0';
  value = static_cast<char>(std::tolower(static_cast<unsigned char>(value)));
  if (value >= 'a' && value <= 'f') return value - 'a' + 10;
  return -1;
}

inline std::string compact_hex(const std::string &value) {
  std::string result;
  result.reserve(value.size());
  for (char character : value) {
    if (character == ':' || character == '-' || std::isspace(static_cast<unsigned char>(character))) continue;
    result.push_back(character);
  }
  return result;
}

inline bool parse_mac(const std::string &value, uint64_t &address) {
  const std::string compact = compact_hex(value);
  if (compact.size() != 12) return false;

  address = 0;
  for (char character : compact) {
    const int nibble = hex_value(character);
    if (nibble < 0) return false;
    address = (address << 4) | static_cast<uint64_t>(nibble);
  }
  return address != 0;
}

inline bool parse_key(const std::string &value, std::array<uint8_t, 16> &key) {
  const std::string compact = compact_hex(value);
  if (compact.size() != 32) return false;

  for (size_t index = 0; index < key.size(); index++) {
    const int high = hex_value(compact[index * 2]);
    const int low = hex_value(compact[(index * 2) + 1]);
    if (high < 0 || low < 0) return false;
    key[index] = static_cast<uint8_t>((high << 4) | low);
  }
  return true;
}

inline const char *configure(esphome::victron_ble::VictronBle *decoder, const std::string &mac,
                             const std::string &bindkey) {
  if (mac.empty() && bindkey.empty()) {
    decoder->set_address(0);
    return "Disabled";
  }
  if (mac.empty()) {
    decoder->set_address(0);
    return "MAC required";
  }
  if (bindkey.empty()) {
    decoder->set_address(0);
    return "Key required";
  }

  uint64_t address = 0;
  std::array<uint8_t, 16> key{};
  if (!parse_mac(mac, address)) {
    decoder->set_address(0);
    return "Invalid MAC";
  }
  if (!parse_key(bindkey, key)) {
    decoder->set_address(0);
    return "Invalid key";
  }

  decoder->set_bindkey(key);
  decoder->set_address(address);
  return "Ready";
}

inline bool configured_address(uint64_t address, const std::string &mac) {
  uint64_t configured = 0;
  return parse_mac(mac, configured) && configured == address;
}

inline float decode(vic_22bit_0_001 value) {
  return value == 0x3FFFFF ? NAN : 0.001f * static_cast<int32_t>(value);
}

inline float decode(vic_20bit_0_1_negative value) {
  return value == 0xFFFFF ? NAN : -0.1f * static_cast<uint32_t>(value);
}

inline float decode(vic_16bit_0_01 value) {
  return value == 0x7FFF ? NAN : 0.01f * static_cast<int16_t>(value);
}

inline float decode(vic_16bit_0_1 value) {
  return value == 0x7FFF ? NAN : 0.1f * static_cast<int16_t>(value);
}

inline float decode(vic_16bit_0_01_positive value) {
  return value == 0xFFFF ? NAN : 0.01f * static_cast<uint16_t>(value);
}

inline float decode(vic_16bit_0_1_positive value) {
  return value == 0xFFFF ? NAN : 0.1f * static_cast<uint16_t>(value);
}

inline float decode(vic_16bit_1_positive value) {
  return value == 0xFFFF ? NAN : static_cast<uint16_t>(value);
}

inline float decode(vic_13bit_0_01_positive value) {
  return value == 0x1FFF ? NAN : 0.01f * static_cast<uint16_t>(value);
}

inline float decode(vic_11bit_0_1_positive value) {
  return value == 0x7FF ? NAN : 0.1f * static_cast<uint16_t>(value);
}

inline float decode(vic_10bit_0_1_positive value) {
  return value == 0x3FF ? NAN : 0.1f * static_cast<uint16_t>(value);
}

inline float decode(vic_9bit_0_1_negative value) {
  return value == 0x1FF ? NAN : -0.1f * static_cast<uint16_t>(value);
}

inline float decode(vic_9bit_0_1_positive value) {
  return value == 0x1FF ? NAN : 0.1f * static_cast<uint16_t>(value);
}

inline const char *device_state_name(esphome::victron_ble::VE_REG_DEVICE_STATE state) {
  using State = esphome::victron_ble::VE_REG_DEVICE_STATE;
  switch (state) {
    case State::OFF: return "Off";
    case State::LOW_POWER: return "Low power";
    case State::FAULT: return "Fault";
    case State::BULK: return "Bulk";
    case State::ABSORPTION: return "Absorption";
    case State::FLOAT: return "Float";
    case State::STORAGE: return "Storage";
    case State::EQUALIZE_MANUAL: return "Equalize";
    case State::PASSTHRU: return "Pass Thru";
    case State::INVERTING: return "Inverting";
    case State::ASSISTING: return "Assisting";
    case State::POWER_SUPPLY: return "Power supply";
    case State::SUSTAIN: return "Sustain";
    case State::STARTING_UP: return "Starting-up";
    case State::REPEATED_ABSORPTION: return "Repeated absorption";
    case State::AUTO_EQUALIZE: return "Auto equalize";
    case State::BATTERY_SAFE: return "BatterySafe";
    case State::LOAD_DETECT: return "Load detect";
    case State::BLOCKED: return "Blocked";
    case State::TEST: return "Test";
    case State::EXTERNAL_CONTROL: return "External Control";
    default: return "Not available";
  }
}

inline const char *record_type_name(esphome::victron_ble::VICTRON_BLE_RECORD_TYPE type) {
  using Type = esphome::victron_ble::VICTRON_BLE_RECORD_TYPE;
  switch (type) {
    case Type::SOLAR_CHARGER: return "solar_charger";
    case Type::BATTERY_MONITOR: return "battery_monitor";
    case Type::INVERTER: return "inverter";
    case Type::AC_CHARGER: return "ac_charger";
    default: return "other";
  }
}

struct SlotState {
  uint32_t last_frame_ms{0};
  uint32_t sequence{0};
  uint32_t uploaded_sequence{0};
  esphome::victron_ble::VICTRON_BLE_RECORD_TYPE record_type{};
  float battery_voltage{NAN};
  float battery_current{NAN};
  float battery_power{NAN};
  float ac_current{NAN};
  float consumed_ah{NAN};
  float state_of_charge{NAN};
  float time_to_go{NAN};
  float pv_power{NAN};
  float yield_today{NAN};
  float output_2_voltage{NAN};
  float output_2_current{NAN};
  float output_3_voltage{NAN};
  float output_3_current{NAN};
  int device_state{-1};
  int charger_error{-1};
  int alarm_reason{-1};

  void reset() {
    last_frame_ms = 0;
    sequence = 0;
    uploaded_sequence = 0;
    clear_metrics();
  }

  void update(const esphome::victron_ble::VictronBleData *message, uint32_t now) {
    clear_metrics();
    record_type = message->record_type;
    last_frame_ms = now;
    sequence++;

    using Type = esphome::victron_ble::VICTRON_BLE_RECORD_TYPE;
    switch (record_type) {
      case Type::AC_CHARGER: {
        const auto &data = message->data.ac_charger;
        battery_voltage = decode(data.battery_voltage_1);
        battery_current = decode(data.battery_current_1);
        battery_power = power(battery_voltage, battery_current);
        output_2_voltage = decode(data.battery_voltage_2);
        output_2_current = decode(data.battery_current_2);
        output_3_voltage = decode(data.battery_voltage_3);
        output_3_current = decode(data.battery_current_3);
        ac_current = decode(data.ac_current);
        device_state = static_cast<uint8_t>(data.device_state);
        charger_error = static_cast<uint8_t>(data.charger_error);
        break;
      }
      case Type::BATTERY_MONITOR: {
        const auto &data = message->data.battery_monitor;
        battery_voltage = decode(data.battery_voltage);
        battery_current = decode(data.battery_current);
        battery_power = power(battery_voltage, battery_current);
        consumed_ah = decode(data.consumed_ah);
        state_of_charge = decode(data.state_of_charge);
        time_to_go = decode(data.time_to_go);
        alarm_reason = static_cast<uint16_t>(data.alarm_reason);
        break;
      }
      case Type::SOLAR_CHARGER: {
        const auto &data = message->data.solar_charger;
        battery_voltage = decode(data.battery_voltage);
        battery_current = decode(data.battery_current);
        battery_power = power(battery_voltage, battery_current);
        pv_power = decode(data.pv_power);
        yield_today = decode(data.yield_today);
        device_state = static_cast<uint8_t>(data.device_state);
        charger_error = static_cast<uint8_t>(data.charger_error);
        break;
      }
      case Type::INVERTER: {
        const auto &data = message->data.inverter;
        battery_voltage = decode(data.battery_voltage);
        ac_current = decode(data.ac_current);
        device_state = static_cast<uint8_t>(data.device_state);
        alarm_reason = static_cast<uint16_t>(data.alarm_reason);
        break;
      }
      default:
        break;
    }
  }

  bool needs_upload(uint32_t now) const {
    return sequence != uploaded_sequence && last_frame_ms != 0 &&
           static_cast<uint32_t>(now - last_frame_ms) < 90000;
  }

  bool is_recent(uint32_t now) const {
    return last_frame_ms != 0 && static_cast<uint32_t>(now - last_frame_ms) < 90000;
  }

  void mark_uploaded() { uploaded_sequence = sequence; }

  void write_metrics(ArduinoJson::JsonObject metrics, uint32_t now) const {
    metrics["victron_record_type"] = record_type_name(record_type);
    metrics["victron_frame_age_seconds"] = static_cast<uint32_t>(now - last_frame_ms) / 1000;
    add_metric(metrics, "battery_voltage", battery_voltage, "V");
    add_metric(metrics, "battery_current", battery_current, "A");
    add_metric(metrics, "battery_power", battery_power, "W");
    add_metric(metrics, "ac_current", ac_current, "A");
    add_metric(metrics, "consumed_ah", consumed_ah, "Ah");
    add_metric(metrics, "state_of_charge", state_of_charge, "%");
    add_metric(metrics, "time_to_go", time_to_go, "min");
    add_metric(metrics, "pv_power", pv_power, "W");
    add_metric(metrics, "yield_today", yield_today, "kWh");
    add_metric(metrics, "output_2_voltage", output_2_voltage, "V");
    add_metric(metrics, "output_2_current", output_2_current, "A");
    add_metric(metrics, "output_3_voltage", output_3_voltage, "V");
    add_metric(metrics, "output_3_current", output_3_current, "A");
    if (device_state >= 0) {
      metrics["device_state"] = device_state_name(
        static_cast<esphome::victron_ble::VE_REG_DEVICE_STATE>(device_state));
    }
    if (charger_error >= 0) metrics["charger_error_code"] = charger_error;
    if (alarm_reason >= 0) metrics["alarm_reason_code"] = alarm_reason;
  }

 private:
  static float power(float voltage, float current) {
    return std::isnan(voltage) || std::isnan(current) ? NAN : voltage * current;
  }

  static void add_metric(ArduinoJson::JsonObject metrics, const char *name, float value, const char *unit) {
    if (std::isnan(value)) return;
    auto metric = metrics[name].to<ArduinoJson::JsonObject>();
    metric["value"] = value;
    metric["unit"] = unit;
  }

  void clear_metrics() {
    battery_voltage = battery_current = battery_power = ac_current = NAN;
    consumed_ah = state_of_charge = time_to_go = pv_power = yield_today = NAN;
    output_2_voltage = output_2_current = output_3_voltage = output_3_current = NAN;
    device_state = charger_error = alarm_reason = -1;
  }
};

inline SlotState &slot(size_t index) {
  static std::array<SlotState, 3> states{};
  return states.at(index);
}

}  // namespace victron_runtime
