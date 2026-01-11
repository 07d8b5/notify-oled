#!/usr/bin/env bash
set -euo pipefail

# Run all collectors and write NDJSON to out/raw.ndjson.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

need_cmd jq

raw_tmp="${OUT_DIR}/raw.ndjson.tmp"
raw_out="${OUT_DIR}/raw.ndjson"
run_log="${LOG_DIR}/run_all.log"

: >"${raw_tmp}"

{
  echo "[$(log_ts)] [INFO] Starting collection"

  shopt -s nullglob
  collectors=("${REPO_ROOT}/collectors"/*)
  shopt -u nullglob

  if (( ${#collectors[@]} == 0 )); then
    echo "[$(log_ts)] [WARN] No collectors found in collectors/"
  fi

  for c in "${collectors[@]}"; do
    [[ -f "$c" && -x "$c" ]] || continue

    base="$(basename "$c")"
    stderr_log="${LOG_DIR}/collectors/${base}.log"

    # Run collector. Prefer a timeout if available.
    out=""
    status=0
    set +e
    if command -v timeout >/dev/null 2>&1; then
      out="$(timeout 10s "$c" 2>>"${stderr_log}")"
      status=$?
    else
      out="$("$c" 2>>"${stderr_log}")"
      status=$?
    fi
    set -e

    if [[ $status -eq 124 ]]; then
      echo "[$(log_ts)] [WARN] Timeout: ${base} (last stderr lines follow)"
      tail -n 20 "${stderr_log}" | sed 's/^/  | /'
    fi

    # Require exactly one non-empty line.
    mapfile -t _lines < <(printf '%s' "$out" | tr -d '\r' | awk 'NF')

    if [[ $status -ne 0 || ${#_lines[@]} -eq 0 ]]; then
      echo "[$(log_ts)] [WARN] Collector failed: ${base} (exit=${status})"
      printf '{"name":"%s","value":"ERR","enabled":true}\n' "${base%.*}" >>"${raw_tmp}"
      continue
    fi

    if (( ${#_lines[@]} != 1 )); then
      echo "[$(log_ts)] [WARN] Collector output must be exactly one non-empty line: ${base} (lines=${#_lines[@]})"
      printf '{"name":"%s","value":"BAD","enabled":true}\n' "${base%.*}" >>"${raw_tmp}"
      continue
    fi

    line="${_lines[0]}"

    # Validate JSON contract.
    if ! jq -e 'type=="object" and (.name|type=="string") and has("value") and (.enabled|type=="boolean")' \
      >/dev/null 2>&1 <<<"${line}"; then
      echo "[$(log_ts)] [WARN] Collector output invalid JSON: ${base}"
      printf '{"name":"%s","value":"BAD","enabled":true}\n' "${base%.*}" >>"${raw_tmp}"
      continue
    fi

    # Normalize to a single compact line.
    jq -c . <<<"${line}" >>"${raw_tmp}"
  done

  echo "[$(log_ts)] [INFO] Collection complete"
} >>"${run_log}"

mv -f "${raw_tmp}" "${raw_out}"
