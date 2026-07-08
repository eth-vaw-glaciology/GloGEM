#!/bin/bash
# run_flow_both.sh — Run RGI7 and RGI6 GloGEMflow forward in parallel (48 batches total)
#
# Launches RGI7 first, waits 30 s for all IDL processes to read config.pro,
# then switches config and launches RGI6.  Both sets run concurrently.
# Spinup caches must be cleared beforehand (already done).
#
# Launch:
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -s flow_both "bash scripts/run_flow_both.sh"

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N=24
BASE="/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"
LOG_DIR="$GLOGEM_DIR/logs"
LOGFILE="$LOG_DIR/flow_both_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"
exec > >(tee "$LOGFILE") 2>&1

echo "========================================================"
echo "  RGI7 + RGI6 GloGEMflow started: $(date)"
echo "========================================================"

wait_for_batches() {
    local done_dir="$1" n="$2" label="$3"
    while true; do
        ndone=$(ls "$done_dir"/batch*.done 2>/dev/null | wc -l) || true
        printf "  %s  [%s]  %d/%d done\n" "$(date +%H:%M:%S)" "$label" "$ndone" "$n"
        [ "$ndone" -ge "$n" ] && break
        sleep 60
    done
    echo "[done] $label finished at $(date)"
}

# ── RGI7 GloGEMflow ──────────────────────────────────────────────────────────
echo ""
echo "=== Launching RGI7 GloGEMflow ($N batches) ==="
DONE7=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi7_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE7" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi7_fwd"

echo ""
echo "--- Waiting 30 s for all RGI7 IDL processes to read config.pro ---"
sleep 30

# ── RGI6 GloGEMflow ──────────────────────────────────────────────────────────
echo ""
echo "=== Clearing RGI6 spinup cache ==="
if ls "$BASE/alps_flow_rgi6/spinup_cache/"*.sav 2>/dev/null | head -1 | grep -q '.'; then
    n_sav=$(ls "$BASE/alps_flow_rgi6/spinup_cache/"*.sav | wc -l)
    rm -f "$BASE/alps_flow_rgi6/spinup_cache/"*.sav
    echo "  Removed $n_sav stale .sav files."
else
    echo "  No spinup cache to clear."
fi

echo ""
echo "=== Launching RGI6 GloGEMflow ($N batches) ==="
DONE6=$(mktemp -d)
cp "$GLOGEM_DIR/scripts/config_flow_rgi6_fwd.pro" "$GLOGEM_DIR/config.pro"
DONE_DIR="$DONE6" bash "$GLOGEM_DIR/scripts/launch_batches.sh" "$N" "flow_rgi6_fwd"

# ── Wait for both in parallel ─────────────────────────────────────────────────
echo ""
echo "=== Both sets running — monitoring progress ==="
echo "[wait] Watching for $N .done files each in:"
echo "       RGI7: $DONE7"
echo "       RGI6: $DONE6"

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
echo "  RGI7 + RGI6 GloGEMflow complete: $(date)"
echo "  Log: $LOGFILE"
echo "========================================================"
