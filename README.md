# IoT Collector

Small vanilla Ruby on Rails collector for ESP32 and other IoT devices. It accepts keyed telemetry uploads, stores everything in one SQLite database, and exposes a simple dashboard.

## API

Send readings to:

```text
GET or POST /api/v1/readings?key=YOUR_INGEST_KEY
```

Query-string upload:

```bash
curl "http://localhost:3000/api/v1/readings?key=dev-secret&device=rv_charger&voltage=13.38&current=3.0&rssi=-99&charge_state=bulk"
```

JSON upload:

```bash
curl -X POST "http://localhost:3000/api/v1/readings?key=dev-secret" \
  -H "Content-Type: application/json" \
  -d '{
    "device": "rv_charger",
    "name": "RV Charger",
    "metrics": {
      "voltage": { "value": 13.38, "unit": "V" },
      "current": { "value": 3.0, "unit": "A" },
      "charge_state": "bulk"
    }
  }'
```

The shared key can be provided as a query parameter or inside the JSON body. The app filters `key` from logs.

## Development

```bash
bin/setup
bin/rails db:migrate
bin/rails server -b 0.0.0.0 -p 3000
```

Development and test default to `dev-secret` if no key is configured.

Run tests:

```bash
bin/rails test
```

## Production

This app is intended to run on Hatchbox as a normal Rails app from GitHub. It uses SQLite in production, so the Hatchbox app needs persistent storage for the `storage` directory.

Production environment variables:

```text
RAILS_MASTER_KEY=...
IOT_COLLECTOR_INGEST_KEY=long-random-device-key
IOT_COLLECTOR_HOST=iotcollector.sunflower-vacations.com
SQLITE_DATABASE=storage/production.sqlite3
```

Deploy flow:

1. Create the Hatchbox app from the public GitHub repository.
2. Set the app domain to `iotcollector.sunflower-vacations.com`.
3. Add the environment variables above.
4. Run database migrations during deploy.
5. Enable automatic deploys for pushes or merges to `main`.

The production ingest URL will be:

```text
https://iotcollector.sunflower-vacations.com/api/v1/readings?key=YOUR_INGEST_KEY
```

## ESPHome

The ATOM Lite example uses its built-in RGB LED for field diagnostics: red means offline or an upload error, yellow means connected but waiting for Victron data, and green means the collector accepted the latest Victron reading.

Example firmware configs live in `examples/esphome/`.

`atom-lite-cloud-test.yaml` sends a fixed sample reading to a development server so you can verify network path and API auth.

`atom-lite-victron-cloud.yaml` shows the intended Victron version: the ESP32 decodes Victron BLE locally with the Victron Instant Readout key, then uploads voltage/current/state readings to this collector.

If the ESP is on an isolated RV or cellular Wi-Fi network, it may not be able to reach a Rails server running on your Mac by LAN IP. For a development test, expose Rails through a plain HTTP tunnel and set `collector_base_url` to that tunnel URL. For production, set it to:

```text
https://iotcollector.sunflower-vacations.com
```

Do not commit real Wi-Fi passwords, collector keys, or Victron bind keys.

## License

MIT
