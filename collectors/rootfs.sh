#!/usr/bin/env bash
set -euo pipefail

# Root filesystem usage. Enables only when usage is high.

use_pct="NA"
if command -v df >/dev/null 2>&1; then
  # Output looks like:  42%
  use_pct=$(df -P / | awk 'NR==2 {print $5}' | tr -d '"\\')
fi

enabled=false
if [[ "$use_pct" =~ ^([0-9]{1,3})%$ ]]; then
  n=${BASH_REMATCH[1]}
  if (( n >= 90 )); then
    enabled=true
  fi
fi

printf '{"name":"ROOT","value":"%s","enabled":%s}\n' "$use_pct" "$enabled"
