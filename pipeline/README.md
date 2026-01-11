# Pipeline scripts

These scripts are designed to be run on a Linux host.

- `00_run_all.sh`: execute collectors and write `out/raw.ndjson`
- `10_wifi_watchdog.sh`: optional Wi‑Fi link watchdog
- `20_select.sh`: filter enabled items into `out/display.json`
- `30_send.sh`: send a 2-line UDP payload to the ESP32

Dependencies:
- `bash`
- `jq`
- `nc` (netcat)
- `ping` (for wifi_watchdog)
- optionally `wpa_cli`, `iwgetid`, `timeout`
