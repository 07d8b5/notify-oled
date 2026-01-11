#!/usr/bin/env bash
set -euo pipefail

# Root filesystem usage percent (no percent sign)
use="NA"
if command -v df >/dev/null 2>&1; then
  use="$(df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')"
  use="${use:-NA}"
fi

# Example policy: enable if root usage is >= 90%
enabled=false
if [[ "$use" =~ ^[0-9]+$ ]] && (( use >= 90 )); then
  enabled=true
fi

printf '{"name":"DISK","value":"%s","enabled":%s}\n' "${use}%" "$enabled"
