#!/usr/bin/env bash
# Run the official SWE-bench Docker harness against an OpenLoomi predictions
# file. This is the second stage of the pipeline:
#
#   stage 1  → run_swebench.sh produces predictions/<model>.jsonl
#   stage 2  → run_swebench_harness.sh scores it with the official harness
#
# Prerequisites:
#   - pip install -e in $SWE_BENCH_HOME (the official SWE-bench repo).
#   - Docker Desktop is running and the user can pull/build images.
#   - At least 120 GB free disk and 16 GB RAM.
#
# This script does not run any agents. It only evaluates an existing
# predictions file. Re-running is safe: it appends a new run_id to
# logs/ and evaluation_results/ in the SWE-bench repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SWE_BENCH_HOME="${SWE_BENCH_HOME:-D:/openloomi3/openloomi/benchmark/SWE-Bench-CL}"
DATASET_NAME="${DATASET_NAME:-princeton-nlp/SWE-bench_Verified}"
PREDICTIONS_PATH="${PREDICTIONS_PATH:-${ROOT_DIR}/predictions/openloomi-verified.jsonl}"
RUN_ID="${RUN_ID:-openloomi-verified}"
MAX_WORKERS="${MAX_WORKERS:-1}"

print_help() {
  cat <<'EOF'
Usage:
  ./run_swebench_harness.sh [options]

Options:
  --swe-bench-home <path>   Path to the official SWE-bench repo
                            (default: D:/openloomi3/openloomi/benchmark/SWE-Bench-CL).
  --dataset <name>          Hugging Face dataset name for SWE-bench harness.
                            (default: princeton-nlp/SWE-bench_Verified)
  --predictions <path>      Path to predictions.jsonl
                            (default: <repo>/predictions/openloomi-verified.jsonl).
  --run-id <text>           Run identifier used for logs/ and evaluation_results/.
  --max-workers <n>         Number of concurrent Docker workers (default: 1).
  --help                    Show this message.

Environment variables (override CLI flags):
  SWE_BENCH_HOME
  DATASET_NAME
  PREDICTIONS_PATH
  RUN_ID
  MAX_WORKERS
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --swe-bench-home) SWE_BENCH_HOME="$2"; shift 2;;
    --dataset)        DATASET_NAME="$2"; shift 2;;
    --predictions)    PREDICTIONS_PATH="$2"; shift 2;;
    --run-id)         RUN_ID="$2"; shift 2;;
    --max-workers)    MAX_WORKERS="$2"; shift 2;;
    --help|-h)        print_help; exit 0;;
    *) echo "Unknown option: $1" >&2; print_help; exit 2;;
  esac
done

log() { printf '[run_swebench_harness] %s\n' "$*"; }

if [[ ! -d "${SWE_BENCH_HOME}" ]]; then
  log "ERROR: SWE-bench repo not found at ${SWE_BENCH_HOME}."
  log "       git clone https://github.com/SWE-bench/SWE-bench.git into that path."
  exit 2
fi
if [[ ! -f "${PREDICTIONS_PATH}" ]]; then
  log "ERROR: predictions file not found: ${PREDICTIONS_PATH}"
  log "       Run run_swebench.sh first to produce predictions."
  exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker is not on PATH. Install Docker Desktop first."
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  log "ERROR: docker daemon is not reachable. Start Docker Desktop."
  exit 2
fi

log "SWE-bench home  : ${SWE_BENCH_HOME}"
log "Dataset name    : ${DATASET_NAME}"
log "Predictions     : ${PREDICTIONS_PATH}"
log "Run id          : ${RUN_ID}"
log "Max workers     : ${MAX_WORKERS}"

cd "${SWE_BENCH_HOME}"

# Activate the venv if SWE_BENCH_VENV is set; otherwise rely on the active
# python interpreter.
if [[ -n "${SWE_BENCH_VENV:-}" && -f "${SWE_BENCH_VENV}/Scripts/Activate.ps1" ]]; then
  log "Activating venv: ${SWE_BENCH_VENV}"
  # shellcheck disable=SC1091
  source "${SWE_BENCH_VENV}/Scripts/activate"
elif [[ -n "${SWE_BENCH_VENV:-}" && -f "${SWE_BENCH_VENV}/bin/activate" ]]; then
  log "Activating venv: ${SWE_BENCH_VENV}"
  # shellcheck disable=SC1091
  source "${SWE_BENCH_VENV}/bin/activate"
fi

python -m swebench.harness.run_evaluation \
  --dataset_name "${DATASET_NAME}" \
  --predictions_path "${PREDICTIONS_PATH}" \
  --max_workers "${MAX_WORKERS}" \
  --run_id "${RUN_ID}"

log "Done. See logs/run_evaluation/${RUN_ID} and evaluation_results/${RUN_ID}.json"
