#!/bin/bash
# overnight_chain.sh  —  automated GloGEM overnight forward run chain
#
# Sequence:
#   1. Wait for RGI7 + RGI6 Δh calibration to finish
#   2. Copy MB calibration params to flow directories
#   3. Clear stale spinup caches (new MB → must rebuild)
#   4. Launch RGI7 Δh forward  (16 batches)
#   5. Launch RGI6 Δh forward  (16 batches)
#   6. Launch RGI7 flow forward (16 batches, spinup rebuilt)
#   7. Launch RGI6 flow forward (16 batches, spinup rebuilt)
#
# Start this in its own tmux session before going to sleep:
#   tmux new-session -d -s overnight "cd ~/projects/glogemflow_development/GloGEM && bash scripts/overnight_chain.sh"
#   tmux attach -t overnight    # to watch progress

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"
N=24
SCRIPTS="${GLOGEM_DIR}/scripts"

# ── logging ───────────────────────────────────────────────────────────────────

CHAIN_LOG="${GLOGEM_DIR}/logs/overnight_chain_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${GLOGEM_DIR}/logs"
exec > >(tee -a "$CHAIN_LOG") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log "overnight_chain.sh started — log: $CHAIN_LOG"
log "GLOGEM_DIR=$GLOGEM_DIR   BASE=$BASE   N=$N"

# ── helpers ───────────────────────────────────────────────────────────────────

wait_calib() {
    # Waits until the calibration _final_ file appears for both RGI versions.
    # This file is written as the last step of calibrate='y' runs.
    local rgi7="${BASE}/alps_dhdt_rgi7/monthly/CentralEurope/calibration/calibrate_m1_cID9_centraleurope_final_era5.dat"
    local rgi6="${BASE}/alps_dhdt_rgi6/monthly/CentralEurope/calibration/calibrate_m1_cID9_centraleurope_final_era5.dat"
    log "Waiting for calibration to complete..."
    while true; do
        local r7="$( [[ -f "$rgi7" ]] && echo 'done' || echo 'running' )"
        local r6="$( [[ -f "$rgi6" ]] && echo 'done' || echo 'running' )"
        if [[ "$r7" == "done" && "$r6" == "done" ]]; then break; fi
        log "  RGI7: $r7   RGI6: $r6"
        sleep 60
    done
    log "Both calibrations complete."
}

copy_calib() {
    local src="${BASE}/$1/monthly/CentralEurope/calibration"
    local dst="${BASE}/$2/monthly/CentralEurope/calibration"
    log "Copying MB calibration params: $1 → $2"
    mkdir -p "$dst"
    cp -v "$src"/* "$dst"/
}

clear_spinup() {
    local dir="${BASE}/$1/spinup_cache"
    if [[ -d "$dir" ]]; then
        local n
        n=$(find "$dir" -name "*.sav" | wc -l)
        log "Clearing spinup cache ($n files): $dir"
        rm -rf "$dir"
    else
        log "No spinup cache found at $dir (OK — will be built fresh)"
    fi
}

launch_phase() {
    local stub="$1" prefix="$2"
    log "Switching config.pro → $stub"
    cp "$SCRIPTS/$stub" "$GLOGEM_DIR/config.pro"
    export DONE_DIR
    log "Launching $N batches: $prefix"
    bash "$SCRIPTS/launch_batches.sh" "$N" "$prefix"
}

wait_batches() {
    local prefix="$1"
    log "Waiting for all $N batches of '$prefix' to finish..."
    while true; do
        local n_done
        n_done=$(find "$DONE_DIR" -name "*.done" | wc -l)
        if [[ "$n_done" -ge "$N" ]]; then break; fi
        log "  $n_done/$N batches done"
        sleep 60
    done
    log "Phase '$prefix' complete."
}

# ── PHASE 0: calibration ─────────────────────────────────────────────────────

wait_calib

# ── PHASE 0.5: copy MB params to flow directories ────────────────────────────

copy_calib alps_dhdt_rgi7 alps_flow_rgi7
copy_calib alps_dhdt_rgi6 alps_flow_rgi6

# ── PHASE 0.6: clear spinup caches (new MB = must rebuild) ───────────────────

clear_spinup alps_flow_rgi7
clear_spinup alps_flow_rgi6

# ── PHASE 1: RGI7 Δh forward ─────────────────────────────────────────────────

log "=== PHASE 1: RGI7 Δh parameterisation forward ==="
DONE_DIR="/tmp/glogem_done_dh_rgi7"
rm -rf "$DONE_DIR" && mkdir -p "$DONE_DIR"
launch_phase config_dh_rgi7_fwd.pro alps_dh_rgi7
wait_batches alps_dh_rgi7

# ── PHASE 2: RGI6 Δh forward ─────────────────────────────────────────────────

log "=== PHASE 2: RGI6 Δh parameterisation forward ==="
DONE_DIR="/tmp/glogem_done_dh_rgi6"
rm -rf "$DONE_DIR" && mkdir -p "$DONE_DIR"
launch_phase config_dh_rgi6_fwd.pro alps_dh_rgi6
wait_batches alps_dh_rgi6

# ── PHASE 3: RGI7 flow forward ───────────────────────────────────────────────

log "=== PHASE 3: RGI7 GloGEMflow forward (spinup will be built) ==="
DONE_DIR="/tmp/glogem_done_flow_rgi7"
rm -rf "$DONE_DIR" && mkdir -p "$DONE_DIR"
launch_phase config_flow_rgi7_fwd.pro alps_flow_rgi7
wait_batches alps_flow_rgi7

# ── PHASE 4: RGI6 flow forward ───────────────────────────────────────────────

log "=== PHASE 4: RGI6 GloGEMflow forward (spinup will be built) ==="
DONE_DIR="/tmp/glogem_done_flow_rgi6"
rm -rf "$DONE_DIR" && mkdir -p "$DONE_DIR"
launch_phase config_flow_rgi6_fwd.pro alps_flow_rgi6
wait_batches alps_flow_rgi6

# ── DONE ─────────────────────────────────────────────────────────────────────

log "=== ALL PHASES COMPLETE ==="
log "Results:"
log "  Δh  RGI7: ${BASE}/alps_dhdt_rgi7/"
log "  Δh  RGI6: ${BASE}/alps_dhdt_rgi6/"
log "  Flow RGI7: ${BASE}/alps_flow_rgi7/"
log "  Flow RGI6: ${BASE}/alps_flow_rgi6/"
