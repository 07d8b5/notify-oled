# Home Telemetry → ESP32-C3 OLED ("notify-oled")

Collect small status signals from a Linux host, select what matters, then send two short
lines over UDP to an ESP32-C3 that displays them on an SSD1306 OLED.

This repo is intentionally boring:
- collectors print one line of JSON
- pipeline turns that into a 2-line display payload
- sender ships `name\nvalue` to the ESP32


## What it does now

### On the Linux host (collection + selection + send)

Recommended entrypoint:

0) `pipeline/run_pipeline.sh` (recommended)
   - runs the full pipeline in order:
     - `00_run_all.sh` → `10_wifi_watchdog.sh` → `20_select.sh` → `30_send.sh` → `40_housekeeping.sh`
   - appends a per-stage run log to: `logs/pipeline.log`
   - exits non-zero if any stage fails (so cron/systemd can detect failure)

Individual stages (typically run directly only for debugging):

1) `pipeline/00_run_all.sh`
   - runs every executable in `collectors/`
   - each collector must print **EXACTLY ONE** JSON object on **ONE** line
   - validates the JSON contract (`name`/`value`/`enabled`)
   - writes NDJSON to: `out/raw.ndjson`
   - logs:
     - `logs/run_all.log`
     - `logs/collectors/<collector>.log` (stderr per collector)

2) `pipeline/10_wifi_watchdog.sh` (required; link reliability)
   - required because the ESP32 SoftAP link is not reliably stable in practice
   - prevents the send stage from failing due to a wedged or half-associated Wi-Fi client state
   - logs: `logs/wifi_watchdog.log`

3) `pipeline/20_select.sh`
   - reads NDJSON from: `out/raw.ndjson`
   - keeps **ONLY** items where `enabled == true`
   - writes a JSON array to: `out/display.json`
   - logs: `logs/select.log`

4) `pipeline/30_send.sh`
   - reads: `out/display.json` (array OR single object)
   - chooses:
     - the first `enabled==true` item if present
     - otherwise the first item
   - sends via UDP to the ESP32:
     - line 1: `name`  (clamped to 6 chars)
     - line 2: `value` (clamped to 6 chars)
   - logs: `logs/send.log`

5) `pipeline/40_housekeeping.sh` (log + temp management)
   - rotates and optionally compresses log files when they exceed a configured size
   - prunes old rotated logs (optional)
   - removes stale temp files in `out/` (e.g., `*.tmp`)
   - rate-limited by default (runs at most once per 24 hours even if scheduled every minute)
   - logs: `logs/housekeeping.log`


### On the ESP32-C3 (receiver / display)

The ESP32 firmware is intentionally simple: it displays exactly what the sender provides.

At boot it:
- locks CPU to **80 MHz**
- performs a **2.4 GHz scan** (STA scan only; it does not join networks)
- picks a SoftAP channel (US-safe range **1–11**, preferring **1/6/11**)
- starts a (optionally hidden) SoftAP
- binds a UDP listener (default **7777**)
- draws two 6-character lines on an SSD1306 OLED

At runtime it:
- listens for UDP payloads like:
  - `ABC123\nDEF456`
  - `ABC123|DEF456`
  - `ABC123,DEF456`
  - or just `ABC123` (second line becomes blank)
- clamps each line to **6 characters** (hard truncate; pads with spaces)
- logs to Serial for diagnosis
- if OLED initialization fails, it continues running headless (serial-only)
- does not auto-restart; it reports failures


## Repo layout

