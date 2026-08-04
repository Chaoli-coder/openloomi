#!/usr/bin/env bash
# Run SWE-bench Verified with OpenLoomi (development build).
#
# Pipeline:
#   1. Verify the OpenLoomi dev API is reachable at $OPENLOOMI_API_URL.
#   2. Verify that openloomi-ctl is on disk.
#   3. Verify or capture the auth token.
#   4. Launch the OpenLoomi runner against the configured split/limit.
#
# Resumable: instances already present in $SWEBENCH_PREDICTIONS are skipped.
# Use --force to re-run every instance from scratch.
#
# Cross-platform: works in Git Bash, WSL, and PowerShell with `bash`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGS_DIR="${ROOT_DIR}/logs"

OPENLOOMI_API_URL="${OPENLOOMI_API_URL:-http://127.0.0.1:3515}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.openloomi/token}"

SPLIT="test"
OUTPUT_MODEL="openloomi-verified"
MAX_CONCURRENT=1
TIMEOUT=3600
PROVIDER=""
MODEL=""
FORCE="0"
SKIP_CHECKS="0"

print_help() {
  cat <<'EOF'
Usage:
  ./run_swebench.sh [options]

Options:
  --split <test>                 Dataset split. SWE-bench Verified has only `test`.
  --output-model <name>          Name used in predictions.jsonl and trajectory dir.
                                 (default: openloomi-verified)
  --max-concurrent <n>           Concurrency (default: 1).
  --timeout <seconds>            Per-instance timeout in seconds (default: 3600).
  --provider <name>              Forwarded to openloomi-ctl (e.g. claude, codex).
  --model <id>                   Forwarded to openloomi-ctl.
  --instance-id <id>             Only run the given instance_id. Repeatable.
  --repo <owner/name>            Only run instances of the given repo. Repeatable.
  --limit <n>                    Only run the first N matching instances.
  --api-url <url>                OpenLoomi API base URL (default: http://127.0.0.1:3515).
  --openloomi-ctl <path>         Full path to openloomi-ctl(.exe).
  --token-file <path>            Path to the OpenLoomi auth token
                                 (default: ~/.openloomi/token).
  --force                        Re-run every instance and overwrite existing
                                 predictions.
  --skip-checks                  Skip the OpenLoomi API and CLI sanity checks.
  --dry-run                      Print the plan but do not run anything.
  --help                         Show this message.

Environment variables (override CLI flags):
  OPENLOOMI_API_URL
  OPENLOOMI_CTL
  TOKEN_FILE
  SWEBENCH_DATASET
  SWEBENCH_WORK_DIR
  SWEBENCH_PREDICTIONS
  SWEBENCH_MODEL_NAME
  SWEBENCH_MAX_CONCURRENT
  SWEBENCH_TIMEOUT

Outputs:
  - logs/openloomi_verified_<model>_<timestamp>.log     (terminal transcript)
  - logs/openloomi_verified_<model>_<timestamp>.json    (run summary)
  - predictions/<model>.jsonl                           (SWE-bench predictions)
  - trajectories/<model>/<instance_id>/attempt_*.json   (per-attempt trajectory)
  - $SWEBENCH_WORK_DIR/workspaces/<instance_id>/src/    (cloned repos)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --split)              SPLIT="$2"; shift 2;;
    --output-model)       OUTPUT_MODEL="$2"; shift 2;;
    --max-concurrent)     MAX_CONCURRENT="$2"; shift 2;;
    --timeout)            TIMEOUT="$2"; shift 2;;
    --provider)           PROVIDER="$2"; shift 2;;
    --model)              MODEL="$2"; shift 2;;
    --instance-id)        INSTANCE_ID+=("$2"); shift 2;;
    --repo)               REPO+=("$2"); shift 2;;
    --limit)              LIMIT="$2"; shift 2;;
    --api-url)            OPENLOOMI_API_URL="$2"; shift 2;;
    --openloomi-ctl)      OPENLOOMI_CTL="$2"; shift 2;;
    --token-file)         TOKEN_FILE="$2"; shift 2;;
    --force)              FORCE="1"; shift;;
    --skip-checks)        SKIP_CHECKS="1"; shift;;
    --dry-run)            DRY_RUN="1"; shift;;
    --help|-h)            print_help; exit 0;;
    *) echo "Unknown option: $1" >&2; print_help; exit 2;;
  esac
done

mkdir -p "${LOGS_DIR}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
TERMINAL_LOG="${LOGS_DIR}/openloomi_verified_terminal_${TIMESTAMP}.log"
exec > >(tee -a "${TERMINAL_LOG}") 2>&1

log() { printf '[run_swebench] %s\n' "$*"; }

log "OpenLoomi API URL   : ${OPENLOOMI_API_URL}"
log "openloomi-ctl       : ${OPENLOOMI_CTL:-<unset>}"
log "Token file          : ${TOKEN_FILE}"
log "Model name          : ${OUTPUT_MODEL}"
log "Concurrency         : ${MAX_CONCURRENT}"
log "Per-instance timeout: ${TIMEOUT}s"
log "Provider / Model    : ${PROVIDER:-<default>} / ${MODEL:-<default>}"
log "Force overwrite     : ${FORCE}"

