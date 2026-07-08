#!/bin/bash
# autostart_bayescal_training.sh — runs the full Tier-3 Bayesian (Kennedy-O'Hagan)
# calibration pipeline end to end, unattended: LHS design -> real IDL training runs
# -> emulator -> KO posterior -> LOO validation -> IDL residual-file writeback.
#
# Training runs launch IDL with the environment variable GLOGEM_CONFIG pointed at an
# auto-generated, self-contained config (see icetemp.calibration.runner.GloGEMRunner's
# module docstring) -- settings.pro reads GLOGEM_CONFIG in preference to config.pro
# when set, confirmed the ONLY place a config path gets resolved. This script therefore
# NEVER reads or writes the real GloGEM/config.pro, and is safe to run concurrently
# with any other GloGEM job already using it (verified against a live 48-process
# production forward-run chain: no interference, no config.pro contention).
#
# Usage (run in its own tmux session, like this project's other long-running jobs):
#   tmux new-session -d -s bayescal_training \
#     "cd ~/projects/glogemflow_development/GloGEM && bash scripts/autostart_bayescal_training.sh"
#   tmux attach -t bayescal_training    # to watch progress
#
# Optional: pass a different calibration config YAML as $1 (default: the CentralEurope
# production config committed at glogemflow_icetemp/config/bayescal_centraleurope.yaml).
# Pass --training-only as $2 to stop after the IDL training runs (skip the automatic
# emulator/calibrate/validate/writeback steps).

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$GLOGEM_DIR/.." && pwd)"
ICETEMP_DIR="${REPO_ROOT}/glogemflow_icetemp"
CALIB_CONFIG="${1:-${ICETEMP_DIR}/config/bayescal_centraleurope.yaml}"
TRAINING_ONLY="${2:-}"

CONDA_SH="/scratch_net/vierzack04/jabeer/conda/etc/profile.d/conda.sh"
CONDA_ENV="glogemflow_icetemp"
LOCK_FILE="/tmp/bayescal_autostart.lock"

# ── logging ───────────────────────────────────────────────────────────────────

LOG_DIR="${GLOGEM_DIR}/logs"
mkdir -p "$LOG_DIR"
CHAIN_LOG="${LOG_DIR}/bayescal_autostart_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$CHAIN_LOG") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── single-instance guard ────────────────────────────────────────────────────
# Two copies racing over the same run_dir / *.done sentinels would corrupt each
# other's progress tracking -- refuse to start a second one.

if [[ -f "$LOCK_FILE" ]]; then
    existing_pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
        log "ERROR: another autostart_bayescal_training.sh is already running (pid $existing_pid, lock: $LOCK_FILE). Exiting."
        exit 1
    fi
    log "Stale lock file found (pid $existing_pid not running) -- removing."
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log "autostart_bayescal_training.sh started — log: $CHAIN_LOG"
log "GLOGEM_DIR=$GLOGEM_DIR  CALIB_CONFIG=$CALIB_CONFIG  TRAINING_ONLY=${TRAINING_ONLY:-no}"

# ── activate the Python environment ──────────────────────────────────────────

# shellcheck disable=SC1090
source "$CONDA_SH"
conda activate "$CONDA_ENV"
cd "$ICETEMP_DIR"

# ── step 1: build design (idempotent — skip if already built) ────────────────

DESIGN_PATH="$(python - "$CALIB_CONFIG" <<'PYEOF'
import sys
from icetemp.calibration import CalibrationConfig
print(CalibrationConfig.from_yaml(sys.argv[1]).design_path)
PYEOF
)"
if [[ -f "$DESIGN_PATH" ]]; then
    log "Design already exists ($DESIGN_PATH) — skipping step 1."
else
    log "=== STEP 1: build design ==="
    python "${ICETEMP_DIR}/scripts/01_build_design.py" "$CALIB_CONFIG"
fi

# ── step 2: write training inputs + run the real IDL training matrix ─────────
# Neither sub-step touches config.pro (see header) -- no wait, no backup/restore needed.

log "=== STEP 2: write training inputs ==="
python "${ICETEMP_DIR}/scripts/02_run_training.py" "$CALIB_CONFIG"

log "=== STEP 2b: run IDL training runs (the slow part — see the feasibility-spike timing in the run log) ==="
python "${ICETEMP_DIR}/scripts/02_run_training.py" "$CALIB_CONFIG" --run idl

if [[ "$TRAINING_ONLY" == "--training-only" ]]; then
    log "TRAINING_ONLY set — stopping after IDL training runs. Run steps 3-5 manually when ready:"
    log "  python scripts/03_fit_emulator.py $CALIB_CONFIG"
    log "  python scripts/04_calibrate.py $CALIB_CONFIG"
    log "  python scripts/05_validate_and_writeback.py $CALIB_CONFIG"
    exit 0
fi

# ── steps 3-5: emulator, KO calibration, LOO validation + writeback ──────────

log "=== STEP 3: fit emulator ==="
python "${ICETEMP_DIR}/scripts/03_fit_emulator.py" "$CALIB_CONFIG"

log "=== STEP 4: Bayesian calibration (emcee) ==="
python "${ICETEMP_DIR}/scripts/04_calibrate.py" "$CALIB_CONFIG"

log "=== STEP 5: leave-one-out validation + IDL residual writeback ==="
python "${ICETEMP_DIR}/scripts/05_validate_and_writeback.py" "$CALIB_CONFIG"

log "=== ALL STEPS COMPLETE ==="
log "Results directory: $(python - "$CALIB_CONFIG" <<'PYEOF'
import sys
from icetemp.calibration import CalibrationConfig
print(CalibrationConfig.from_yaml(sys.argv[1]).output_path)
PYEOF
)"
log "Review the LOO decision rule output above before wiring the residual file into"
log "firnice_temp_calib_bayes_file — it is written for inspection either way."
