#!/bin/bash
# One-shot scheduler, run in a tmux session on iceberg (no reboot there) on 2026-09-09:
# waits until 2026-09-10 00:05, then starts one rerun watcher per vierzack. The vierzacks
# reboot ~19:30 on 2026-09-09, which kills every tmux session there; the queue files on
# /home survive. Retries a host every 5 min for up to three hours if it is not back yet.
set -u
P=/home/jabeer/projects/glogemflow_development/GloGEM
LOG=$P/logs/restart_watchers_after_reboot_$(date +%Y%m%d_%H%M%S).log
exec >> "$LOG" 2>&1
target=$(date -d '2026-09-10 00:05' +%s)
echo "$(date '+%F %T') scheduler up on $(hostname); starting watchers at 2026-09-10 00:05"
while [ "$(date +%s)" -lt "$target" ]; do sleep 60; done
declare -A CEIL=([vierzack04]=40 [vierzack06]=26 [vierzack03]=18 [vierzack05]=24)
for h in vierzack04 vierzack06 vierzack03 vierzack05; do
  for try in $(seq 1 36); do
    # Only start when the host is back AND can see /home, the input data (/itet-stor) and the
    # output volume (a local disk on vierzack04, NFS-exported to the others) -- all autofs, so
    # the test itself triggers the mount. Without this a host that is up before vierzack04
    # would launch batches that die at once, and each dead launch consumes a queue entry.
    if ssh -o BatchMode=yes -o ConnectTimeout=15 "$h" "cd '$P' && test -f logs/launch_queue_$h.txt && test -r /itet-stor/jabeer/glogem/data/catchments/RGI12_caucasus_batch01.dat && test -d /scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/caucasus_flow_rgi7_gmip4 && { tmux ls 2>/dev/null | grep -q '^gmip4_watcher_$h:' || tmux new-session -d -s gmip4_watcher_$h 'QUEUE_FILE=logs/launch_queue_$h.txt LICENSE_CEILING=${CEIL[$h]} bash scripts/auto_relaunch_watcher.sh'; } && tmux ls | grep -q '^gmip4_watcher_$h:'"; then
      echo "$(date '+%F %T') $h: watcher running (ceiling ${CEIL[$h]}, queue logs/launch_queue_$h.txt)"; break
    else
      echo "$(date '+%F %T') $h: not reachable or not started (try $try/36) -- retry in 5 min"; sleep 300
    fi
  done
done
echo "$(date '+%F %T') scheduler finished"
