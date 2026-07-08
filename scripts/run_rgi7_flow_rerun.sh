#!/bin/bash
# run_rgi7_flow_rerun.sh — Re-run RGI7 GloGEMflow forward (24 batches)
#
# Run after fixing width_mid_dx volume convention in glogemflow_coupled.pro.
# Spinup cache must be cleared first (already done).
#
# Launch:
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -s rgi7_flow_rerun "bash scripts/run_rgi7_flow_rerun.sh"

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N=24
LOG_DIR="$GLOGEM_DIR/logs"
LOGFILE="$LOG_DIR/rgi7_flow_rerun_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOGFILE") 2>&1

echo "========================================================"
echo "  RGI7 GloGEMflow re-run started: $(date)"
echo "========================================================"

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

echo ""
echo "=== RGI7 GloGEMflow forward run ($N batches) ==="
DONE=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi7_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi7_fwd"
wait_for_batches "$DONE" "$N" "RGI7 GloGEMflow forward run"
rm -rf "$DONE"

echo ""
echo "========================================================"
echo "  RGI7 GloGEMflow re-run complete: $(date)"
echo "  Log: $LOGFILE"
echo "========================================================"
