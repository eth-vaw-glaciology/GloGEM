#!/bin/bash
# watch_and_launch_subregions.sh — runs as its own detached tmux session
# directly on the cluster (independent of any Claude Code session or the
# user's own computer), polls vierzack03/04/06/07 for a free host, and
# launches run_gmip4_subregions.sh (LowLatitudes + Antarctic, 11
# subregions) the moment one frees up. Exits after launching (or after
# confirming it's already running) -- this is a one-shot "launch when
# ready" watcher, not an ongoing daemon.
#
# Launch (run this ON the cluster, e.g. from wherever you already have a
# shell open on vierzack04 -- do NOT run locally, it needs to keep going
# after this shell/session ends):
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -d -s gmip4_watcher "bash scripts/watch_and_launch_subregions.sh"
#
# Check on it later from anywhere:
#   ssh vierzack04 "tmux capture-pane -p -t gmip4_watcher -S -30"

set -uo pipefail   # deliberately NOT -e: a single failed SSH check must not kill an
                    # unattended, possibly multi-day watcher -- every check below
                    # tolerates failure and just retries next loop.

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$GLOGEM_DIR/logs"
LOGFILE="$LOG_DIR/watch_and_launch_subregions_$(date +%Y%m%d_%H%M%S).log"
POLL_SECONDS=120

mkdir -p "$LOG_DIR"
exec > >(tee "$LOGFILE") 2>&1

# host:tmux_session pairs to watch
CANDIDATES=(
    "vierzack03:gmip4_retry_svalbard"
    "vierzack04:gmip4_iceland_reflow"
    "vierzack06:gmip4_retry_russianarctic"
    "vierzack07:gmip4_retry_scandinavia"
)

echo "======================================================"
echo "  Subregion launch watcher started: $(date)"
echo "  Polling every ${POLL_SECONDS}s for a free host among:"
for c in "${CANDIDATES[@]}"; do echo "    ${c%%:*} (session ${c##*:})"; done
echo "======================================================"

# Returns via echo: "free", "busy", or "unreachable"
check_host() {
    local host="$1" session="$2"
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" "tmux has-session -t '$session'" 2>/dev/null; then
        echo "busy"
        return
    fi
    # has-session failed -- could be "session genuinely gone" or "ssh/host unreachable".
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" "true" 2>/dev/null; then
        echo "free"
    else
        echo "unreachable"
    fi
}

while true; do
    # Someone (manually, or a previous instance of this watcher) may have
    # already launched it -- if so, our job is done.
    if ssh -o ConnectTimeout=10 -o BatchMode=yes vierzack04 "tmux has-session -t gmip4_subregions" 2>/dev/null; then
        echo "$(date +%H:%M:%S)  gmip4_subregions is already running (launched by someone else) -- watcher exiting."
        exit 0
    fi

    free_host=""
    status_line="$(date +%H:%M:%S) "
    for c in "${CANDIDATES[@]}"; do
        host="${c%%:*}"; session="${c##*:}"
        status="$(check_host "$host" "$session")"
        status_line+="  ${host}=${status}"
        if [ "$status" = "free" ] && [ -z "$free_host" ]; then
            free_host="$host"
        fi
    done
    echo "$status_line"

    if [ -n "$free_host" ]; then
        echo ""
        echo "  >>> $free_host is free -- launching run_gmip4_subregions.sh there. $(date)"
        if ssh -o ConnectTimeout=10 -o BatchMode=yes "$free_host" \
            "cd ~/projects/glogemflow_development/GloGEM && tmux new-session -d -s gmip4_subregions 'bash scripts/run_gmip4_subregions.sh'"; then
            sleep 15
            echo "  Launch command sent. Early pane output:"
            ssh -o ConnectTimeout=10 -o BatchMode=yes "$free_host" "tmux capture-pane -p -t gmip4_subregions -S -15" 2>&1
            echo ""
            echo "======================================================"
            echo "  Watcher done -- gmip4_subregions launched on $free_host: $(date)"
            echo "======================================================"
            exit 0
        else
            echo "  !!! Launch command failed (ssh error) -- will retry next poll."
        fi
    fi

    sleep "$POLL_SECONDS"
done