# ---------------------------------------------------------------------------
# 1. Sanity checks
# ---------------------------------------------------------------------------
if [[ "${SKIP_CHECKS}" != "1" ]]; then
  log "Checking OpenLoomi API at ${OPENLOOMI_API_URL}..."
  API_HOST="$(printf '%s' "${OPENLOOMI_API_URL}" | sed -E 's#^https?://##; s#/.*$##')"
  API_PORT="$(printf '%s' "${OPENLOOMI_API_URL}" | sed -E 's#^.*:([0-9]+).*$#\1#')"
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "Test-NetConnection -ComputerName '${API_HOST%:*}' -Port ${API_PORT} | Select-Object -ExpandProperty TcpTestSucceeded" \
      | grep -q "True" || {
        log "ERROR: cannot reach ${OPENLOOMI_API_URL}. Start pnpm tauri:dev first."
        exit 2
      }
  elif command -v nc >/dev/null 2>&1; then
    nc -z "${API_HOST}" "${API_PORT}" || {
      log "ERROR: cannot reach ${OPENLOOMI_API_URL}. Start pnpm tauri:dev first."
      exit 2
    }
  else
    log "WARN: no powershell/nc found, skipping port check."
  fi
  log "OpenLoomi API reachable."

  if [[ -z "${OPENLOOMI_CTL:-}" || ! -f "${OPENLOOMI_CTL}" ]]; then
    log "ERROR: openloomi-ctl not found. Export OPENLOOMI_CTL or pass --openloomi-ctl."
    exit 2
  fi
  log "openloomi-ctl present."

  if [[ -z "${OPENLOOMI_AUTH_TOKEN:-}" ]]; then
    if [[ ! -f "${TOKEN_FILE}" ]]; then
      log "ERROR: token file not found at ${TOKEN_FILE} and OPENLOOMI_AUTH_TOKEN is empty."
      log "       Log in through the OpenLoomi desktop app, or set OPENLOOMI_AUTH_TOKEN."
      exit 2
    fi
    log "Token file found at ${TOKEN_FILE}."
  else
    log "Using OPENLOOMI_AUTH_TOKEN from environment."
  fi
fi

# ---------------------------------------------------------------------------
# 2. Build runner command
# ---------------------------------------------------------------------------
PY_ARGS=(
  "${SCRIPT_DIR}/run_benchmark_openloomi.py"
  --max-concurrent "${MAX_CONCURRENT}"
  --timeout "${TIMEOUT}"
)
[[ -n "${LIMIT:-}"      ]] && PY_ARGS+=(--limit "${LIMIT}")
[[ "${FORCE}" == "1"    ]] && PY_ARGS+=(--force)
[[ "${DRY_RUN:-0}" == "1" ]] && PY_ARGS+=(--dry-run)
[[ -n "${PROVIDER}"     ]] && PY_ARGS+=(--provider "${PROVIDER}")
[[ -n "${MODEL}"        ]] && PY_ARGS+=(--model "${MODEL}")
if [[ "${#INSTANCE_ID[@]:-0}" -gt 0 ]]; then
  for iid in "${INSTANCE_ID[@]}"; do PY_ARGS+=(--instance-id "$iid"); done
fi
if [[ "${#REPO[@]:-0}" -gt 0 ]]; then
  for r in "${REPO[@]}"; do PY_ARGS+=(--repo "$r"); done
fi

log "Launching runner:"
printf '   %q ' python "${PY_ARGS[@]}"
printf '\n'

# ---------------------------------------------------------------------------
# 3. Export environment
# ---------------------------------------------------------------------------
export OPENLOOMI_API_URL
export OPENLOOMI_CLI_DIRECT="0"
if [[ -z "${OPENLOOMI_AUTH_TOKEN:-}" && -f "${TOKEN_FILE}" ]]; then
  export OPENLOOMI_AUTH_TOKEN="$(tr -d '[:space:]' < "${TOKEN_FILE}")"
fi
export SWEBENCH_MODEL_NAME="${OUTPUT_MODEL}"
export SWEBENCH_PREDICTIONS="${ROOT_DIR}/predictions/${OUTPUT_MODEL}.jsonl"
export SWEBENCH_WORK_DIR="${SWEBENCH_WORK_DIR:-D:/swebench-work}"

log "Predictions path    : ${SWEBENCH_PREDICTIONS}"
log "Work dir            : ${SWEBENCH_WORK_DIR}"

cd "${ROOT_DIR}"
python "${PY_ARGS[@]}"
RUNNER_EXIT=$?

log "Runner exit code    : ${RUNNER_EXIT}"
log "Terminal log        : ${TERMINAL_LOG}"
exit ${RUNNER_EXIT}
