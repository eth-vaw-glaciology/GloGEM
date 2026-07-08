#!/bin/bash
# autostart_bayescal_training.sh — waits for GloGEM/config.pro to be free, then
# automatically runs the Tier-3 Bayesian (Kennedy-O'Hagan) calibration training
# pipeline: LHS design -> real IDL training runs -> emulator -> KO posterior ->
# LOO validation -> IDL residual-file writeback.
#
# WHY THIS EXISTS: this project hit a live, multi-hour production run (24+24-batch
# GloGEMflow forward simulation) actively using config.pro the first time the
# calibration training runs were attempted -- config.pro is user-managed (see its own
# header: "do not edit while chain is running") and IDL/CPU/license seats are shared,
# finite resources, so launching a competing `idl` session while another job is live
# would both corrupt that job's config and slow it down. This script polls until NO
# real IDL process is running anywhere on the machine, THEN (and only then) backs up
# config.pro, activates the training config, and runs the pipeline -- unattended, so
# training can start the moment the machine is actually free instead of requiring
# someone to notice and launch it by hand.
#
# What it does NOT do: it never touches config.pro while anything is using it, and it
# restores your ORIGINAL config.pro once the IDL-dependent training step finishes
# (steps 3-5 of the pipeline -- emulator fit, KO calibration, LOO validation, residual
# writeback -- are pure Python and need neither IDL nor config.pro).
#
# Usage (run in its own tmux session, like this project's other long-running jobs):
#   tmux new-session -d -s bayescal_autostart \
#     "cd ~/projects/glogemflow_development/GloGEM && bash scripts/autostart_bayescal_training.sh"
#   tmux attach -t bayescal_autostart    # to watch progress
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

POLL_INTERVAL=120   # seconds between busy-checks -- deliberately coarser than
                     # overnight_chain.sh's own 60s (this script may sit waiting for
                     # HOURS, no need to poll as tightly as a same-session wait_batches)
LOCK_FILE="/tmp/bayescal_autostart.lock"

# ── logging ───────────────────────────────────────────────────────────────────

LOG_DIR="${GLOGEM_DIR}/logs"
mkdir -p "$LOG_DIR"
CHAIN_LOG="${LOG_DIR}/bayescal_autostart_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$CHAIN_LOG") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── single-instance guard ────────────────────────────────────────────────────
# Two copies of this script racing to swap config.pro would be exactly the kind of
# collision this script exists to PREVENT -- refuse to start a second one.

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

# ── wait for IDL / config.pro to be free ─────────────────────────────────────
# Detection is process-based (not tied to any one job's *.done sentinel directory)
# so this works regardless of what is currently occupying IDL: any real IDL worker
# process (bin.linux.x86_64/idl -- NOT the idle `read -r` wrapper shells that
# launch_batches.sh leaves sitting after a batch finishes) means busy.

is_idl_busy() {
    pgrep -f 'bin\.linux\.x86_64/idl' >/dev/null 2>&1
}

log "Waiting for all IDL activity on this machine to finish..."
first_check=1
while is_idl_busy; do
    n_proc="$(pgrep -f 'bin\.linux\.x86_64/idl' | wc -l)"
    if [[ "$first_check" -eq 1 ]]; then
        log "  IDL busy ($n_proc worker process(es) running) — will keep checking every ${POLL_INTERVAL}s."
        first_check=0
    else
        log "  still busy ($n_proc worker process(es))"
    fi
    sleep "$POLL_INTERVAL"
done
log "No IDL processes detected. Waiting one more check interval to rule out a brief gap between phases..."
sleep "$POLL_INTERVAL"
if is_idl_busy; then
    log "IDL became busy again during the confirmation wait — resuming poll loop."
    exec "$0" "$CALIB_CONFIG" "$TRAINING_ONLY"
fi
log "Confirmed free. Proceeding."

# ── back up config.pro before touching it ────────────────────────────────────

CONFIG_PRO="${GLOGEM_DIR}/config.pro"
BACKUP_DIR="${GLOGEM_DIR}/logs/config_pro_backups"
mkdir -p "$BACKUP_DIR"
if [[ -f "$CONFIG_PRO" ]]; then
    BACKUP_PATH="${BACKUP_DIR}/config.pro.$(date +%Y%m%d_%H%M%S).bak"
    cp "$CONFIG_PRO" "$BACKUP_PATH"
    log "Backed up existing config.pro -> $BACKUP_PATH (will be restored after training)"
else
    BACKUP_PATH=""
    log "No existing config.pro found (nothing to back up)."
fi

restore_config() {
    if [[ -n "$BACKUP_PATH" && -f "$BACKUP_PATH" ]]; then
        cp "$BACKUP_PATH" "$CONFIG_PRO"
        log "Restored original config.pro from $BACKUP_PATH"
    fi
}

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

# ── step 2a: write training inputs (safe — no config.pro / IDL yet) ──────────

log "=== STEP 2a: write training inputs ==="
python "${ICETEMP_DIR}/scripts/02_run_training.py" "$CALIB_CONFIG"

# ── activate the training config (the one config.pro-touching action this script
#    takes — only reached after the busy-wait above confirmed IDL is free) ───────

TRAINING_CONFIG="${GLOGEM_DIR}/scripts/config_bayescal_training.pro"
if [[ ! -f "$TRAINING_CONFIG" ]]; then
    log "ERROR: $TRAINING_CONFIG not found after step 2a — aborting before touching config.pro."
    exit 1
fi
cp "$TRAINING_CONFIG" "$CONFIG_PRO"
log "Activated training config: cp $TRAINING_CONFIG -> $CONFIG_PRO"

# Always attempt to restore config.pro on exit from here on, success or failure —
# leaving the user's config.pro pointed at a calibration-training run would silently
# break the NEXT time they (or overnight_chain.sh) expect it to hold their own config.
trap 'restore_config; rm -f "$LOCK_FILE"' EXIT

# ── step 2b: run the real IDL training matrix ─────────────────────────────────

log "=== STEP 2b: run IDL training runs (this is the slow part — see the runtime feasibility spike / config for expected duration) ==="
python "${ICETEMP_DIR}/scripts/02_run_training.py" "$CALIB_CONFIG" --run idl

# training is IDL-dependent; everything after this point is pure Python and does not
# need config.pro, so restore it now rather than holding it for the rest of the run.
restore_config

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
