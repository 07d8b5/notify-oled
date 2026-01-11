#!/usr/bin/env bash
set -euo pipefail

# Wi-Fi watchdog for hosts connected to an ESP32 SoftAP.
#
# Designed for NetworkManager-managed systems:
# - Uses nmcli to bounce the Wi-Fi connection and/or radio.
# - Flushes neighbor (ARP) and route caches to clear "connected but dead" wedges.
#
# Health check is strict:
# - If EXPECTED_SSID is set, the interface must be associated to that SSID (best-effort).
# - Interface must have an IPv4 address matching EXPECTED_SUBNET_PREFIX (simple prefix match).
# - IPv4 gateway must match GW.
# - ICMP ping to GW must succeed.
#
# Configuration:
# - Optional config file: ${REPO_ROOT}/config/wifi_watchdog.conf
# - All variables below can be overridden there.
#
# Permissions:
# - nmcli connection/radio control is often gated by polkit.
# - This script detects missing permissions and logs a clear error instead of silently failing.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

watch_log="${LOG_DIR}/wifi_watchdog.log"

# Defaults (override in config/wifi_watchdog.conf)
IFACE="wlan0"
GW="192.168.4.1"
EXPECTED_SSID=""                     # e.g. "esp32-softap-ssid"
EXPECTED_SUBNET_PREFIX="192.168.4."  # e.g. "192.168.4."
PING_COUNT=1
PING_TIMEOUT=1
RECONNECT_TRIES=2
NM_CONN=""                           # recommended: NetworkManager connection profile name

CFG="${REPO_ROOT}/config/wifi_watchdog.conf"
if [[ -f "${CFG}" ]]; then
  # shellcheck disable=SC1091
  source "${CFG}"
fi

need_cmd ping

nm_has() { command -v nmcli >/dev/null 2>&1; }

nm_active_wifi_name() {
  # Active Wi-Fi connection profile name for IFACE (may equal SSID depending on setup).
  nmcli -t -f ACTIVE,DEVICE,TYPE,NAME dev status 2>/dev/null \
    | awk -F: -v d="${IFACE}" '$1=="yes" && $2==d && $3=="wifi"{print $4; exit}'
}

nm_ssid_best_effort() {
  # Best-effort SSID detection:
  # - On many systems, the active NM connection NAME matches the SSID.
  # - If not, fall back to iwgetid if available.
  local n=""
  n="$(nm_active_wifi_name)"
  if [[ -n "$n" ]]; then
    printf '%s' "$n"
    return 0
  fi
  if command -v iwgetid >/dev/null 2>&1; then
    iwgetid -r 2>/dev/null || true
  fi
}

nm_ip4() { nmcli -g IP4.ADDRESS dev show "${IFACE}" 2>/dev/null | head -n1 || true; }
nm_gw4() { nmcli -g IP4.GATEWAY dev show "${IFACE}" 2>/dev/null || true; }
nm_state() { nmcli -g GENERAL.STATE dev show "${IFACE}" 2>/dev/null || true; }

log_state() {
  local ssid ip gw state
  state="$(nm_state)"
  ssid="$(nm_ssid_best_effort)"
  ip="$(nm_ip4)"
  gw="$(nm_gw4)"
  echo "[$(log_ts)] [INFO] State: nm='${state}' ssid='${ssid}' ip='${ip}' gw='${gw}'"
}

