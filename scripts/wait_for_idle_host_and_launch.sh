#!/bin/bash
# wait_for_idle_host_and_launch.sh — polls for a genuinely idle host and launches the full
# Tier-3 Bayesian calibration campaign via autostart_bayescal_training.sh.
#
# v4 (current): the previous version (v3) added a Phase 1 that waited for the STRING "gmip4"
# to disappear from `ps aux` on every host before even looking at load. Confirmed BROKEN after
# 18h of zero progress (started 2026-08-11 16:50, still waiting at 2026-08-12 11:xx). Direct
# process inspection at that point showed the check was wrong in BOTH directions:
#   - vierzack03/04/06/07 each showed "1 gmip4-related process" PERMANENTLY, from a stale tmux
#     wrapper shell (e.g. `gmip4_flow_rerun_centraleurope`, started Aug 6-7, several sitting at
#     a trailing `read -r _` prompt with 0% CPU) whose SESSION NAME contains "gmip4" -- matched
#     by the naive grep forever, regardless of whether real computation was still happening
#     inside. vierzack07 in particular had load1=0.01-0.10 and ZERO real idl processes -- the
#     most idle host in the whole cluster -- yet Phase 1 refused to even consider it.
#   - vierzack05 showed "0 gmip4-related processes" (no gmip4-named wrapper there) while
#     actually being the MOST heavily loaded host in the cluster: load1=9.3, 5 concurrent real
#     idl processes at 80-99% CPU each. A false negative in the opposite direction.
# i.e. grepping a tmux session's command line for a name substring is not a reliable proxy for
# real computational load, in either direction -- it neither reliably clears when work
# finishes (stale wrapper shells linger) nor reliably flags when work is present (differently-
# named IDL runs are invisible to it). Replaced with a direct measurement: sum of %CPU across
# actually-running `idl90/bin/bin.linux.x86_64/idl` processes per host (the real compute, not
# the thin perl launcher stub), combined with /proc/loadavg as a secondary corroborating check.
# This also removes the old two-phase (wait-for-ensemble, then wait-for-idle) structure -- the
# calibration campaign only ever uses ONE remote_host for its entire 100-point design matrix
# (see CalibrationConfig.remote_host docstring), so waiting for the WHOLE cluster to clear was
# never actually necessary; finding any ONE genuinely idle host is sufficient and doesn't
# compete with real GMIP4 work still running elsewhere on other hosts.
#
# PRIORITY LOCK: the user separately queued an Antarctic GMIP4 run (in a different session) to
# launch automatically once cluster capacity frees up, and explicitly wants the Bayesian
# calibration campaign prioritized ahead of it (queue Bayesian first; only start Antarctic once
# Bayesian is fully done). Since that other launcher is a SEPARATE, independently-developed
# script this one has no direct control over, this creates BAYESCAL_LOCK the moment it starts
# waiting (not just once IDL actually launches) as a durable, filesystem-visible signal any
# cooperating launcher can check -- released only once the ENTIRE 5-step pipeline finishes (or
# this script is killed/errors -- the EXIT trap covers both), not just the IDL-heavy part.
#
# Usage (run in its own tmux session, matching this project's other long-running jobs):
#   tmux new-session -d -s wait_for_idle_host \
#     "bash scripts/wait_for_idle_host_and_launch.sh <config.yaml>"
#   tmux attach -t wait_for_idle_host    # to watch progress

set -euo pipefail

HOSTS=(vierzack03 vierzack04 vierzack05 vierzack06 vierzack07)
LOAD_THRESHOLD=3.0        # secondary corroborating check -- each host has 24 cores (nproc).
IDL_CPU_THRESHOLD=15.0    # sum of %CPU across real idl bin processes -- one genuinely active
                          # IDL run sits at 80-99% CPU on a single core, so this reliably flags
                          # real work while ignoring dead/stuck processes sitting at ~0% CPU
                          # (confirmed live: vierzack04 had two such stuck processes).
POLL_INTERVAL=300         # 5 min

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:?Usage: wait_for_idle_host_and_launch.sh <config.yaml>}"

LOG_DIR="${GLOGEM_DIR}/logs"
mkdir -p "$LOG_DIR"
WAIT_LOG="${LOG_DIR}/wait_for_idle_host_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$WAIT_LOG") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

LOCK_FILE="${LOG_DIR}/BAYESCAL_CAMPAIGN_ACTIVE.lock"
cat > "$LOCK_FILE" <<EOF
Bayesian calibration campaign is queued/active (config: $CONFIG).
User priority: this campaign must complete BEFORE any new large batch campaign (e.g. the
Antarctic GMIP4 run) starts on this cluster. Other launchers should check for this file's
absence before claiming cluster capacity for new large-scale work.
Started: $(date)
Wait log: $WAIT_LOG
EOF
trap 'rm -f "$LOCK_FILE"; log "Lock released ($LOCK_FILE removed) on exit."' EXIT
log "Created priority lock: $LOCK_FILE"

log "wait_for_idle_host_and_launch.sh started — config=$CONFIG log=$WAIT_LOG"
log "Candidate hosts: ${HOSTS[*]}"
log "Idle test: load1 < ${LOAD_THRESHOLD} AND real-idl-%CPU-sum < ${IDL_CPU_THRESHOLD} (checking every ${POLL_INTERVAL}s)"

# ── pick a genuinely idle host, measured directly rather than by name-matching ─────────────
selected_host=""
while [[ -z "$selected_host" ]]; do
  for h in "${HOSTS[@]}"; do
    load1="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$h" 'cut -d" " -f1 /proc/loadavg' 2>/dev/null || true)"
    if [[ -z "$load1" ]]; then
      log "  $h: unreachable, skipping"
      continue
    fi
    idl_cpu="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$h" \
      "ps -eo pcpu,cmd 2>/dev/null | grep 'bin.linux.x86_64/idl' | grep -v grep | awk '{s+=\$1} END{print s+0}'" \
      2>/dev/null || echo "")"
    [[ -z "$idl_cpu" ]] && idl_cpu=0
    log "  $h: load1=$load1 real-idl-%CPU-sum=$idl_cpu"
    if awk -v l="$load1" -v t="$LOAD_THRESHOLD" -v c="$idl_cpu" -v ct="$IDL_CPU_THRESHOLD" \
        'BEGIN{exit !(l<t && c<ct)}'; then
      log "$h is genuinely idle (load1=$load1 < $LOAD_THRESHOLD, idl-%CPU-sum=$idl_cpu < $IDL_CPU_THRESHOLD) — selecting it."
      selected_host="$h"
      break
    fi
  done
  if [[ -z "$selected_host" ]]; then
    log "No idle host this sweep — sleeping ${POLL_INTERVAL}s."
    sleep "$POLL_INTERVAL"
  fi
done

sed -i "s/^remote_host:.*/remote_host: $selected_host/" "$CONFIG"
log "Patched remote_host: $selected_host into $CONFIG. Launching campaign..."
cd "$GLOGEM_DIR"

# NOT exec'd (unlike the training campaign's own launch pattern elsewhere in this project) --
# deliberately kept as a normal call so the EXIT trap above still fires (releasing
# BAYESCAL_LOCK) once autostart_bayescal_training.sh finishes, whether it succeeds or fails.
bash scripts/autostart_bayescal_training.sh "$CONFIG"
log "Bayesian calibration campaign (all 5 pipeline steps) finished."
