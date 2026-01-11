#!/usr/bin/env bash
set -euo pipefail

# Select enabled items from out/raw.ndjson into out/display.json.
# If none enabled, emit fallback: [{ "name":"ALL OK", "value":" HH:MM" }]

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

need_cmd jq

raw_in="${OUT_DIR}/raw.ndjson"
display_out="${OUT_DIR}/display.json"
select_log="${LOG_DIR}/select.log"

if [[ ! -f "${raw_in}" ]]; then
  echo "[$(log_ts)] [FATAL] Missing input: ${raw_in}" | tee -a "${select_log}" >&2
  exit 1
fi

clock="$(date '+%H:%M')"

{
  echo "[$(log_ts)] [INFO] Selecting enabled items from $(basename "$raw_in") -> $(basename "$display_out")"

  # Keep enabled entries as [{name,value},...]. If none, emit ALL OK + time.
  jq -s --arg t " $clock" '
    [ .[] | select(.enabled == true) | {name, value} ] as $items
    | if ($items|length) == 0
      then [ { "name":"ALL OK", "value": $t } ]
      else $items
      end
  ' "$raw_in" >"$display_out"

  count="$(jq 'length' "$display_out" 2>/dev/null || echo 0)"
  echo "[$(log_ts)] [INFO] Wrote ${count} item(s) to ${display_out}"
} >>"$select_log"

