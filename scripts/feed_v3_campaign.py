#!/usr/bin/env python3
"""Feed the GMIP4 v3 campaign (NorthAsia, LowLatitudes, Antarctic, Greenland, and the reruns of
Alaska, SouthernAndes, RussianArctic) into the per-host watcher queues of this worktree.

Same scheme as feed_v2_campaign.py: every batch's ERA5 hindcast first; a batch's ssp126
once its hindcast has ended; its other three SSPs once ssp126 has finished its first GCM
(its projection spin-ups are then cached, so the three read them instead of redoing them).

NorthAsia, LowLatitudes and Antarctic run one config per climate subregion, each accepting only
its own batches; the other regions run one config each.

Run from the worktree root in tmux, with the regions to feed:
    python3 scripts/feed_v3_campaign.py northasia lowlatitudes
    python3 scripts/feed_v3_campaign.py antarctic greenland      (later, or in a 2nd feeder)
    python3 scripts/feed_v3_campaign.py alaska southernandes russianarctic
What has been queued is kept in logs/v3_fed.txt, so a restart resumes. A region can be
fed by one feeder at a time (lock file logs/feed_v3_<region>.lock).
--check only runs the pre-flight checks and prints the queue entries, queueing nothing.

Once everything is fed, the feeder waits for every job to end and then reports each batch
without its 5 .done markers: a queue line can be lost when the feeder appends while a watcher
rewrites that queue file. A fed job that is in no queue, never started and has no marker is
reported as LOST as soon as it is seen twice in a row, with the line to re-queue.
--verify only prints that completeness report for the given regions (exit code 1 if incomplete).
"""
import fcntl, glob, os, re, sys, time

HOSTS = {"vierzack04": 22, "vierzack05": 20, "vierzack06": 22, "vierzack07": 22, "iceberg": 4}
FIRST = "ssp126"                              # builds the batch's projection spin-up cache
REST = ["ssp585", "ssp370", "ssp534over"]      # longest runs first
STATE = "logs/v3_fed.txt"
POLL = 60
SSPS = ["hindcast", FIRST] + REST
LOST_POLLS = 2      # a job seen this many polls in a row as neither queued, started nor ended is lost
STALE_H = 6         # a started job whose logs have not changed for this long is counted as dead
CATCHMENTS = "/itet-stor/jabeer/glogem/data/catchments"
RGI = {"northasia": "10", "lowlatitudes": "16", "antarctic": "19", "greenland": "05",
       "alaska": "01", "southernandes": "17", "russianarctic": "09"}

