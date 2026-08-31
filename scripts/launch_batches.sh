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
#                  contains glogem.pro's own "FINISHED region !!!" marker
#                  once per expected GCM (see EXPECTED_GCMS below), or
#                  write a note to $DONE_DIR/batchNN.failed otherwise
#                  (used by chain scripts to detect completion). This is a
#                  content check, not an exit-code check: IDL exits 0 even
#                  when a run fails outright (e.g. license exhaustion, a
#                  missing config) — confirmed empirically, `echo '.r
#                  nonexistent' | idl` still returns $?=0 — so checking
#                  $? here would silently treat every such failure as done.
#
#                  Counting occurrences (not just checking presence) matters:
#                  the Aug 11 NFS outage interrupted several already-running
#                  multi-GCM batches mid-loop, so some GCMs finished (their
#                  own "FINISHED region" markers written) before the outage
#                  and the rest silently never ran -- a plain grep -q for
#                  "does the marker appear at all" saw the early GCMs'
#                  markers and wrongly called the whole batch done, hiding
#                  the gap until it surfaced days later as NaN/missing data
#                  in combine_gmip4_output.py. Discovered 2026-08-17 across
#                  Svalbard/Iceland/RussianArctic/Scandinavia.
#
#   EXPECTED_GCMS — how many "FINISHED region" occurrences the batch's own
#                  config actually calls for. If unset, inferred from
#                  CONFIG_FILE's own GCM_model_idx (GCM_model_idx=[0] is
#                  GloGEM's sentinel for "all 8"; any other value is a
#                  1-based index list, so its element count is the
#                  expected GCM count -- see settings.pro:61,536-539 and
#                  glogem.pro:85). Falls back to 1 (today's behaviour: any
#                  marker at all counts as done) when no CONFIG_FILE is set
#                  or it has no GCM_model_idx (calibration runs, which
#                  don't loop over GCMs at all).
#   BATCH_LIST   — if set (space or comma separated, e.g. "3 8" or "3,8"),
#                  launches only those batch numbers instead of 1..N --
#                  for targeted repairs of specific batches (e.g. the ones
#                  an interrupted run left with missing GCMs) without
#                  wasting compute recomputing batches that were already
#                  correct. N is still used for the log/summary text.
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

# Determine how many "FINISHED region" markers a genuinely complete batch
# should produce -- see EXPECTED_GCMS note above.
if [[ -z "${EXPECTED_GCMS:-}" ]]; then
    EXPECTED_GCMS=1
    if [[ -n "${CONFIG_FILE:-}" && -f "$CONFIG_FILE" ]]; then
        idx_line=$(grep -o 'GCM_model_idx *= *\[[^]]*\]' "$CONFIG_FILE" | tail -1) || true
        if [[ -n "$idx_line" ]]; then
            idx_vals="${idx_line#*[}"
            idx_vals="${idx_vals%]*}"
            first_val="${idx_vals%%,*}"
            first_val="$(echo "$first_val" | tr -d '[:space:]')"
            if [[ "$first_val" == "0" ]]; then
                EXPECTED_GCMS=8
            else
                EXPECTED_GCMS=$(( $(echo "$idx_vals" | tr -cd ',' | wc -c) + 1 ))
            fi
        fi
    fi
fi

echo "GloGEM directory : $GLOGEM_DIR"
echo "Session prefix   : $PREFIX"
echo "Launching        : $N batch sessions"
echo "Logs             : $LOG_DIR"
if [[ -n "${CONFIG_FILE:-}" ]]; then
    echo "Config           : $CONFIG_FILE (via GLOGEM_CONFIG)"
fi
if [[ -n "${DONE_DIR:-}" ]]; then
    echo "Expected GCMs    : $EXPECTED_GCMS (per batch, for completion detection)"
fi
echo ""

if [[ -n "${BATCH_LIST:-}" ]]; then
    BATCH_NUMS=$(echo "$BATCH_LIST" | tr ',' ' ')
else
    BATCH_NUMS=$(seq 1 "$N")
fi

for i in $BATCH_NUMS; do
    # Strip any leading zeros first: printf "%02d" "08" errors out ("invalid
    # octal number") since bash printf treats a leading-zero numeric string
    # as octal, and 08/09 aren't valid octal digits.
    i="${i#0}"; i="${i#0}"
    BATCH=$(printf "%02d" "$i")
    SESSION="${PREFIX}_batch${BATCH}"
    LOGFILE="${LOG_DIR}/${PREFIX}_batch${BATCH}_$(date +%Y%m%d_%H%M%S).log"

    DONE_CMD=":"
    if [[ -n "${DONE_DIR:-}" ]]; then
        DONE_CMD="nfin=\$(grep -c 'FINISHED region !!!' '${LOGFILE}' || true); if [ \"\${nfin:-0}\" -ge ${EXPECTED_GCMS} ]; then touch '${DONE_DIR}/batch${BATCH}.done'; else echo \"only \${nfin:-0}/${EXPECTED_GCMS} FINISHED markers (exit \$EC) -- see ${LOGFILE}\" > '${DONE_DIR}/batch${BATCH}.failed'; fi"
    fi

    CONFIG_ENV=""
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        CONFIG_ENV="GLOGEM_CONFIG='${CONFIG_FILE}' "
    fi

    # Kill any leftover session with the same name
    tmux kill-session -t "$SESSION" 2>/dev/null || true

    # Filter the (very verbose -- per-glacier-per-year "Flow: vol=..." lines
    # plus per-glacier spin-up iteration detail, ~99.9% of raw output on a
    # large-region batch, confirmed 2026-08-31: 888,640 raw lines vs. ~150-250
    # kept) stream down to the markers actually used for completion detection,
    # error diagnosis and health checks -- this is what filled /home to the
    # quota ceiling twice (2026-08-18, 2026-08-31). -A10 after FINISHED
    # region catches its GCM/calving-flux/usage-stats/time-elapsed block in
    # one match rather than needing each as a separate pattern.
    # NOTE: lowercase bare "error" deliberately excluded -- it false-positives
    # on the benign "Volume error : -0.25 %" spin-up diagnostic printed for
    # EVERY glacier, which defeated most of the reduction (confirmed
    # 2026-08-31: 888,640 -> 6,569 lines with it, -> 3,503 without, on the
    # same real log). Capitalized Error/ERROR plus Illegal/Undefined variable/
    # WARNING/etc. still catch every genuine error class seen this project.
    KEEP_PATTERN='Loaded user config|Catchment selection|Reanalysis product selected|MIP scenario selected|FINISHED region|WARNING|Error|ERROR|Illegal|Undefined variable|Permission denied|Failed to acquire|No licenses|Execution halted|Parameter-File.*not available|^License:|^IDL [0-9]'

    tmux new-session -d -s "$SESSION" \
        "cd '${GLOGEM_DIR}' && echo '.r glogem' | ${CONFIG_ENV}GLOGEM_BATCH=${BATCH} idl 2>&1 | grep --line-buffered -E -A10 '${KEEP_PATTERN}' | tee '${LOGFILE}'; EC=\${PIPESTATUS[1]}; echo \"Batch ${BATCH} finished (exit \$EC)\"; ${DONE_CMD}; read -r _"

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
