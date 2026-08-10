#!/bin/bash
# launch_batches.sh  —  start N parallel GloGEM batches in tmux sessions
#
# Each session runs:  echo ".r glogem" | GLOGEM_BATCH=<NN> idl
# config.pro (or CONFIG_FILE, see below) reads GLOGEM_BATCH and sets
# catchment_selection = '<name>_batchNN'.
#
# Usage:
#   cd /home/jabeer/projects/glogemflow_development/GloGEM
#   bash scripts/launch_batches.sh [N_BATCHES] [SESSION_PREFIX]
#   bash scripts/launch_batches.sh 16 alps_flow_rgi7
#
# Environment variables:
#   DONE_DIR     — if set, touch $DONE_DIR/batchNN.done once the batch log
#                  contains glogem.pro's own "FINISHED region !!!" marker,
#                  or write a note to $DONE_DIR/batchNN.failed otherwise
#                  (used by chain scripts to detect completion). This is a
#                  content check, not an exit-code check: IDL exits 0 even
#                  when a run fails outright (e.g. license exhaustion, a
#                  missing config) — confirmed empirically, `echo '.r
#                  nonexistent' | idl` still returns $?=0 — so checking
#                  $? here would silently treat every such failure as done.
#   CONFIG_FILE  — if set, exported per-session as GLOGEM_CONFIG so each IDL
#                  process loads this config directly by absolute path,
#                  instead of the shared base_dir/config.pro. This is what
#                  makes it safe to run multiple scenarios (or multiple
#                  hosts sharing this same NFS-mounted repo) concurrently
#                  without one launch's `cp config.pro` racing another's —
#                  each batch's config is fixed at spawn time, no shared
#                  mutable file involved. When unset, falls back to the
#                  original behaviour (each batch reads whatever the caller
#                  already copied into base_dir/config.pro).

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
if [[ -n "${CONFIG_FILE:-}" ]]; then
    echo "Config           : $CONFIG_FILE (via GLOGEM_CONFIG)"
fi
echo ""

for i in $(seq 1 "$N"); do
    BATCH=$(printf "%02d" "$i")
    SESSION="${PREFIX}_batch${BATCH}"
    LOGFILE="${LOG_DIR}/${PREFIX}_batch${BATCH}_$(date +%Y%m%d_%H%M%S).log"

    DONE_CMD=":"
    if [[ -n "${DONE_DIR:-}" ]]; then
        DONE_CMD="if grep -q 'FINISHED region !!!' '${LOGFILE}'; then touch '${DONE_DIR}/batch${BATCH}.done'; else echo \"no FINISHED marker (exit \$EC) -- see ${LOGFILE}\" > '${DONE_DIR}/batch${BATCH}.failed'; fi"
    fi

    CONFIG_ENV=""
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        CONFIG_ENV="GLOGEM_CONFIG='${CONFIG_FILE}' "
    fi

    # Kill any leftover session with the same name
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    tmux new-session -d -s "$SESSION" \
        "cd '${GLOGEM_DIR}' && echo '.r glogem' | ${CONFIG_ENV}GLOGEM_BATCH=${BATCH} idl 2>&1 | tee '${LOGFILE}'; EC=\${PIPESTATUS[1]}; echo \"Batch ${BATCH} finished (exit \$EC)\"; ${DONE_CMD}; read -r _"

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