# region: [(config key, batch, area km2)] from _notes/heldregions/batch_map.tsv; alaska and
# southernandes: the v2 batches, russianarctic: the batches of the submitted v1 run (RGI7 areas)
BATCHES = {
    "northasia": [("northasia_altay", "01", 334.4), ("northasia_altay", "02", 314.1),
                  ("northasia_altay", "03", 308.2), ("northasia_altay", "04", 300.3),
                  ("northasia_east", "05", 343.6), ("northasia_east", "06", 339.2),
                  ("northasia_east", "07", 323.9), ("northasia_east", "08", 314.5),
                  ("northasia_north", "09", 58.4)],
    "lowlatitudes": [("lowlatitudes_andes", "01", 582.8), ("lowlatitudes_andes", "02", 579.6),
                     ("lowlatitudes_andes", "03", 575.6), ("lowlatitudes_andes", "04", 571.1),
                     ("lowlatitudes_africa", "05", 5.2), ("lowlatitudes_mexico", "06", 1.6),
                     ("lowlatitudes_newguinea", "07", 2.5)],
    "antarctic": [("antarctic_atlantic", "01", 3308.1), ("antarctic_indian", "02", 889.2),
                  ("antarctic_pacific", "03", 149.0), ("antarctic_maudwilkes", "04", 11809.6),
                  ("antarctic_victoria", "05", 4084.2), ("antarctic_peninsula", "06", 29525.1),
                  ("antarctic_peninsula", "07", 27815.8), ("antarctic_peninsula", "08", 26243.5),
                  ("antarctic_mariebyrd", "09", 33215.9)],
    "greenland": [("greenland", f"{i:02d}", a) for i, a in enumerate(
        [5737.3, 5424.1, 5218.5, 5297.3, 5114.5, 5073.4, 5115.8, 4996.7, 4973.6, 4853.9,
         4827.9, 4854.6, 4779.3, 4759.4, 4715.5, 4713.4, 4652.9, 4634.3, 4618.2, 4580.3], 1)],
    "alaska": [("alaska", f"{i:02d}", a) for i, a in enumerate(
        [7226.6, 6873.0, 6662.2, 4975.4, 4808.8, 4757.1, 4707.6, 4617.1, 4559.0, 4431.7,
         4362.3, 4317.6, 4269.2, 4131.5, 4081.1, 4047.2, 3945.4, 3908.1], 1)],
    "southernandes": [("southernandes", f"{i:02d}", a) for i, a in enumerate(
        [2561.3, 2179.0, 2065.2, 2035.8, 2016.9, 1899.4, 1771.9, 1742.0, 1650.1, 1630.9,
         1600.8, 1585.3, 1456.2, 1441.4, 1403.8, 1394.9, 1360.3, 1324.5], 1)],
    "russianarctic": [("russianarctic", f"{i:02d}", a) for i, a in enumerate(
        [9314.2, 9018.5, 8624.1, 8430.8, 8233.1, 8039.8], 1)],
}


def cfg(key, ssp):
    if ssp == "hindcast":
        return f"scripts/config_hindcast_rgi7_{key}_gmip4v3.pro"
    return f"scripts/config_flow_rgi7_{key}_gmip4v3_{ssp}.pro"


def done_dir(key, ssp):
    # "_rerun_" keeps the watcher's failed-launch circuit breaker (logs/done_*_rerun_*/) working
    return f"logs/done_{key}_rerun_v3_{ssp}"


def entry(key, b, ssp):
    return f"{cfg(key, ssp)}|{b}|v3_{key}_{ssp}|{done_dir(key, ssp)}"


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


def dirres(path):
    m = re.search(r"^dirres\s*=\s*'([^']+)'", open(path).read(), re.M)
    return m.group(1) if m else None


def preflight(regions, done):
    """configs, batch lists, catchment files and staged calibration exist; no stale spin-up cache"""
    errors = []
    for r in regions:
        started = any(s.startswith(f"{k}|") for k, _, _ in BATCHES[r] for s in done)
        for key in sorted({k for k, _, _ in BATCHES[r]}):
            for ssp in ["hindcast", FIRST] + REST:
                if not os.path.exists(cfg(key, ssp)):
                    errors.append(f"missing {cfg(key, ssp)}")
            text = open(cfg(key, FIRST)).read() if os.path.exists(cfg(key, FIRST)) else ""
            allowed = re.search(r"total\(\[([^\]]*)\] eq _batch\)", text)
            for k, b, _ in BATCHES[r]:
                if k == key and allowed and f"'{b}'" not in allowed.group(1):
                    errors.append(f"{cfg(key, FIRST)} does not accept batch {b}")
        for _, b, _ in BATCHES[r]:
            c = f"{CATCHMENTS}/RGI{RGI[r]}_{r}_batch{b}.dat"
            if not os.path.exists(c):
                errors.append(f"missing catchment {c}")
        d = dirres(cfg(BATCHES[r][0][0], "hindcast"))
        if d is None:
            errors.append(f"no dirres in {cfg(BATCHES[r][0][0], 'hindcast')}")
            continue
        if not glob.glob(f"{d}monthly/*/calibration/calibrate_m1_cID9_*_final_era5.dat"):
            errors.append(f"no staged calibration in {d}monthly/*/calibration/")
        for p in glob.glob(f"{d}monthly/*/calibration/calibrate_m1_cID9_*_final_era5_*.dat"):
            errors.append(f"{p} would override the staged calibration for its catchment -- remove it")
        cache = glob.glob(f"{d}spinup_cache/*")
        if cache and not started:
            errors.append(f"{r}: {len(cache)} files in {d}spinup_cache/ before the first job -- clear it")
    return errors


