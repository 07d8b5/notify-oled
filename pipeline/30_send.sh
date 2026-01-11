#!/usr/bin/env bash
set -euo pipefail

# Send a 2-line payload (name\nvalue) over UDP to the ESP32.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

need_cmd jq
need_cmd nc

# Load UDP destination.
ESP32_CONF="${REPO_ROOT}/config/esp32.conf"
if [[ -f "${ESP32_CONF}" ]]; then
  # shellcheck disable=SC1091
  source "$ESP32_CONF"
fi

: "${ESP32_HOST:=192.168.4.1}"
: "${UDP_PORT:=7777}"
: "${TIMEOUT:=2}"
: "${RETRIES:=3}"

send_log="${LOG_DIR}/send.log"

# Prefer display.json; fall back to raw.ndjson.
in_json="${OUT_DIR}/display.json"
if [[ ! -f "${in_json}" ]]; then
  in_json="${OUT_DIR}/raw.ndjson"
fi

if [[ ! -f "${in_json}" ]]; then
  echo "[$(log_ts)] [FATAL] Missing input JSON (out/display.json or out/raw.ndjson)" | tee -a "${send_log}" >&2
  exit 1
fi

# Extract a single object to send.
obj="$(
  jq -c '
    if type == "array" then
      ( (map(select(.enabled == true)) | .[0]) // .[0] // empty )
    else
      .
    end
  ' "${in_json}"
)"

if [[ -z "${obj}" || "${obj}" == "null" ]]; then
  echo "[$(log_ts)] [WARN] No items available to send" >>"${send_log}"
  exit 0
fi

name="$(jq -r '.name // ""' <<<"${obj}")"
value="$(jq -r '(.value // "") | tostring' <<<"${obj}")"

# Clamp/pad to OLED constraints.
line1="$(clamp6 "${name}")"
line2="$(clamp6 "${value}")"

payload="${line1}\n${line2}"

{
  echo "[$(log_ts)] [INFO] Sending to ${ESP32_HOST}:${UDP_PORT} name='${line1}' value='${line2}'"

  ok=false
  for ((i=1; i<=RETRIES; i++)); do
    # netcat variants differ; -w is widely supported.
    if printf '%b' "${payload}" | nc -u -w "${TIMEOUT}" "${ESP32_HOST}" "${UDP_PORT}" >/dev/null 2>&1; then
      ok=true
      echo "[$(log_ts)] [INFO] Send OK (try ${i}/${RETRIES})"
      break
    fi
    echo "[$(log_ts)] [WARN] Send failed (try ${i}/${RETRIES})"
    sleep 0.2
  done

  if [[ "${ok}" == "false" ]]; then
    echo "[$(log_ts)] [ERROR] All send attempts failed"
    exit 1
  fi
} >>"${send_log}"
