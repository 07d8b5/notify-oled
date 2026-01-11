#!/usr/bin/env bash
set -euo pipefail

# Filter NDJSON (out/raw.ndjson) to enabled items (out/display.json).

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

{
  echo "[$(log_ts)] [INFO] Selecting enabled items"
  jq -s '[.[] | select(.enabled == true)]' "${raw_in}" >"${display_out}"
  count="$(jq 'length' "${display_out}")"
  echo "[$(log_ts)] [INFO] Wrote ${count} item(s) to ${display_out}"
} >>"${select_log}"
