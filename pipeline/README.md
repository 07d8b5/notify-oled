# Pipeline scripts

These scripts are designed to be run on a Linux host.

## Recommended entrypoint

- `run_pipeline.sh`: runs all stages in order and appends per-stage status to `logs/pipeline.log`.

This is preferred over chaining scripts with long `&&` one-liners in crontab: failures are attributed to a specific stage and the schedule line stays readable.

## Stages

- `00_run_all.sh`: execute collectors and write `out/raw.ndjson`
- `10_wifi_watchdog.sh`: required Wi‑Fi link watchdog (ESP32 SoftAP is unreliable)
- `20_select.sh`: filter enabled items into `out/display.json`
- `30_send.sh`: send a 2-line UDP payload to the ESP32
- `40_housekeeping.sh`: rotate/compress logs and prune stale temp files (rate-limited)

## Dependencies

- `bash`
- `jq`
- `nc` (netcat)
- `find`, `stat` (coreutils)
- `gzip` (optional; used by housekeeping if enabled)
- `ping` (for wifi_watchdog)
- optionally `wpa_cli`, `iwgetid`, `timeout`

## Crontab example

Run every minute:

```cron
* * * * * /absolute/path/to/repo/pipeline/run_pipeline.sh >/dev/null 2>&1
```

For debugging, also capture cron output:

```cron
* * * * * /absolute/path/to/repo/pipeline/run_pipeline.sh >>/absolute/path/to/repo/logs/cron.log 2>&1
```

Notes:
- Use absolute paths in cron (cron runs with a minimal environment).
- Ensure scripts are executable: `chmod +x /absolute/path/to/repo/pipeline/*.sh`.

