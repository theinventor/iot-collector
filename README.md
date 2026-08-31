# IoT Collector

A small, multi-tenant Ruby on Rails telemetry collector for ESP32 and other IoT devices. It stores data in one SQLite database and includes a keyed API, historical charts, range reports, and CSV exports.

The app has no user accounts. Each collector key is a capability: the key used to upload telemetry is also the key used to read only that collector's data. A strong, previously unseen key creates its namespace on its first upload. Read requests never create namespaces.

## Upload API

Keys used to create a collector must be at least 32 characters. Generate one with:

```bash
openssl rand -hex 32
```

Query-string upload for simple embedded clients:

```bash
export IOT_COLLECTOR_KEY=replace-with-a-random-32-character-or-longer-key

curl --get "http://localhost:3000/api/v1/readings" \
  --data-urlencode "key=$IOT_COLLECTOR_KEY" \
  --data-urlencode "device=rv_charger" \
  --data-urlencode "voltage=13.38" \
  --data-urlencode "current=3.0" \
  --data-urlencode "charge_state=bulk"
```

JSON upload using the same key as a bearer token:

```bash
curl -X POST "http://localhost:3000/api/v1/readings" \
  -H "Authorization: Bearer $IOT_COLLECTOR_KEY" \
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

The key can be sent as a `key` query/body parameter, an `Authorization: Bearer` token, or an `X-IoT-Collector-Key` header. The app filters `key` from Rails logs and stored payloads.

## Read API

All read endpoints require the same key by bearer token, `X-IoT-Collector-Key`, or query parameter:

```text
GET /api/v1/status
GET /api/v1/devices
GET /api/v1/devices/:identifier
GET /api/v1/devices/:identifier/readings?range=24h&limit=100
```

Valid ranges are `1h`, `6h`, `24h`, `7d`, and `30d`. The readings API returns at most 500 samples per request.

Open the browser dashboard and enter the same collector key used for uploads:

```text
https://iot.sunflower-vacations.com/
```

The dashboard remembers the key in an encrypted, HTTP-only cookie and renews it on every authenticated visit. Access remains available across browser restarts until **Log out** is clicked or the browser's site data is cleared. Existing `?key=...` links remain supported, but redirect immediately to a URL without the key.

## Remote Victron Management

Loggers behind cellular routers or NAT can use the collector as a pull-based control plane. The logger reports unconfigured Victron Bluetooth advertisements and periodically retrieves its desired slot configuration. No inbound connection to the logger is required.

These endpoints use the same collector capability key:

```text
GET    /api/v1/loggers/:identifier/config
PUT    /api/v1/loggers/:identifier/slots/:position
DELETE /api/v1/loggers/:identifier/slots/:position
GET    /api/v1/loggers/:identifier/discoveries
POST   /api/v1/loggers/:identifier/discoveries
```

Slot positions are `1`, `2`, or `3`. A slot contains a stable device identifier, display name, Bluetooth MAC address, and 32-character Victron advertisement key. An untouched slot does not override the logger's local configuration. Deleting a slot creates an explicit disabled configuration that the logger applies on its next poll.

Bind keys are returned only by the authenticated configuration endpoint. They are not included in telemetry pages, discovery responses, or normal CLI output. Use HTTPS in production and treat the collector capability key as a secret.

## CLI

The Go CLI uses only the standard library:

```bash
go install github.com/theinventor/iot-collector/cmd/iotcollector@latest

export IOT_COLLECTOR_URL=https://iot.sunflower-vacations.com
export IOT_COLLECTOR_KEY=your-collector-key

iotcollector status
iotcollector devices
iotcollector latest rv_charger
iotcollector -range 7d -limit 50 readings rv_charger
iotcollector -json devices

iotcollector discoveries atom_lite_logger
iotcollector config atom_lite_logger
iotcollector configure \
  --name "Motorhome Hardwired Charger" \
  --device motorhome_hardwired_charger \
  --mac aa:bb:cc:dd:ee:ff \
  --bind-key 00112233445566778899aabbccddeeff \
  atom_lite_logger 2
iotcollector clear atom_lite_logger 2
```

Flags for `configure` must appear before the logger identifier and slot number. Normal `config` output reports only whether a bind key is configured; `-json config` returns the complete authenticated firmware document, including bind keys.

For a local checkout, run `go run ./cmd/iotcollector` in place of `iotcollector`.

## Development

```bash
bin/setup
bin/rails db:migrate
bin/rails server -b 0.0.0.0 -p 3000
```

Run the Rails and Go tests:

```bash
bin/rails test
go test ./...
go vet ./...
```

## Production

This app is intended to run on Hatchbox as a normal Rails app from GitHub. SQLite is the production database, so the Hatchbox app must persist the `storage` directory and run only one app server host against that database.

Production environment variables:

```text
RAILS_MASTER_KEY=...
IOT_COLLECTOR_HOST=iot.sunflower-vacations.com
SQLITE_DATABASE=storage/production.sqlite3
```

`IOT_COLLECTOR_INGEST_KEY` is not required for normal operation. When upgrading a database created before multi-tenant collectors, set it to the old ingest key for the first migration so existing devices are assigned to that key.

Deploy flow:

1. Create the Hatchbox app from this public GitHub repository.
2. Set the app domain to `iot.sunflower-vacations.com`.
3. Add the production environment variables.
4. Run `bin/rails db:migrate` during deploy.
5. Enable automatic deploys for pushes or merges to `main`.

The production ingest URL is:

```text
https://iot.sunflower-vacations.com/api/v1/readings?key=YOUR_COLLECTOR_KEY
```

## ESPHome

The ATOM Lite example uses its built-in RGB LED for field diagnostics: red means offline or an upload error, yellow means connected but waiting for Victron data, and green means the collector accepted the latest Victron reading. A field logger should upload Wi-Fi SSID, IP, and RSSI in its heartbeat so connectivity can be diagnosed through the collector.

The production ATOM Lite firmware and flashing instructions live in [`firmware/`](firmware/README.md). It supports cloud-managed Victron slots, discovery reporting, local authenticated diagnostics, Ranch-primary Wi-Fi with RV fallback, and direct telemetry uploads without Home Assistant.

Smaller reference configurations remain in `examples/esphome/`. `atom-lite-cloud-test.yaml` sends a fixed sample reading to a development server, and `atom-lite-victron-cloud.yaml` demonstrates a single statically configured Victron decoder.

Do not commit real Wi-Fi passwords, collector keys, or Victron bind keys.

## License

MIT
