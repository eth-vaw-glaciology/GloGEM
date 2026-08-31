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

QUEUE_FILE="$GLOGEM_DIR/logs/launch_queue.txt"
LOGFILE="$GLOGEM_DIR/logs/auto_relaunch_watcher_$(date +%Y%m%d_%H%M%S).log"
LICENSE_CEILING=55
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
    pgrep -u "$(whoami)" -f "bin.linux.x86_64/idl$" 2>/dev/null | wc -l
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

while true; do
    n=$(live_sessions)
    if [ "$n" -lt "$LICENSE_CEILING" ]; then
        entry=$(pop_queue)
        if [ -n "$entry" ]; then
            IFS='|' read -r cfg batch prefix done_dir <<< "$entry"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Free slot ($n/$LICENSE_CEILING) -- launching batch $batch of $cfg"
            mkdir -p "$done_dir"
            CONFIG_FILE="$cfg" DONE_DIR="$done_dir" BATCH_LIST="$batch" \
                bash scripts/launch_batches.sh 1 "$prefix" >> "$LOGFILE" 2>&1
        fi
    fi
    sleep "$POLL_SECONDS"
done
