# ATOM Lite Victron Logger

`atom-lite-victron-runtime.yaml` is the production ESPHome firmware for an M5Stack ATOM Lite. It decodes Victron Instant Readout advertisements locally and uploads telemetry directly to IoT Collector without Home Assistant.

## Configure

Install ESPHome 2026.8.1 or newer, then create the untracked secrets file:

```bash
cd firmware
cp secrets.example.yaml secrets.yaml
```

Fill in the collector capability key, both Wi-Fi networks, and the initial Victron values. Never commit `secrets.yaml`.

The primary Wi-Fi is listed first with priority 20; the fallback has priority 10. Change the entries in `atom-lite-victron-runtime.yaml` if a deployment needs a different order.

## Flash

Connect the ATOM Lite with a data-capable USB cable and identify its serial port:

```bash
ls /dev/cu.*
esphome run atom-lite-victron-runtime.yaml --device /dev/cu.YOUR_USB_SERIAL_PORT
```

After the first flash, OTA is also available while the computer can reach the logger:

```bash
esphome run atom-lite-victron-runtime.yaml --device victron-ble-proxy-XXXXXX.local
```

## Operation

The logger supports three runtime-configurable Victron slots. It fetches desired slot configuration from the Rails API, reports unconfigured Victron advertisements, and sends decoded readings plus Wi-Fi and slot diagnostics to the collector. Unchanged cloud polls do not reset active decoders.

The authenticated local web interface uses username `admin` and the collector capability key as its password. It exposes device configuration, status, restart, OTA, and live logs.

The built-in LED is:

- Red when Wi-Fi or cloud upload is failing.
- Yellow while connected and waiting for Victron data.
- Green after the collector accepts a decoded Victron reading.

Victron Instant Readout must be enabled. A Victron device may stop advertising while VictronConnect is actively connected to it.
