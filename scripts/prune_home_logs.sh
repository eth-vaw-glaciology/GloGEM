#!/bin/bash
# Keep the GloGEM log directory off the home quota.
# GloGEM's own journals (glogem_*.log, tens of MB each) and old batch logs are
# gzipped to net_scratch. Files still being written are left alone: selection is
# by mtime, so an active job's log is never touched.
set -uo pipefail

LOGS="${LOGS:-/home/jabeer/projects/glogemflow_development/GloGEM/logs}"
ARCHIVE="${ARCHIVE:-/itet-stor/jabeer/net_scratch/glogem_logs/archive}"
JOURNAL_AGE_MIN="${JOURNAL_AGE_MIN:-360}"   # 6 h
BATCH_AGE_DAYS="${BATCH_AGE_DAYS:-3}"
SOFT_MB=10000

[ -d "$LOGS" ] || exit 0
DEST="$ARCHIVE/$(date +%Y%m%d)"
mkdir -p "$DEST" 2>/dev/null || exit 0

archive() {   # $1 = find expression result via stdin
  local n=0
  while IFS= read -r -d '' f; do
    gzip -c "$f" > "$DEST/$(basename "$f").gz" 2>/dev/null && rm -f "$f" && n=$((n+1))
  done
  echo "$n"
}

a=$(find "$LOGS" -maxdepth 1 -name 'glogem_*.log' -mmin +"$JOURNAL_AGE_MIN" -print0 2>/dev/null | archive)
b=$(find "$LOGS" -maxdepth 1 -name '*.log' ! -name 'glogem_*' -mtime +"$BATCH_AGE_DAYS" -print0 2>/dev/null | archive)

# --- health checks: the two failures that have cost the most time ---
# 1. jobs that stopped mid-run (incomplete + silent) 2. idle slots beside queued work
DEAD=$(python3 - <<'PYEOF' 2>/dev/null || echo "?"
import glob, os, re, time
now=time.time(); pat=re.compile(r'_(ssp\w+?)_batch(\d+)_(\d{8}_\d{6})\.log$')
latest={}
for p in glob.glob("/home/jabeer/projects/glogemflow_development/GloGEM/logs/*batch*.log"):
    m=pat.search(os.path.basename(p))
    if not m: continue
    k=(os.path.basename(p).split('_ssp')[0], m.group(1), m.group(2))
    if k not in latest or os.path.getmtime(p)>os.path.getmtime(latest[k]): latest[k]=p
n=0
for (pre,ssp,b),p in latest.items():
    exp=4 if ssp=="ssp534over" else 8
    if sum(1 for _ in open(p) if 'FINISHED region' in _) < exp and (now-os.path.getmtime(p))/60 > 90: n+=1
print(n)
PYEOF
)
[ "${DEAD:-0}" != "0" ] && [ "${DEAD:-0}" != "?" ] &&   echo "[$(date '+%F %T')] ALERT: ${DEAD} job(s) incomplete and silent >90 min -- check for silent deaths"

QD=$(grep -h -v '^#' "$LOGS"/launch_queue_*.txt 2>/dev/null | grep -c '|' || echo 0)
if [ "${QD:-0}" -gt 0 ]; then
  IDLE=0
  while read -r h c; do
    n=$(timeout 15 ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" "pgrep -u \$(id -u) -f 'bin.linux.x86_64/idl\$' | wc -l" 2>/dev/null || echo "$c")
    [ "${n:-$c}" -lt "$c" ] && IDLE=$(( IDLE + c - ${n:-$c} ))
  done < <(sed 's/:/ /' "$LOGS/keeper_hosts.txt" 2>/dev/null)
  [ "$IDLE" -gt 4 ] && echo "[$(date '+%F %T')] ALERT: ${IDLE} idle slot(s) with ${QD} job(s) queued -- rebalance needed"
fi

used=$(du -sxm /home/jabeer 2>/dev/null | cut -f1)
pct=$(( used * 100 / SOFT_MB ))
echo "[$(date '+%F %T')] archived ${a} journal(s), ${b} batch log(s); home ${used} MB (${pct}% of soft)"
[ "$pct" -ge 85 ] && echo "  WARNING: home at ${pct}% of the ${SOFT_MB} MB soft quota"
exit 0
