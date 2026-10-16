#!/bin/bash
# run_queue.sh - run every GloGEM config of a folder, N at a time on this host, from a fixed code tree.
#
# usage: run_queue.sh <code tree> <config dir> <log dir> <N parallel>
#
# <code tree> should be an export of one commit (git archive), not a worktree that is edited while
# jobs run: IDL compiles some routines only when they are first called.
# A config whose <log dir>/<name>.done exists is skipped, so the queue can be restarted. A job counts
# as done when its log has 'FINISHED region'; otherwise <name>.failed is written.
# The first N starts are 5 s apart, to spread the reads of the climate files.
set -u
tree=$1; cfgdir=$2; logdir=$3; npar=$4
mkdir -p "$logdir"

run_one() {
  local cfg=$1 name
  name=$(basename "$cfg" .pro)
  [ -e "$logdir/$name.done" ] && return 0
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
  [ -e "$logdir/$(basename "$cfg" .pro).done" ] && continue
  if [ $i -lt "$npar" ]; then i=$((i + 1)); echo "$cfg"; sleep 5; else echo "$cfg"; fi
done | xargs -P "$npar" -I{} bash -c 'run_one "$@"' _ {}

echo "queue finished $(date '+%F %T'): $(ls "$logdir"/*.done 2>/dev/null | wc -l) done, $(ls "$logdir"/*.failed 2>/dev/null | wc -l) failed"
