#!/usr/bin/env python3
"""Feed the GMIP4 v2 campaign into the per-host watcher queues.

Phase 1 queues every batch's ERA5 hindcast. A hindcast runs the flow spin-up for every
glacier of its batch and caches it, so phase 2 queues a batch's four SSP runs only once
its hindcast has finished: the SSP runs then read the cache instead of repeating the
spin-ups, and no two jobs write the same cache file.

Run from the repo root in tmux:  python3 scripts/feed_v2_campaign.py
State (what has been queued) is kept in logs/v2_fed.txt, so a restart resumes.
"""
import os, time

HOSTS = {"vierzack04": 22, "vierzack05": 20, "vierzack06": 22, "vierzack07": 22, "iceberg": 4}
# region key, batches; largest first so the longest region starts earliest
REGIONS = [("centralasia", 24), ("alaska", 18), ("southernandes", 18),
           ("westerncanada", 12), ("southasiaeast", 12)]
SSPS = ["ssp126", "ssp585", "ssp370", "ssp534over"]   # longest runs first
STATE = "logs/v2_fed.txt"
POLL = 60


def queue_file(h):
    return f"logs/launch_queue_{h}.txt"


def pending(h):
    try:
        return sum(1 for ln in open(queue_file(h)) if ln.strip() and not ln.lstrip().startswith("#"))
    except FileNotFoundError:
        return 0


def push(entries):
    """append each entry to the host queue with the least pending work per slot"""
    for e in entries:
        h = min(HOSTS, key=lambda k: (pending(k) + 1) / HOSTS[k])
        with open(queue_file(h), "a") as f:
            f.write(e + "\n")


def fed():
    try:
        return set(ln.strip() for ln in open(STATE) if ln.strip())
    except FileNotFoundError:
        return set()


def mark(key):
    with open(STATE, "a") as f:
        f.write(key + "\n")


def entry(r, b, ssp):
    if ssp == "hindcast":
        return f"scripts/config_hindcast_rgi7_{r}_gmip4v2.pro|{b}|v2_{r}_hindcast|logs/done_{r}_rerun_v2_hindcast"
    return f"scripts/config_flow_rgi7_{r}_gmip4v2_{ssp}.pro|{b}|v2_{r}_{ssp}|logs/done_{r}_rerun_v2_{ssp}"


def main():
    os.makedirs("logs", exist_ok=True)
    done = fed()
    # phase 1: interleave regions so each gets hindcasts running from the start
    order = []
    for i in range(max(n for _, n in REGIONS)):
        for r, n in REGIONS:
            if i < n:
                order.append((r, f"{i + 1:02d}"))
    new = [(r, b) for r, b in order if f"{r}|{b}|hindcast" not in done]
    push([entry(r, b, "hindcast") for r, b in new])
    for r, b in new:
        mark(f"{r}|{b}|hindcast")
    print(time.strftime("%F %T"), f"queued {len(new)} hindcasts", flush=True)
    # phase 2
    while True:
        done = fed()
        todo = 0
        for r, b in order:
            if f"{r}|{b}|ssp" in done:
                continue
            todo += 1
            d = f"logs/done_{r}_rerun_v2_hindcast/batch{b}"
            if os.path.exists(d + ".done") or os.path.exists(d + ".failed"):
                push([entry(r, b, s) for s in SSPS])
                mark(f"{r}|{b}|ssp")
                ok = "done" if os.path.exists(d + ".done") else "FAILED -- SSPs will run their own spin-ups"
                print(time.strftime("%F %T"), f"{r} batch{b}: hindcast {ok}; queued 4 SSP runs", flush=True)
        if todo == 0:
            print(time.strftime("%F %T"), "all batches fed -- exiting", flush=True)
            return
        time.sleep(POLL)


if __name__ == "__main__":
    main()