```text
repo/
├── README.md
├── collectors/                   # executable scripts; each prints 1 JSON line
│   ├── <anything>.sh
│   └── ...
├── collectors_disabled/          # parking lot for collectors you don't want run
├── pipeline/
│   ├── 00_run_all.sh             # run collectors -> out/raw.ndjson (NDJSON)
│   ├── 10_wifi_watchdog.sh       # keep host connected to ESP32 SoftAP (required)
│   ├── 20_select.sh              # filter/shape -> out/display.json (JSON array)
│   ├── 30_send.sh                # UDP send name/value to ESP32
│   ├── 40_housekeeping.sh        # rotate/prune logs; clean temp files
│   ├── run_pipeline.sh           # recommended entrypoint: runs all stages + per-stage logging
│   └── _lib.sh                   # shared helpers for pipeline scripts (not executable)
├── config/
│   ├── repo.conf.example         # defines REPO_ROOT (template)
│   ├── esp32.conf.example        # ESP32_HOST, UDP_PORT, TIMEOUT, RETRIES (template)
│   ├── wifi_watchdog.conf.example # Wi-Fi watchdog settings (template)
│   └── housekeeping.conf.example # housekeeping settings (template)
├── esp32/                        # ESP32 firmware project (Arduino / PlatformIO)
├── out/                          # generated (gitignored)
│   ├── raw.ndjson                # NDJSON: one object per collector
│   └── display.json              # JSON array: selected items for display
└── logs/                         # runtime logs (gitignored)
    ├── pipeline.log
    ├── run_all.log
    ├── select.log
    ├── send.log
    ├── wifi_watchdog.log
    ├── housekeeping.log
    └── collectors/
        └── <collector>.log
```


## JSON contract (collectors)

Each collector prints EXACTLY ONE LINE of JSON to stdout.

Required keys:
- `name`    (string)                     stable identifier
- `value`   (string|number|bool|null)    value to show/use
- `enabled` (boolean)                    whether it should be considered

Example:

```json
{"name":"ZFS","value":"ONLINE","enabled":true}
```


## Config

Templates are provided in `config/*.conf.example`. Copy them to the corresponding `*.conf` files to override defaults.

### Linux host side

`config/repo.conf`
- `REPO_ROOT="/path/to/repo"`   # set to your clone location

`config/esp32.conf` (UDP mode)
- `ESP32_HOST="192.168.4.1"`
- `UDP_PORT=7777`
- `TIMEOUT=2`
- `RETRIES=3`

`config/wifi_watchdog.conf` (required; Wi‑Fi link watchdog)
- see `config/wifi_watchdog.conf.example` for defaults
- `IFACE="wlan0"`
- `GW="192.168.4.1"`
- `PING_COUNT=1`
- `PING_TIMEOUT=1`
- `RECONNECT_TRIES=2`
- `EXPECTED_SSID` (optional)

`config/housekeeping.conf` (optional; log rotation and pruning)
- see `config/housekeeping.conf.example` for defaults
- `RUN_INTERVAL_HOURS=24`
- `MAX_LOG_BYTES=2097152`
- `ROTATE_KEEP=30`
- `COMPRESS=true`
- `PRUNE_DAYS=180`
- `OUT_TMP_PRUNE_DAYS=2`

### ESP32 side

Edit `esp32/esp32_oled_udp/config.h`:
- SoftAP identity:
  - `AP_SSID` (default: `"notify-oled"`)
  - `AP_PASS` (default: `"change-me"`)
  - `AP_HIDDEN` (1 = hidden, 0 = broadcast)
  - `AP_MAXCONN`


## Scheduling (crontab)

Run the single entrypoint script. This keeps the schedule line readable and produces a single per-stage log (`logs/pipeline.log`).

Edit your crontab:

```bash
crontab -e
```

Run every minute (quiet):

```cron
* * * * * /absolute/path/to/repo/pipeline/run_pipeline.sh >/dev/null 2>&1
```

If you want cron to keep a separate log (in addition to `logs/pipeline.log`):

```cron
* * * * * /absolute/path/to/repo/pipeline/run_pipeline.sh >>/absolute/path/to/repo/logs/cron.log 2>&1
```

Notes:
- Use absolute paths in cron (cron runs with a minimal environment).
- Ensure scripts are executable: `chmod +x pipeline/*.sh`.

