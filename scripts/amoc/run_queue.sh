#!/bin/bash
# run_queue.sh - run every GloGEM config of a folder, N at a time on this host, from a fixed code tree.
#
# usage: run_queue.sh <code tree> <config dir> <log dir> <N parallel>
#
# <code tree> should be an export of one commit (git archive), not a worktree that is edited while
# jobs run: IDL compiles some routines only when they are first called.
# Several hosts can run the same queue at once: a job is claimed by creating <log dir>/<name>.claim
# (mkdir is atomic, also over NFS), and a claimed job is skipped. Claims are kept after the job ends.
# A job counts as done when its log has 'FINISHED region' (<name>.done); otherwise <name>.failed is
# written.
# To restart when no queue runs any more: rm -r <log dir>/*.claim, then rerun; done jobs are skipped,
# failed ones are retried.
# The first N starts are 5 s apart, to spread the reads of the climate files.
set -u
tree=$1; cfgdir=$2; logdir=$3; npar=$4
mkdir -p "$logdir"

run_one() {
  local cfg=$1 name
  name=$(basename "$cfg" .pro)
  [ -e "$logdir/$name.done" ] && return 0
  mkdir "$logdir/$name.claim" 2>/dev/null || return 0
  echo "$(hostname) $(date '+%F %T')" > "$logdir/$name.claim/owner"
  mkdir -p "$logdir/$name"
  rm -f "$logdir/$name.failed"
  (cd "$tree" && echo '.r glogem' | GLOGEM_CONFIG="$cfg" GLOGEM_LOGDIR="$logdir/$name" idl \
      > "$logdir/$name/idl_stdout.log" 2>&1)
  if grep -q 'FINISHED region' "$logdir/$name/idl_stdout.log"; then
    touch "$logdir/$name.done"
  else
    touch "$logdir/$name.failed"
  fi
}
export -f run_one
export tree logdir

i=0
for cfg in "$cfgdir"/*.pro; do
  name=$(basename "$cfg" .pro)
  [ -e "$logdir/$name.done" ] || [ -e "$logdir/$name.claim" ] && continue
  if [ $i -lt "$npar" ]; then i=$((i + 1)); echo "$cfg"; sleep 5; else echo "$cfg"; fi
done | xargs -P "$npar" -I{} bash -c 'run_one "$@"' _ {}

echo "queue finished on $(hostname) $(date '+%F %T'): $(ls "$logdir"/*.done 2>/dev/null | wc -l) done," \
     "$(ls "$logdir"/*.failed 2>/dev/null | wc -l) failed"
