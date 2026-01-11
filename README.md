# Home Telemetry -> ESP32-C3 OLED ("notify-oled")

Collect small status signals from a machine, select what matters, and send a
two-line UDP payload to an ESP32-C3 which displays it on a small SSD1306 OLED.

Design goals:
- collectors are single-purpose executables that print **one JSON object**
- the pipeline produces a single, clamped two-line display payload
- the ESP32 firmware is intentionally simple (display what it is sent)

## What it does now

### On the Pi (collector host)

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

   Behavior:
   - checks reachability of the ESP32 SoftAP gateway/target (typically `192.168.4.1`)
   - if unreachable, attempts recovery using user-space Wi-Fi control (no reboot):
     - disconnect + reassociate using `wpa_cli`
     - re-request an address if necessary (DHCP renew may be host-dependent)
   - does not modify telemetry outputs (`out/raw.ndjson`, `out/display.json`) and does not restart unrelated services
   - writes diagnostics to `logs/wifi_watchdog.log`

   Exit status:
   - `0` if the link is healthy **or** recovery succeeded
   - non-zero if recovery failed (the send stage is expected to fail in this case)

3) `pipeline/20_select.sh`
   - reads NDJSON from: `out/raw.ndjson`
   - keeps **ONLY** items where `enabled == true`
   - writes JSON array to: `out/display.json`
   - logs: `logs/select.log`

4) `pipeline/30_send.sh`
   - reads: `out/display.json` (array OR single object)
   - chooses:
     - first enabled item if present
     - else first item
   - sends via UDP to the ESP32:
     - line 1: `name`  (clamped to 6 chars)
     - line 2: `value` (clamped to 6 chars)
   - logs: `logs/send.log`


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

repo/
├── README.md
├── collectors/                   # executable scripts; each prints 1 JSON line
│   ├── <anything>.sh
│   └── ...
├── collectors_disabled/          # parking lot for collectors you don't want run
├── pipeline/
│   ├── 00_run_all.sh             # run collectors -> out/raw.ndjson (NDJSON)
│   ├── 10_wifi_watchdog.sh       # keep Pi connected to ESP32 SoftAP (required)
│   ├── 20_select.sh              # filter/shape -> out/display.json (JSON array)
│   ├── 30_send.sh                # UDP send name/value to ESP32
│   └── _lib.sh                   # shared helpers for pipeline scripts (not executable)
├── config/
│   ├── repo.conf.example          # template for REPO_ROOT override
│   ├── esp32.conf.example         # template for ESP32_HOST, UDP_PORT, TIMEOUT, RETRIES
│   └── wifi_watchdog.conf.example # template for watchdog settings
├── esp32/                        # ESP32 firmware project (Arduino / PlatformIO)
├── out/                          # generated (gitignored)
│   ├── raw.ndjson                # NDJSON: one object per collector
│   └── display.json              # JSON array: selected items for display
└── logs/                         # runtime logs (gitignored)
    ├── run_all.log
    ├── select.log
    ├── send.log
    ├── wifi_watchdog.log
    └── collectors/
        └── <collector>.log


## Config

### Pi side

The `config/*.example` files are templates. Copy them to the non-`.example`
names to enable local overrides. These local config files are ignored by git.

`config/repo.conf` (optional)
- `REPO_ROOT="/path/to/repo"`   # override autodetected repo root

`config/esp32.conf` (UDP mode)
- `ESP32_HOST="192.168.4.1"`
- `UDP_PORT=7777`
- `TIMEOUT=2`
- `RETRIES=3`

`config/wifi_watchdog.conf`
- `IFACE="wlan0"`
- `GW="192.168.4.1"`
- `EXPECTED_SSID=""` (optional)

### ESP32 side

Edit `esp32/esp32_oled_udp/config.h`:

- SoftAP identity:
  - `AP_SSID` (default: `"notify-oled"`)
  - `AP_PASS` (default: `"change-me"`)
  - `AP_HIDDEN` (1 = hidden, 0 = broadcast)
  - `AP_MAXCONN`

- Local override header (recommended for real Wi‑Fi credentials):
  - create `esp32/esp32_oled_udp/config_local.h` (ignored by git)
  - define `NOTIFY_AP_SSID` and `NOTIFY_AP_PASS` there
  - optional: `NOTIFY_SCAN_LOG_SSIDS=1` to print nearby SSIDs during the boot scan