def lock(regions):
    """keep only the regions no other feeder is feeding"""
    mine = []
    for r in regions:
        fh = open(f"logs/feed_v3_{r}.lock", "w")
        try:
            fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            print(time.strftime("%F %T"), f"{r}: another feeder holds logs/feed_v3_{r}.lock -- skipped", flush=True)
            continue
        lock.handles.append(fh)
        mine.append(r)
    return mine


lock.handles = []


def first_gcm_done(key, b):
    """the batch's ssp126 run has finished one GCM (so all its spin-ups are cached), or ended"""
    d = f"{done_dir(key, FIRST)}/batch{b}"
    if os.path.exists(d + ".done") or os.path.exists(d + ".failed"):
        return True
    for p in glob.glob(f"logs/v3_{key}_{FIRST}_batch{b}_*.log"):
        with open(p, errors="ignore") as f:
            if "FINISHED region" in f.read():
                return True
    return False


def queued():
    """queue entries of every host, deferred ones included (first four fields)"""
    out = set()
    for p in glob.glob("logs/launch_queue_*.txt*"):
        try:
            for ln in open(p):
                ln = ln.strip()
                if ln and not ln.startswith("#"):
                    out.add("|".join(ln.split("|")[:4]))
        except OSError:
            pass
    return out


def last_change(logs):
    """newest change of a job's batch logs and of the journal each one names"""
    t = 0.0
    for p in logs:
        try:
            t = max(t, os.path.getmtime(p))
            for ln in open(p, errors="ignore"):
                if ln.startswith("Log file:"):
                    t = max(t, os.path.getmtime(ln.split(":", 1)[1].strip()))
        except OSError:
            pass
    return t


def job_status(key, b, ssp, fed_now, queue):
    """done | failed | queued | running | stalled | lost | not fed"""
    if f"{key}|{b}|{ssp if ssp in ('hindcast', FIRST) else 'rest'}" not in fed_now:
        return "not fed"
    d = f"{done_dir(key, ssp)}/batch{b}"
    if os.path.exists(d + ".done"):
        return "done"
    if os.path.exists(d + ".failed"):
        return "failed"
    if entry(key, b, ssp) in queue:
        return "queued"
    logs = glob.glob(f"logs/v3_{key}_{ssp}_batch{b}_*.log")
    if logs:
        return "running" if time.time() - last_change(logs) < STALE_H * 3600 else "stalled"
    return "lost"


def completeness(regions):
    """{(key, batch, ssp): status} for every job of the regions"""
    fed_now, queue = fed(), queued()
    return {(k, b, s): job_status(k, b, s, fed_now, queue) for r in regions for k, b, _ in BATCHES[r] for s in SSPS}


def report(regions, st):
    """print every batch without its 5 .done markers; True if all are there"""
    n = {}
    for v in st.values():
        n[v] = n.get(v, 0) + 1
    nb = sum(len(BATCHES[r]) for r in regions)
    print(time.strftime("%F %T"), f"completeness ({', '.join(regions)}): {nb} batches, {len(st)} jobs: " +
          ", ".join(f"{c} {v}" for v, c in sorted(n.items())), flush=True)
    for r in regions:
        for k, b, _ in BATCHES[r]:
            bad = [(s, st[(k, b, s)]) for s in SSPS if st[(k, b, s)] != "done"]
            if bad:
                print(f"  {k} batch{b}: " + ", ".join(f"{s} {v}" for s, v in bad), flush=True)
                for s, v in bad:
                    if v == "lost":
                        print(f"    re-queue: {entry(k, b, s)}", flush=True)
    ok = all(v == "done" for v in st.values())
    if ok:
        print(f"  every batch has its {len(SSPS)} .done markers", flush=True)
    return ok


