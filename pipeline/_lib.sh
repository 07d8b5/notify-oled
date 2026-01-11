#!/usr/bin/env bash
set -euo pipefail

# Restrict default permissions for any files we create (logs, outputs).
umask 077

# Resolve repository root.
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_script_dir}/.." && pwd)"

# Optional override.
if [[ -f "${REPO_ROOT}/config/repo.conf" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/config/repo.conf"
fi

# Re-resolve if an override was provided.
if [[ -n "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd "${REPO_ROOT}" && pwd)"
fi

OUT_DIR="${REPO_ROOT}/out"
LOG_DIR="${REPO_ROOT}/logs"

mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${LOG_DIR}/collectors"

log_ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[$(log_ts)] [FATAL] Missing required command: $1" >&2
    exit 127
  }
}

clamp6() {
  # Pads/truncates to 6 characters (byte-based; intended for ASCII).
  printf '%-6.6s' "$1"
}
