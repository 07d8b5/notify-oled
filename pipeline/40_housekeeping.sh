    #!/usr/bin/env bash
    set -euo pipefail

    # Rotate and prune logs + a few harmless temp files.
    #
    # Intended to run as the last stage in the cron chain, but it rate-limits itself
    # (default: once per 24h) so it's cheap even if cron runs every minute.

    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

    house_log="${LOG_DIR}/housekeeping.log"

    # Defaults (can be overridden via config/housekeeping.conf)
    RUN_INTERVAL_HOURS=24
    MAX_LOG_BYTES=2097152
    ROTATE_KEEP=30
    COMPRESS=true
    COMPRESS_FROM=2
    PRUNE_DAYS=180
    OUT_TMP_PRUNE_DAYS=2

    CONF="${REPO_ROOT}/config/housekeeping.conf"
    if [[ -f "${CONF}" ]]; then
      # shellcheck disable=SC1091
      source "${CONF}"
    fi

    stamp="${OUT_DIR}/.housekeeping.stamp"
    now_epoch="$(date +%s)"

    # Rate limit.
    if [[ -f "${stamp}" ]]; then
      last_epoch="$(cat "${stamp}" 2>/dev/null || echo 0)"
      if [[ "${last_epoch}" =~ ^[0-9]+$ ]]; then
        min_delta="$(( RUN_INTERVAL_HOURS * 3600 ))"
        if (( now_epoch - last_epoch < min_delta )); then
          exit 0
        fi
      fi
    fi

    rotate_one() {
      local f="$1"
      [[ -f "${f}" ]] || return 0

      local sz
      sz="$(stat -c %s "${f}" 2>/dev/null || echo 0)"
      [[ "${sz}" =~ ^[0-9]+$ ]] || sz=0

      if (( sz < MAX_LOG_BYTES )); then
        return 0
      fi

      # Drop the oldest rotation.
      rm -f "${f}.${ROTATE_KEEP}" "${f}.${ROTATE_KEEP}.gz" 2>/dev/null || true

      # Shift rotations upward.
      local i
      for (( i=ROTATE_KEEP-1; i>=1; i-- )); do
        if [[ -f "${f}.${i}.gz" ]]; then
          mv -f "${f}.${i}.gz" "${f}.$((i+1)).gz"
        elif [[ -f "${f}.${i}" ]]; then
          mv -f "${f}.${i}" "${f}.$((i+1))"
        fi
      done

      # Rotate current.
      mv -f "${f}" "${f}.1"
      : > "${f}"

      # Compress older rotations.
      if [[ "${COMPRESS}" == "true" ]]; then
        for (( i=COMPRESS_FROM; i<=ROTATE_KEEP; i++ )); do
          if [[ -f "${f}.${i}" ]]; then
            gzip -f "${f}.${i}" >/dev/null 2>&1 || true
          fi
        done
      fi
    }

    {
      echo "[$(log_ts)] [INFO] Housekeeping start"
      echo "[$(log_ts)] [INFO] MAX_LOG_BYTES=${MAX_LOG_BYTES} ROTATE_KEEP=${ROTATE_KEEP} COMPRESS=${COMPRESS} PRUNE_DAYS=${PRUNE_DAYS}"

      shopt -s nullglob

      # Rotate top-level logs and per-collector logs.
      for f in "${LOG_DIR}"/*.log "${LOG_DIR}/collectors"/*.log; do
        rotate_one "${f}"
      done

      # Optional time-based pruning of old rotated logs.
      if [[ "${PRUNE_DAYS}" =~ ^[0-9]+$ ]] && (( PRUNE_DAYS > 0 )); then
        find "${LOG_DIR}" -type f \( -name '*.gz' -o -name '*.log.[0-9]*' \) -mtime +"${PRUNE_DAYS}" -delete 2>/dev/null || true
      fi

      # Remove stale temp files in out/.
      if [[ "${OUT_TMP_PRUNE_DAYS}" =~ ^[0-9]+$ ]] && (( OUT_TMP_PRUNE_DAYS > 0 )); then
        find "${OUT_DIR}" -maxdepth 1 -type f -name '*.tmp' -mtime +"${OUT_TMP_PRUNE_DAYS}" -delete 2>/dev/null || true
      fi

      echo "[$(log_ts)] [INFO] Housekeeping complete"
    } >> "${house_log}"

    printf '%s
' "${now_epoch}" > "${stamp}"

