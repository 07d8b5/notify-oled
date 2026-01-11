# Collectors

Collectors are executable scripts/programs that emit **exactly one line** of JSON to stdout.

Contract:

- `name` (string): short stable label
- `value` (string|number|bool|null): current value
- `enabled` (boolean): whether this item should be eligible for display

Example:

```json
{"name":"TEMP","value":"42C","enabled":true}
```

Notes:
- Write diagnostics to stderr. The pipeline captures stderr to per-collector log files.
- Keep `name` and `value` short. The sender clamps each to 6 characters for the OLED.
