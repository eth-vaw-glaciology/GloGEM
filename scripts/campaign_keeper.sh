#!/bin/bash
# campaign_keeper.sh -- keeps the GMIP4 rerun campaign alive without anyone watching it.
#
# Runs as a detached tmux session on a host that is NOT scheduled to reboot (iceberg).
# Every POLL minutes it:
#   1. makes sure every managed host that is up (and can see the input + output volumes)
#      has its watcher running, restarting it if the host rebooted or the watcher died;
#   2. re-queues any batch-job that is not done, not queued, not running anywhere reachable,
#      and whose log has been silent for STALE_MIN minutes -- so work lost to a reboot comes
#      back automatically instead of vanishing from the queue.
#
# vierzack05 is deliberately NOT managed here: it reboots on 11 Sep and is shared with a
# colleague. Re-enable it by hand afterwards with the one-liner in auto_relaunch_watcher.sh.
#
# Start:  tmux new-session -d -s gmip4_keeper "bash scripts/campaign_keeper.sh"
# Stop:   tmux kill-session -t gmip4_keeper
set -uo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"; cd "$GLOGEM_DIR"
LOGFILE="$GLOGEM_DIR/logs/campaign_keeper_$(date +%Y%m%d_%H%M%S).log"
POLL_MIN=20
STALE_MIN=90
# Host list is re-read every round from this file, so a host can be added or removed while
# the keeper runs (that is how vierzack05 comes back after its maintenance).
HOSTS_FILE="$GLOGEM_DIR/logs/keeper_hosts.txt"
[ -f "$HOSTS_FILE" ] || echo "vierzack04:40 vierzack06:30 vierzack03:20 iceberg:7" | tr " " "\n" > "$HOSTS_FILE"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== campaign keeper up on $(hostname): $(date) ==="
echo "    host list: $HOSTS_FILE   poll ${POLL_MIN} min   stale threshold ${STALE_MIN} min"

while true; do
    HOSTS=$(grep -vE "^\s*(#|$)" "$HOSTS_FILE" | tr "\n" " ")
    alive=""
    for hc in $HOSTS; do
        h="${hc%%:*}"; ceil="${hc##*:}"
        # host must be up AND able to see input + output before it is given work
        if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "$h" \
             "test -r /itet-stor/jabeer/glogem/data/catchments/RGI12_caucasus_batch01.dat && \
              test -d /scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development" 2>/dev/null; then
            echo "[$(date '+%F %T')] $h not ready (down, or volumes not back yet) -- skipping this round"
            continue
        fi
        alive="$alive $h"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "$h" \
             "tmux has-session -t gmip4_watcher_$h" 2>/dev/null; then
            ssh -o BatchMode=yes -o ConnectTimeout=15 "$h" \
              "cd '$GLOGEM_DIR' && tmux new-session -d -s gmip4_watcher_$h \
               'QUEUE_FILE=logs/launch_queue_$h.txt LICENSE_CEILING=$ceil bash scripts/auto_relaunch_watcher.sh'" 2>/dev/null \
              && echo "[$(date '+%F %T')] $h: watcher was missing -- restarted (ceiling $ceil)"
        fi
    done

    # re-queue anything lost, onto whichever live host has the shortest queue
    if [ -n "$alive" ]; then
        best=""; bestn=999999
        for h in $alive; do
            # grep -vc exits 1 on a zero count, so guard instead of using ||
            n=$(grep -vc '^#' "logs/launch_queue_$h.txt" 2>/dev/null)
            case "$n" in ''|*[!0-9]*) n=999999 ;; esac
            if [ "$n" -lt "$bestn" ]; then bestn=$n; best=$h; fi
        done
        out=$(python3 scripts/requeue_incomplete.py --stale-min "$STALE_MIN" --to "$best" 2>&1)
        echo "$out" | grep -qE "\| 0 LOST" || { echo "[$(date '+%F %T')] reconciliation -> $best"; echo "$out" | sed 's/^/    /'; }
        # duplicate guard (2026-09-10): a job must never sit in two queues -- that would let two
        # hosts compute the same batch and write the same output files. Cheap to check, fatal to miss.
        dups=$(cat logs/launch_queue_*.txt 2>/dev/null | grep -v '^#' | cut -d'|' -f1-4 | sort | uniq -d | wc -l)
        if [ "$dups" -gt 0 ]; then
            echo "[$(date '+%F %T')] !! $dups job(s) queued on more than one host -- pausing reconciliation, fix by hand"
            STALE_MIN=999999   # stop re-queueing until a human looks
        fi
    fi
    sleep $((POLL_MIN * 60))
done
