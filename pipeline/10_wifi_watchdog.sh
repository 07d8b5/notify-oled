#!/usr/bin/env bash
set -euo pipefail

# Best-effort Wi-Fi watchdog for hosts connected to the ESP32 SoftAP.
#
# This script is intentionally conservative: it does not restart services;
# it uses common user-space tools (when permitted by local policy)
# to request a re-association. Note: wpa_cli often requires root or
# membership in a privileged group (e.g., netdev) depending on distro.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

watch_log="${LOG_DIR}/wifi_watchdog.log"

# Defaults
IFACE="wlan0"
GW="192.168.4.1"
PING_COUNT=1
PING_TIMEOUT=1
RECONNECT_TRIES=2
EXPECTED_SSID=""

CFG="${REPO_ROOT}/config/wifi_watchdog.conf"
if [[ -f "${CFG}" ]]; then
  # shellcheck disable=SC1091
  source "${CFG}"
fi

need_cmd ping

{
  echo "[$(log_ts)] [INFO] Wi-Fi watchdog iface=${IFACE} gw=${GW}"

  if [[ -n "${EXPECTED_SSID}" ]] && command -v iwgetid >/dev/null 2>&1; then
    cur_ssid="$(iwgetid -r 2>/dev/null || true)"
    if [[ "${cur_ssid}" != "${EXPECTED_SSID}" ]]; then
      echo "[$(log_ts)] [INFO] Not on expected SSID; skipping (cur='${cur_ssid}')"
      exit 0
    fi
  fi

  if ping -I "${IFACE}" -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${GW}" >/dev/null 2>&1; then
    echo "[$(log_ts)] [INFO] Link OK"
    exit 0
  fi

  echo "[$(log_ts)] [WARN] Ping failed; attempting reconnect"

  if ! command -v wpa_cli >/dev/null 2>&1; then
    echo "[$(log_ts)] [ERROR] wpa_cli not available; cannot request reconnect"
    exit 1
  fi

  for ((i=1; i<=RECONNECT_TRIES; i++)); do
    wpa_cli -i "${IFACE}" disconnect >/dev/null 2>&1 || true
    sleep 0.2
    wpa_cli -i "${IFACE}" reconnect >/dev/null 2>&1 || true
    sleep 0.6

    if ping -I "${IFACE}" -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${GW}" >/dev/null 2>&1; then
      echo "[$(log_ts)] [INFO] Reconnect OK (try ${i}/${RECONNECT_TRIES})"
      exit 0
    fi

    echo "[$(log_ts)] [WARN] Reconnect attempt failed (try ${i}/${RECONNECT_TRIES})"
  done

  echo "[$(log_ts)] [ERROR] Reconnect did not restore connectivity"
  exit 1
} >>"${watch_log}"
