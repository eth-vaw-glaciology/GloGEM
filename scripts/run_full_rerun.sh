#!/bin/bash
# run_full_rerun.sh — Re-run everything after the glacier_retreat freeze-before-
# survey-year fix (glogem.pro).
#
# Phase 1: Δh forward runs, sequential (RGI7 then RGI6) — no spinup, so no
#          config.pro race risk from running one at a time.
# Phase 2: GloGEMflow forward runs, concurrent (RGI7 + RGI6) — spinup cache
#          from the previous run stays valid (the fix only changes pre-survey-
#          year geometry, which the spinup does not depend on), so caches are
#          NOT cleared this time.
#
# Launch:
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -s full_rerun "bash scripts/run_full_rerun.sh"

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N=24
LOG_DIR="$GLOGEM_DIR/logs"
LOGFILE="$LOG_DIR/full_rerun_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOGFILE") 2>&1

echo "========================================================"
echo "  Full re-run (post glacier_retreat fix) started: $(date)"
echo "========================================================"

wait_for_batches() {
    local done_dir="$1" n="$2" label="$3"
    echo "[wait] $label — watching for $n .done files in $done_dir"
    while true; do
        ndone=$(ls "$done_dir"/batch*.done 2>/dev/null | wc -l) || true
        printf "  %s  %d/%d batches done\n" "$(date +%H:%M:%S)" "$ndone" "$n"
        [ "$ndone" -ge "$n" ] && break
        sleep 60
    done
    echo "[done] $label finished at $(date)"
}

# ── Phase 1a: Δh RGI7 ─────────────────────────────────────────────────────────
echo ""
echo "=== Phase 1a: Δh RGI7 forward run ($N batches) ==="
DONE=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_dh_rgi7_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "dh_rgi7_fwd"
wait_for_batches "$DONE" "$N" "Δh RGI7 forward run"
rm -rf "$DONE"

# ── Phase 1b: Δh RGI6 ─────────────────────────────────────────────────────────
echo ""
echo "=== Phase 1b: Δh RGI6 forward run ($N batches) ==="
DONE=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_dh_rgi6_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "dh_rgi6_fwd"
wait_for_batches "$DONE" "$N" "Δh RGI6 forward run"
rm -rf "$DONE"

# ── Phase 2: GloGEMflow RGI7 + RGI6, concurrent (spinup cache preserved) ─────
echo ""
echo "=== Phase 2a: Launching GloGEMflow RGI7 ($N batches) ==="
DONE7=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi7_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE7" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi7_fwd"

echo ""
echo "--- Waiting 30 s for all RGI7 IDL processes to read config.pro ---"
sleep 30

echo ""
echo "=== Phase 2b: Launching GloGEMflow RGI6 ($N batches) ==="
echo "  (spinup cache NOT cleared — still valid after the geometry-freeze fix)"
DONE6=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi6_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE6" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi6_fwd"

echo ""
echo "=== Both flow sets running — monitoring progress ==="
rgi7_done=0; rgi6_done=0
while [ "$rgi7_done" -eq 0 ] || [ "$rgi6_done" -eq 0 ]; do
    n7=$(ls "$DONE7"/batch*.done 2>/dev/null | wc -l) || true
    n6=$(ls "$DONE6"/batch*.done 2>/dev/null | wc -l) || true
    printf "  %s  RGI7: %d/%d  RGI6: %d/%d\n" "$(date +%H:%M:%S)" "$n7" "$N" "$n6" "$N"
    [ "$n7" -ge "$N" ] && rgi7_done=1
    [ "$n6" -ge "$N" ] && rgi6_done=1
    [ "$rgi7_done" -eq 0 ] || [ "$rgi6_done" -eq 0 ] && sleep 60
done
rm -rf "$DONE7" "$DONE6"

echo ""
echo "========================================================"
echo "  Full re-run complete: $(date)"
echo "  Log: $LOGFILE"
echo "========================================================"
