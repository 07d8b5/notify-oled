#!/usr/bin/env bash
set -euo pipefail

# 1-minute load average (first field of /proc/loadavg)
load="NA"
if [[ -r /proc/loadavg ]]; then
  load="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo NA)"
fi

# Disabled by default; enable it when you want it eligible for display.
printf '{"name":"LOAD","value":"%s","enabled":false}\n' "$load"
