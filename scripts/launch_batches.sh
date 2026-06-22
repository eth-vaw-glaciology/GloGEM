#!/bin/bash
# launch_batches.sh  —  start N parallel GloGEM flow batches in tmux sessions
#
# Each session runs:  GLOGEM_BATCH=<NN> idl -e "@glogem"
# config.pro reads GLOGEM_BATCH and sets catchment_selection = 'alps_batchNN'.
#
# Prerequisites (run once before this script):
#   1.  python scripts/create_batches.py          # writes catchment files
#   2.  Kill any running serial session:
#         tmux kill-session -t <session-name>
#   3.  Verify config.pro has:
#         dirres pointing to alps_flow/
#         GCM_rcp_idx = [1, 2, 4]
#
# Usage:
#   cd /home/jabeer/projects/glogemflow_development/GloGEM
#   bash scripts/launch_batches.sh [N_BATCHES]
#   bash scripts/launch_batches.sh 16            # default

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-16}"
LOG_DIR="${GLOGEM_DIR}/logs"

cd "$GLOGEM_DIR"
mkdir -p "$LOG_DIR"

echo "GloGEM directory : $GLOGEM_DIR"
echo "Launching        : $N batch sessions"
echo "Logs             : $LOG_DIR"
echo ""

for i in $(seq 1 "$N"); do
    BATCH=$(printf "%02d" "$i")
    SESSION="alps_flow_batch${BATCH}"
    LOGFILE="${LOG_DIR}/batch${BATCH}_$(date +%Y%m%d_%H%M%S).log"

    # Kill any leftover session with the same name
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    tmux new-session -d -s "$SESSION" \
        "cd '${GLOGEM_DIR}' && GLOGEM_BATCH=${BATCH} idl -e '@glogem' 2>&1 | tee '${LOGFILE}'; echo 'Batch ${BATCH} finished'; read -r _"

    echo "  Started: $SESSION  (GLOGEM_BATCH=$BATCH)"
done

echo ""
echo "All $N sessions launched."
echo ""
echo "Useful commands:"
echo "  tmux ls                              # list all sessions"
echo "  tmux attach -t alps_flow_batch01     # attach to batch 01"
echo "  Ctrl-b d                             # detach without killing"
echo "  tail -f ${LOG_DIR}/batch01_*.log     # follow log"
