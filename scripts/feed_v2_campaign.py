#!/usr/bin/env python3
"""Feed the GMIP4 v2 campaign into the per-host watcher queues.

Phase 1 queues every batch's ERA5 hindcast. Phase 2 queues a batch's ssp126 run once its
hindcast has finished, and its other three SSP runs once ssp126 has finished its first GCM:
by then every flow spin-up of the batch is in the cache (projection spin-ups; a hindcast
spins up one year earlier and caches under its own key), so the three read it instead of
repeating the spin-ups and no two jobs write the same cache file.

Run from the repo root in tmux:  python3 scripts/feed_v2_campaign.py
State (what has been queued) is kept in logs/v2_fed.txt, so a restart resumes.
"""
import glob, os, time

HOSTS = {"vierzack04": 22, "vierzack05": 20, "vierzack06": 22, "vierzack07": 22, "iceberg": 4}
# region key, batches; largest first so the longest region starts earliest
REGIONS = [("centralasia", 24), ("alaska", 18), ("southernandes", 18),
           ("westerncanada", 12), ("southasiaeast", 12)]
FIRST = "ssp126"                              # builds the batch's projection spin-up cache
REST = ["ssp585", "ssp370", "ssp534over"]      # longest runs first
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
            if f"{r}|{b}|rest" in done:
                continue
            todo += 1
            if f"{r}|{b}|{FIRST}" not in done:
                d = f"logs/done_{r}_rerun_v2_hindcast/batch{b}"
                if os.path.exists(d + ".done") or os.path.exists(d + ".failed"):
                    push([entry(r, b, FIRST)])
                    mark(f"{r}|{b}|{FIRST}")
                    ok = "done" if os.path.exists(d + ".done") else "FAILED"
                    print(time.strftime("%F %T"), f"{r} batch{b}: hindcast {ok}; queued {FIRST}", flush=True)
                continue
            if first_gcm_done(r, b):
                push([entry(r, b, s) for s in REST])
                mark(f"{r}|{b}|rest")
                print(time.strftime("%F %T"), f"{r} batch{b}: {FIRST} past its first GCM; queued {', '.join(REST)}", flush=True)
        if todo == 0:
            print(time.strftime("%F %T"), "all batches fed -- exiting", flush=True)
            return
        time.sleep(POLL)


def first_gcm_done(r, b):
    """the batch's ssp126 run has finished one GCM (so all its spin-ups are cached), or ended"""
    d = f"logs/done_{r}_rerun_v2_{FIRST}/batch{b}"
    if os.path.exists(d + ".done") or os.path.exists(d + ".failed"):
        return True
    for p in glob.glob(f"logs/v2_{r}_{FIRST}_batch{b}_*.log"):
        with open(p, errors="ignore") as f:
            if "FINISHED region" in f.read():
                return True
    return False

if __name__ == "__main__":
    main()
