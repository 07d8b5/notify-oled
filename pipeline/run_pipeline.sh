#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_lib.sh
source "$HERE/_lib.sh"

logf="$LOG_DIR/pipeline.log"

stage() {
  local name="$1" cmd="$2"
  printf '[%s] START %s\n' "$(date -Is)" "$name" >>"$logf"
  if "$HERE/$cmd" >>"$logf" 2>&1; then
    printf '[%s] OK    %s\n' "$(date -Is)" "$name" >>"$logf"
  else
    printf '[%s] FAIL  %s (exit=%d)\n' "$(date -Is)" "$name" "$?" >>"$logf"
    return 1
  fi
}

stage "collect"        "00_run_all.sh"
stage "wifi_watchdog"  "10_wifi_watchdog.sh"
stage "select"         "20_select.sh"
stage "send"           "30_send.sh"
stage "housekeeping"   "40_housekeeping.sh"

