#!/bin/bash
# run_rgi6_repair.sh — RGI6 calibration + Δh + flow forward runs
#
# Runs four phases sequentially, each over 24 parallel batches:
#   1. RGI6 calibration          (config_cali_rgi6.pro)
#   2. Copy cal params to flow dir + clear spinup cache
#   3. RGI6 Δh forward run       (config_dh_rgi6_fwd.pro)
#   4. RGI6 GloGEMflow forward   (config_flow_rgi6_fwd.pro)
#
# Launch:
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -s rgi6_repair "bash scripts/run_rgi6_repair.sh"

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N=24
BASE="/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"
CAL_DIR="$BASE/alps_dhdt_rgi6/monthly/CentralEurope/calibration"
FLOW_CAL_DIR="$BASE/alps_flow_rgi6/monthly/CentralEurope/calibration"
SPINUP_DIR="$BASE/alps_flow_rgi6/spinup_cache"
LOG_DIR="$GLOGEM_DIR/logs"
LOGFILE="$LOG_DIR/rgi6_repair_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOGFILE") 2>&1

echo "========================================================"
echo "  RGI6 repair chain started: $(date)"
echo "========================================================"

# ── Helper: wait until all N batches drop a .done file ───────────────────────
wait_for_batches() {
    local done_dir="$1" n="$2" label="$3"
    echo "[wait] $label — watching for $n .done files in $done_dir"
    while true; do
        ndone=$(ls "$done_dir"/batch*.done 2>/dev/null | wc -l)
        printf "  %s  %d/%d batches done\n" "$(date +%H:%M:%S)" "$ndone" "$n"
        [ "$ndone" -ge "$n" ] && break
        sleep 60
    done
    echo "[done] $label finished at $(date)"
}

# ── Phase 1: RGI6 calibration ─────────────────────────────────────────────────
echo ""
echo "=== Phase 1: RGI6 calibration (${N} batches) ==="
DONE1=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_cali_rgi6.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE1" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "cali_rgi6"
wait_for_batches "$DONE1" "$N" "RGI6 calibration"
rm -rf "$DONE1"

# ── Copy calibration parameters to flow directory ─────────────────────────────
echo ""
echo "=== Copying RGI6 calibration params to alps_flow_rgi6 ==="
mkdir -p "$FLOW_CAL_DIR"
cp "$CAL_DIR"/calibrate_m1_cID9_centraleurope_final_era5_alps_batch*.dat "$FLOW_CAL_DIR/"
cp "$CAL_DIR"/toff_m1_cID9_centraleurope_alps_batch*.dat                 "$FLOW_CAL_DIR/"
echo "  Copied $(ls "$FLOW_CAL_DIR"/calibrate_*_alps_batch*.dat | wc -l) calibration files."

# ── Phase 2: RGI6 Δh parameterisation forward run ────────────────────────────
echo ""
echo "=== Phase 2: RGI6 Δh parameterisation forward run (${N} batches) ==="
DONE2=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_dh_rgi6_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE2" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "dh_rgi6_fwd"
wait_for_batches "$DONE2" "$N" "RGI6 Δh forward run"
rm -rf "$DONE2"

# ── Clear RGI6 spinup cache (MB params changed, cache is stale) ──────────────
echo ""
echo "=== Clearing RGI6 flow spinup cache ==="
if ls "$SPINUP_DIR"/*.sav 2>/dev/null | head -1 | grep -q '.'; then
    n_sav=$(ls "$SPINUP_DIR"/*.sav | wc -l)
    rm -f "$SPINUP_DIR"/*.sav
    echo "  Removed $n_sav stale .sav files."
else
    echo "  No spinup cache to clear."
fi

# ── Phase 3: RGI6 GloGEMflow forward run ──────────────────────────────────────
echo ""
echo "=== Phase 3: RGI6 GloGEMflow forward run (${N} batches) ==="
DONE3=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi6_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE3" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi6_fwd"
wait_for_batches "$DONE3" "$N" "RGI6 GloGEMflow forward run"
rm -rf "$DONE3"

echo ""
echo "========================================================"
echo "  RGI6 repair complete: $(date)"
echo "  Log: $LOGFILE"
echo "========================================================"
