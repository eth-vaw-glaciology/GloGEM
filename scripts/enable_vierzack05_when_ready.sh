#!/bin/bash
# enable_vierzack05_when_ready.sh -- bring vierzack05 back into the campaign.
#
# It is idle because its maintenance reboot is pending. This waits for whichever comes first:
#   * the reboot has happened (uptime below REBOOT_UPTIME_H hours), or
#   * DEADLINE passes -- so the machine is used by then at the latest, rebooted or not.
# Then it gives vierzack05 a fair share of the pending jobs and hands it to the campaign keeper,
# which from that point starts and restarts its watcher like any other host.
#
# Runs on iceberg (which is not scheduled to reboot):
#   tmux new-session -d -s gmip4_enable_v05 "bash scripts/enable_vierzack05_when_ready.sh"
set -uo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"; cd "$GLOGEM_DIR"
HOST=vierzack05
CEILING=20
DEADLINE="${DEADLINE:-2026-09-12 08:00}"
REBOOT_UPTIME_H=3
POLL_MIN=10
LOGFILE="$GLOGEM_DIR/logs/enable_${HOST}_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

DEADLINE_EPOCH=$(date -d "$DEADLINE" +%s) || exit 1
echo "=== waiting to re-enable $HOST: reboot detected, or $DEADLINE at the latest ==="

while true; do
    reason=""
    up=$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST" \
         'awk "{printf \"%.0f\", \$1/3600}" /proc/uptime' 2>/dev/null || echo "")
    if [ -n "$up" ] && [ "$up" -lt "$REBOOT_UPTIME_H" ]; then
        reason="it rebooted (uptime ${up}h)"
    elif [ "$(date +%s)" -ge "$DEADLINE_EPOCH" ]; then
        reason="deadline $DEADLINE reached (no reboot yet)"
    fi

    if [ -n "$reason" ]; then
        # host must be able to see input + output before it is given any work
        if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST" \
             "test -r /itet-stor/jabeer/glogem/data/catchments/RGI12_caucasus_batch01.dat && \
              test -d /scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development" 2>/dev/null; then
            echo "[$(date '+%F %T')] $reason, but volumes are not back yet -- waiting"
            sleep $((POLL_MIN * 60)); continue
        fi
        echo "[$(date '+%F %T')] enabling $HOST: $reason"

        # the old watcher carries the expired SHUTDOWN_AT=2026-09-11 06:00 and would defer
        # every job, so it has to go before the keeper starts a clean one
        ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST" "tmux kill-session -t gmip4_watcher_$HOST" 2>/dev/null

        python3 - "$HOST" "$CEILING" <<'PY'
import sys, os, glob
host, ceil = sys.argv[1], int(sys.argv[2])
P = "/home/jabeer/projects/glogemflow_development/GloGEM/logs"
W = {}
for l in open(f"{P}/keeper_hosts.txt"):
    l = l.strip()
    if l and not l.startswith("#"):
        h, c = l.split(":"); W[h] = int(c)
W[host] = ceil
pend = {}
for h in W:
    f = f"{P}/launch_queue_{h}.txt"
    pend[h] = [l.strip() for l in open(f)] if os.path.exists(f) else []
    pend[h] = [l for l in pend[h] if l and not l.startswith("#")]
allj = [e for h in pend for e in pend[h]]
tot = sum(W.values())
# rebalance everything pending in proportion to each host's ceiling
i, new = 0, {}
for h in sorted(W, key=lambda x: -W[x]):
    n = len(allj) - i if h == sorted(W, key=lambda x: -W[x])[-1] else round(len(allj) * W[h] / tot)
    new[h] = allj[i:i + n]; i += n
for h, jobs in new.items():
    f = f"{P}/launch_queue_{h}.txt"
    hdr = [l for l in open(f)] if os.path.exists(f) else []
    hdr = [l for l in hdr if l.startswith("#")]
    with open(f + ".new", "w") as fh:
        fh.writelines(hdr); fh.writelines(e + "\n" for e in jobs)
    os.replace(f + ".new", f)
    print(f"    {h}: {len(jobs)} jobs queued")
# duplicate check -- a job in two queues would let two hosts write the same output
seen = [ "|".join(e.split("|")[:4]) for h in new for e in new[h] ]
assert len(seen) == len(set(seen)), "DUPLICATE JOBS AFTER REBALANCE -- aborting"
print("    no job is queued twice")
PY
        if [ $? -ne 0 ]; then echo "[$(date '+%F %T')] rebalance failed -- leaving everything as it was"; exit 1; fi

        # hand the host to the keeper; it starts and thereafter maintains the watcher
        grep -q "^${HOST}:" "$GLOGEM_DIR/logs/keeper_hosts.txt" || \
            echo "${HOST}:${CEILING}" >> "$GLOGEM_DIR/logs/keeper_hosts.txt"
        echo "[$(date '+%F %T')] $HOST handed to the campaign keeper (ceiling $CEILING); it will start the watcher within 20 min"
        exit 0
    fi
    sleep $((POLL_MIN * 60))
done