health_ok() {
  # Returns 0 if the link appears healthy, else 1.
  local ssid ip gw

  ssid="$(nm_ssid_best_effort)"
  ip="$(nm_ip4)"
  gw="$(nm_gw4)"

  if [[ -n "${EXPECTED_SSID}" && "${ssid}" != "${EXPECTED_SSID}" ]]; then
    return 1
  fi

  if [[ -n "${EXPECTED_SUBNET_PREFIX}" ]]; then
    [[ "${ip}" == ${EXPECTED_SUBNET_PREFIX}*/* ]] || return 1
  else
    [[ -n "${ip}" ]] || return 1
  fi

  [[ "${gw}" == "${GW}" ]] || return 1

  ping -I "${IFACE}" -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${GW}" >/dev/null 2>&1
}

nm_reset_link() {
  # Best-effort cache flush. Some systems may restrict these operations.
  ip neigh flush dev "${IFACE}" >/dev/null 2>&1 || true
  ip route flush cache >/dev/null 2>&1 || true
}

# ---- Permission detection (polkit-gated nmcli operations) ----

nm_perm_value() {
  # Returns the VALUE column (e.g. "yes", "no", "auth") for a permission id, or empty.
  # Only "yes" is suitable for unattended operation.
  local perm_id="$1"
  nmcli -t -f PERMISSION,VALUE general permissions 2>/dev/null \
    | awk -F: -v id="$perm_id" '$1==id{print $2; exit}'
}

nm_require_perm_or_die() {
  # Fail early with a clear error if a required NM permission is not granted.
  local perm_id="$1"
  local v=""
  v="$(nm_perm_value "$perm_id")"

  # If we cannot read permissions, do not fail here; runtime checks will still catch auth errors.
  if [[ -z "$v" ]]; then
    echo "[$(log_ts)] [WARN] Unable to read NetworkManager permissions; proceeding with runtime checks"
    return 0
  fi

  if [[ "$v" != "yes" ]]; then
    echo "[$(log_ts)] [ERROR] Insufficient NetworkManager permission: ${perm_id} (value='${v}')"
    echo "[$(log_ts)] [ERROR] Fix: grant this action via polkit."
    echo "[$(log_ts)] [ERROR] Hint: nmcli general permissions"
    exit 2
  fi
}

nm_bounce_connection() {
  local c="${NM_CONN}"
  local out="" rc=0

  if [[ -z "${c}" ]]; then
    c="$(nm_active_wifi_name)"
  fi
  if [[ -z "${c}" ]]; then
    echo "[$(log_ts)] [WARN] Unable to determine NetworkManager connection name"
    return 1
  fi

  out="$(nmcli -w 5 con down "${c}" 2>&1)"; rc=$?
  if (( rc != 0 )); then
    if grep -qi 'not authorized' <<<"$out"; then
      echo "[$(log_ts)] [ERROR] Not authorized to deactivate connections (polkit)."
      echo "[$(log_ts)] [ERROR] Output: ${out}"
      return 77
    fi
    echo "[$(log_ts)] [WARN] nmcli con down failed (rc=${rc}): ${out}"
  fi

  out="$(nmcli -w 10 con up "${c}" 2>&1)"; rc=$?
  if (( rc != 0 )); then
    if grep -qi 'not authorized' <<<"$out"; then
      echo "[$(log_ts)] [ERROR] Not authorized to activate connections (polkit)."
      echo "[$(log_ts)] [ERROR] Output: ${out}"
      return 77
    fi
    echo "[$(log_ts)] [WARN] nmcli con up failed (rc=${rc}): ${out}"
  fi

  return 0
}

nm_toggle_radio() {
  local out="" rc=0

  out="$(nmcli -w 5 radio wifi off 2>&1)"; rc=$?
  if (( rc != 0 )); then
    if grep -qi 'not authorized' <<<"$out"; then
      echo "[$(log_ts)] [ERROR] Not authorized to toggle Wi-Fi radio (polkit)."
      echo "[$(log_ts)] [ERROR] Output: ${out}"
      return 77
    fi
    echo "[$(log_ts)] [WARN] nmcli radio wifi off failed (rc=${rc}): ${out}"
  fi

  sleep 0.5

  out="$(nmcli -w 10 radio wifi on 2>&1)"; rc=$?
  if (( rc != 0 )); then
    if grep -qi 'not authorized' <<<"$out"; then
      echo "[$(log_ts)] [ERROR] Not authorized to toggle Wi-Fi radio (polkit)."
      echo "[$(log_ts)] [ERROR] Output: ${out}"
      return 77
    fi
    echo "[$(log_ts)] [WARN] nmcli radio wifi on failed (rc=${rc}): ${out}"
  fi

  return 0
}

{
  echo "[$(log_ts)] [INFO] Wi-Fi watchdog iface=${IFACE} gw=${GW}"

  if ! nm_has; then
    echo "[$(log_ts)] [ERROR] nmcli not available; cannot perform NetworkManager recovery"
    exit 1
  fi

  # Fail early if NM reports that required permissions are not granted.
  # - Connection bounce: org.freedesktop.NetworkManager.network-control
  # - Radio toggle:      org.freedesktop.NetworkManager.enable-disable-wifi
  nm_require_perm_or_die "org.freedesktop.NetworkManager.network-control"
  nm_require_perm_or_die "org.freedesktop.NetworkManager.enable-disable-wifi"

  log_state

  if health_ok; then
    echo "[$(log_ts)] [INFO] Link OK"
    exit 0
  fi

  echo "[$(log_ts)] [WARN] Link unhealthy; attempting recovery"

  for ((i=1; i<=RECONNECT_TRIES; i++)); do
    echo "[$(log_ts)] [INFO] Recovery A: flush neighbor/route cache (try ${i}/${RECONNECT_TRIES})"
    nm_reset_link
    if health_ok; then
      echo "[$(log_ts)] [INFO] Link OK after cache flush"
      exit 0
    fi

    echo "[$(log_ts)] [INFO] Recovery B: bounce NetworkManager connection (try ${i}/${RECONNECT_TRIES})"
    if ! nm_bounce_connection; then
      rc=$?
      if [[ $rc -eq 77 ]]; then
        echo "[$(log_ts)] [ERROR] Recovery aborted due to insufficient permissions (network-control)."
        exit 2
      fi
    fi
    sleep 0.6
    if health_ok; then
      echo "[$(log_ts)] [INFO] Link OK after connection bounce"
      exit 0
    fi

    echo "[$(log_ts)] [INFO] Recovery C: toggle Wi-Fi radio (try ${i}/${RECONNECT_TRIES})"
    if ! nm_toggle_radio; then
      rc=$?
      if [[ $rc -eq 77 ]]; then
        echo "[$(log_ts)] [ERROR] Recovery aborted due to insufficient permissions (enable-disable-wifi)."
        exit 2
      fi
    fi
    sleep 0.8
    if health_ok; then
      echo "[$(log_ts)] [INFO] Link OK after radio toggle"
      exit 0
    fi

    log_state
    echo "[$(log_ts)] [WARN] Recovery attempt failed (try ${i}/${RECONNECT_TRIES})"
  done

  echo "[$(log_ts)] [ERROR] Recovery did not restore connectivity"
  exit 1
} >>"${watch_log}"