def wait_and_report(regions):
    """after the last feed: flag lost jobs as they appear, report once every job has ended"""
    seen, told = {}, set()
    while True:
        st = completeness(regions)
        for j, v in st.items():
            seen[j] = seen.get(j, 0) + 1 if v == "lost" else 0
            if seen[j] >= LOST_POLLS and j not in told:
                print(time.strftime("%F %T"), f"LOST: {j[0]} batch{j[1]} {j[2]} was fed but is in no queue, never "
                      f"started and has no marker -- re-queue: {entry(*j)}", flush=True)
                told.add(j)
        busy = [j for j, v in st.items() if v in ("queued", "running", "not fed") or (v == "lost" and seen[j] < LOST_POLLS)]
        if not busy:
            return report(regions, st)
        time.sleep(POLL)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    bad = [a for a in args if a not in BATCHES]
    if not args or bad:
        sys.exit(f"usage: feed_v3_campaign.py [--check | --verify] REGION... (from {', '.join(BATCHES)}); unknown: {bad}")
    regions = list(dict.fromkeys(args))
    if "--verify" in sys.argv:
        sys.exit(0 if report(regions, completeness(regions)) else 1)
    os.makedirs("logs", exist_ok=True)
    done = fed()
    errors = preflight(regions, done)
    for e in errors:
        print("PRE-FLIGHT:", e, flush=True)
    if errors:
        sys.exit(1)
    # interleave regions, largest batch first within each, so every region starts early
    per = {r: sorted(BATCHES[r], key=lambda t: -t[2]) for r in regions}
    order = []
    for i in range(max(len(v) for v in per.values())):
        for r in regions:
            if i < len(per[r]):
                order.append(per[r][i][:2])
    if check:
        for k, b in order:
            print(entry(k, b, "hindcast"))
        print(f"pre-flight ok: {len(order)} batches, {5 * len(order)} jobs")
        return
    regions = lock(regions)
    if not regions:
        print(time.strftime("%F %T"), "no region left to feed -- exiting", flush=True)
        return
    order = [(k, b) for k, b in order if any(k == kk for r in regions for kk, _, _ in BATCHES[r])]
    # phase 1
    new = [(k, b) for k, b in order if f"{k}|{b}|hindcast" not in done]
    push([entry(k, b, "hindcast") for k, b in new])
    for k, b in new:
        mark(f"{k}|{b}|hindcast")
    print(time.strftime("%F %T"), f"queued {len(new)} hindcasts ({', '.join(regions)})", flush=True)
    # phase 2
    while True:
        done = fed()
        todo = 0
        for k, b in order:
            if f"{k}|{b}|rest" in done:
                continue
            todo += 1
            if f"{k}|{b}|{FIRST}" not in done:
                d = f"{done_dir(k, 'hindcast')}/batch{b}"
                if os.path.exists(d + ".done") or os.path.exists(d + ".failed"):
                    push([entry(k, b, FIRST)])
                    mark(f"{k}|{b}|{FIRST}")
                    ok = "done" if os.path.exists(d + ".done") else "FAILED"
                    print(time.strftime("%F %T"), f"{k} batch{b}: hindcast {ok}; queued {FIRST}", flush=True)
                continue
            if first_gcm_done(k, b):
                push([entry(k, b, s) for s in REST])
                mark(f"{k}|{b}|rest")
                print(time.strftime("%F %T"), f"{k} batch{b}: {FIRST} past its first GCM; queued {', '.join(REST)}", flush=True)
        if todo == 0:
            print(time.strftime("%F %T"), "all batches fed -- waiting for every job to end, then checking the .done markers", flush=True)
            wait_and_report(regions)
            return
        time.sleep(POLL)


if __name__ == "__main__":
    main()
