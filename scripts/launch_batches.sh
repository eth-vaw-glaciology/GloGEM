#!/bin/bash
# launch_batches.sh  —  start N parallel GloGEM batches in tmux sessions
#
# Each session runs:  echo ".r glogem" | GLOGEM_BATCH=<NN> idl
# config.pro reads GLOGEM_BATCH and sets catchment_selection = 'alps_batchNN'.
#
# Usage:
#   cd /home/jabeer/projects/glogemflow_development/GloGEM
#   bash scripts/launch_batches.sh [N_BATCHES] [SESSION_PREFIX]
#   bash scripts/launch_batches.sh 16 alps_flow_rgi7
#
# Environment variables (set by overnight_chain.sh):
#   DONE_DIR   — if set, touch $DONE_DIR/batchNN.done after IDL exits
#                (used by the chain script to detect completion)

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-16}"
PREFIX="${2:-alps_flow}"
LOG_DIR="${GLOGEM_DIR}/logs"

cd "$GLOGEM_DIR"
mkdir -p "$LOG_DIR"

echo "GloGEM directory : $GLOGEM_DIR"
echo "Session prefix   : $PREFIX"
echo "Launching        : $N batch sessions"
echo "Logs             : $LOG_DIR"
echo ""

for i in $(seq 1 "$N"); do
    BATCH=$(printf "%02d" "$i")
    SESSION="${PREFIX}_batch${BATCH}"
    LOGFILE="${LOG_DIR}/${PREFIX}_batch${BATCH}_$(date +%Y%m%d_%H%M%S).log"

    DONE_CMD=""
    if [[ -n "${DONE_DIR:-}" ]]; then
        DONE_CMD="; touch '${DONE_DIR}/batch${BATCH}.done'"
    fi

    # Kill any leftover session with the same name
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    tmux new-session -d -s "$SESSION" \
        "cd '${GLOGEM_DIR}' && echo '.r glogem' | GLOGEM_BATCH=${BATCH} idl 2>&1 | tee '${LOGFILE}'; echo 'Batch ${BATCH} finished'${DONE_CMD}; read -r _"

    echo "  Started: $SESSION  (GLOGEM_BATCH=$BATCH)"
done

echo ""
echo "All $N sessions launched."
echo ""
echo "Useful commands:"
echo "  tmux ls                              # list all sessions"
echo "  tmux attach -t ${PREFIX}_batch01     # attach to batch 01"
echo "  Ctrl-b d                             # detach without killing"
echo "  tail -f ${LOG_DIR}/${PREFIX}_batch01_*.log  # follow log"
