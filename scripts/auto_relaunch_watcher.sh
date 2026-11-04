#!/bin/bash
# auto_relaunch_watcher.sh — runs as its own detached tmux session on
# vierzack04. Polls the number of live IDL sessions every POLL_SECONDS;
# whenever there's headroom under LICENSE_CEILING, pops the next queued
# batch launch from QUEUE_FILE and starts it. Keeps going indefinitely
# (unlike watch_and_launch_subregions.sh, which is one-shot).
#
# QUEUE_FILE format: one pending batch launch per line,
#   CONFIG_FILE|BATCH_NUMBER|SESSION_PREFIX|DONE_DIR
# Blank lines and lines starting with # are ignored. Append more lines
# to QUEUE_FILE at any time (e.g. from a live Claude Code session) --
# the watcher re-reads it every loop, so new work picked up automatically.
#
# Launch (from this host, vierzack04):
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -d -s gmip4_auto_relaunch "bash scripts/auto_relaunch_watcher.sh"
#
# Check on it later:
#   tmux capture-pane -p -t gmip4_auto_relaunch -S -40
#
# Stop it:
#   tmux kill-session -t gmip4_auto_relaunch

set -uo pipefail   # deliberately NOT -e: this must survive a single bad
                    # launch attempt and keep polling, not die.

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$GLOGEM_DIR"

# Both overridable from the environment so one watcher can run per host, each
# with its own queue and ceiling (2026-09-08):
#   QUEUE_FILE=logs/launch_queue_vierzack06.txt LICENSE_CEILING=26 bash scripts/auto_relaunch_watcher.sh
QUEUE_FILE="${QUEUE_FILE:-$GLOGEM_DIR/logs/launch_queue.txt}"
LOGFILE="$GLOGEM_DIR/logs/auto_relaunch_watcher_$(hostname)_$(date +%Y%m%d_%H%M%S).log"
LICENSE_CEILING="${LICENSE_CEILING:-55}"
# Optional launch deadline (2026-09-10): stop starting new batches after this time, so a host
# that is about to be rebooted is never given work it cannot finish. Already-running sessions
# are untouched. Format: anything `date -d` understands, e.g. "2026-09-11 05:00".
LAUNCH_UNTIL="${LAUNCH_UNTIL:-}"
# Better than a flat deadline on a host with a known shutdown (2026-09-10): give each queue
# entry an optional 5th field with its expected hours, and launch it only if it would FINISH
# before SHUTDOWN_AT (minus SHUTDOWN_MARGIN_MIN). Entries that no longer fit are moved to
# $QUEUE_FILE.deferred -- requeue_incomplete.py picks those up for another host, because that
# file deliberately does not match the launch_queue_*.txt glob.
SHUTDOWN_AT="${SHUTDOWN_AT:-}"
SHUTDOWN_MARGIN_MIN="${SHUTDOWN_MARGIN_MIN:-30}"
if [ -n "$SHUTDOWN_AT" ]; then
    SHUTDOWN_EPOCH=$(date -d "$SHUTDOWN_AT" +%s 2>/dev/null) || { echo "bad SHUTDOWN_AT: $SHUTDOWN_AT"; exit 1; }
fi
if [ -n "$LAUNCH_UNTIL" ]; then
    LAUNCH_UNTIL_EPOCH=$(date -d "$LAUNCH_UNTIL" +%s 2>/dev/null) || { echo "bad LAUNCH_UNTIL: $LAUNCH_UNTIL"; exit 1; }
fi
POLL_SECONDS=120

mkdir -p "$GLOGEM_DIR/logs"
touch "$QUEUE_FILE"
exec > >(tee -a "$LOGFILE") 2>&1

echo "======================================================"
echo "  Auto-relaunch watcher started: $(date)"
echo "  Queue file: $QUEUE_FILE"
echo "  License ceiling: $LICENSE_CEILING   Poll: ${POLL_SECONDS}s"
echo "======================================================"

live_sessions() {
    # numeric UID: whoami fails without a passwd entry, and an empty -u makes
    # pgrep return nothing, which reads as "no jobs running"
    pgrep -u "$(id -u)" -f "bin.linux.x86_64/idl$" 2>/dev/null | wc -l
}

# Pop the first non-comment, non-blank line from QUEUE_FILE and echo it,
# rewriting the file without that line. Empty echo if queue is empty.
pop_queue() {
    local line
    line=$(grep -v '^\s*#' "$QUEUE_FILE" | grep -v '^\s*$' | head -1)
    if [ -n "$line" ]; then
        # Remove exactly this line (first match) from the file, preserving comments/blanks.
        awk -v target="$line" 'BEGIN{done=0} { if (!done && $0==target) {done=1; next} print }' "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
        mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
    fi
    echo "$line"
}

# Each poll fills ALL free slots (2026-09-08; previously one launch per poll, which
# took >1 h to fill a 40-slot host), with a short gap between launches so IDL
# licence checkouts don't collide.
while true; do
    n=$(live_sessions)
    if [ -n "$LAUNCH_UNTIL" ] && [ "$(date +%s)" -ge "$LAUNCH_UNTIL_EPOCH" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] launch deadline $LAUNCH_UNTIL reached -- no new launches; $(grep -vc '^#' "$QUEUE_FILE" 2>/dev/null) job(s) left in the queue for another host"
        exit 0
    fi
    while [ "$n" -lt "$LICENSE_CEILING" ]; do
        # Circuit breaker (2026-09-09): a launch that dies at once (licence server down, NFS not
        # back after a reboot, broken code) still consumes its queue entry as a .failed marker.
        # If 5 or more launches failed in the last 10 minutes, stop launching this poll instead
        # of draining the whole queue; re-queue the .failed ones by hand once the cause is fixed.
        nfail=$(find "$GLOGEM_DIR"/logs/done_*_rerun_*/ -name '*.failed' -mmin -10 2>/dev/null | wc -l)
        if [ "$nfail" -ge 5 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $nfail launches failed in the last 10 min -- pausing launches this poll (queue untouched)"
            break
        fi
        entry=$(pop_queue)
        [ -n "$entry" ] || break
        IFS='|' read -r cfg batch prefix done_dir est <<< "$entry"
        if [ -n "$SHUTDOWN_AT" ]; then
            need=$(awk -v e="${est:-0}" 'BEGIN{printf "%d", e*3600}')
            if [ $(( $(date +%s) + need + SHUTDOWN_MARGIN_MIN*60 )) -ge "$SHUTDOWN_EPOCH" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${prefix} batch ${batch} (~${est:-?} h) would not finish before ${SHUTDOWN_AT} -- deferred"
                echo "$entry" >> "${QUEUE_FILE}.deferred"
                continue
            fi
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Free slot ($n/$LICENSE_CEILING) -- launching batch $batch of $cfg"
        mkdir -p "$done_dir"
        CONFIG_FILE="$cfg" DONE_DIR="$done_dir" BATCH_LIST="$batch" \
            bash scripts/launch_batches.sh 1 "$prefix" >> "$LOGFILE" 2>&1
        sleep 5
        n=$(live_sessions)
    done
    sleep "$POLL_SECONDS"
done
