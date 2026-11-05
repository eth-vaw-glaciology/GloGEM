"""Feed the GMIP4 v4 rerun (14 regions, worktree _wt_v4) into the per-host watcher queues.

Same scheme as feed_v3_campaign.py: every batch's ERA5 hindcast first; a batch's ssp126
once its hindcast has ended; its other three SSPs once ssp126 has finished its first GCM
(its projection spin-ups are then cached, so the three read them instead of redoing them).
Only vierzack04 and vierzack06, at most 16 jobs each (cluster split with the ice-temperature
sessions, 2026-10-27).

LowLatitudes runs one config per climate subregion, each accepting only its own batches;
the other regions run one config each.

Run from the worktree root in tmux, with the regions to feed (or "all"):
    python3 scripts/gmip4/feed_v4_campaign.py all
What has been queued is kept in logs/v4_fed.txt, so a restart resumes. A region can be
fed by one feeder at a time (lock file logs/feed_v4_<region>.lock).
--check only runs the pre-flight checks and prints the queue entries, queueing nothing.
--verify only prints the completeness report for the given regions (exit code 1 if incomplete).
"""
import fcntl, glob, os, re, sys, time

HOSTS = {"vierzack04": 16, "vierzack06": 16}
FIRST = "ssp126"                              # builds the batch's projection spin-up cache
REST = ["ssp585", "ssp370", "ssp534over"]      # longest runs first
STATE = "logs/v4_fed.txt"
POLL = 60
SSPS = ["hindcast", FIRST] + REST
LOST_POLLS = 2      # a job seen this many polls in a row as neither queued, started nor ended is lost
STALE_H = 6         # a started job whose logs have not changed for this long is counted as dead
CATCHMENTS = "/itet-stor/jabeer/glogem/data/catchments"
RGI = {"westerncanada": "02", "arcticcanadan": "03", "arcticcanadas": "04", "iceland": "06", "svalbard": "07",
       "scandinavia": "08", "russianarctic": "09", "centraleurope": "11", "caucasus": "12", "centralasia": "13",
       "southasiawest": "14", "southasiaeast": "15", "lowlatitudes": "16", "newzealand": "18"}
# catchment file prefix where it is not the region key (RGI<NN>_<prefix>_batch<BB>.dat)
PREFIX = {"arcticcanadan": "arcticcanadaN", "arcticcanadas": "arcticcanadaS", "centraleurope": "alps",
          "centralasia": "centralasiaN", "southasiawest": "centralasiaW", "southasiaeast": "centralasiaS"}

# region: [(config key, batch, area km2)]; areas from the staged calibration files (ordering only)
BATCHES = {
    'iceland': [('iceland', '01', 3514.1), ('iceland', '02', 2860.1), ('iceland', '03', 2374.9), ('iceland', '04', 2304.7)],
    'svalbard': [('svalbard', '01', 4916.8), ('svalbard', '02', 4694.6), ('svalbard', '03', 4431.2), ('svalbard', '04', 4226.9), ('svalbard', '05', 3992.2), ('svalbard', '06', 3906.9), ('svalbard', '07', 3822.3), ('svalbard', '08', 3793.4)],
    'russianarctic': [('russianarctic', '01', 9280.5), ('russianarctic', '02', 8956.5), ('russianarctic', '03', 8575.9), ('russianarctic', '04', 8350.9), ('russianarctic', '05', 8166.3), ('russianarctic', '06', 7993.7)],
    'newzealand': [('newzealand', '01', 125.8), ('newzealand', '02', 72.6), ('newzealand', '03', 72.9), ('newzealand', '04', 66.8), ('newzealand', '05', 52.8), ('newzealand', '06', 50.8), ('newzealand', '07', 49.8), ('newzealand', '08', 46.5), ('newzealand', '09', 45.4), ('newzealand', '10', 46.6), ('newzealand', '11', 44.3), ('newzealand', '12', 44.3), ('newzealand', '13', 42.4), ('newzealand', '14', 42.3), ('newzealand', '15', 40.8), ('newzealand', '16', 42.5)],
    'scandinavia': [('scandinavia', '01', 221.4), ('scandinavia', '02', 211.1), ('scandinavia', '03', 205.1), ('scandinavia', '04', 202.0), ('scandinavia', '05', 195.5), ('scandinavia', '06', 181.7), ('scandinavia', '07', 179.8), ('scandinavia', '08', 177.5), ('scandinavia', '09', 175.7), ('scandinavia', '10', 175.0), ('scandinavia', '11', 173.3), ('scandinavia', '12', 172.3), ('scandinavia', '13', 171.0), ('scandinavia', '14', 169.9), ('scandinavia', '15', 168.6), ('scandinavia', '16', 166.4)],
    'centraleurope': [('centraleurope', '01', 160.3), ('centraleurope', '02', 136.0), ('centraleurope', '03', 110.6), ('centraleurope', '04', 107.7), ('centraleurope', '05', 91.3), ('centraleurope', '06', 86.9), ('centraleurope', '07', 93.2), ('centraleurope', '08', 79.9), ('centraleurope', '09', 83.8), ('centraleurope', '10', 91.8), ('centraleurope', '11', 82.7), ('centraleurope', '12', 84.5), ('centraleurope', '13', 80.0), ('centraleurope', '14', 80.1), ('centraleurope', '15', 84.8), ('centraleurope', '16', 68.7), ('centraleurope', '17', 81.4), ('centraleurope', '18', 73.8), ('centraleurope', '19', 73.6), ('centraleurope', '20', 79.5), ('centraleurope', '21', 73.1), ('centraleurope', '22', 80.7), ('centraleurope', '23', 63.8), ('centraleurope', '24', 74.2)],
    'caucasus': [('caucasus', '01', 140.3), ('caucasus', '02', 133.8), ('caucasus', '03', 131.0), ('caucasus', '04', 126.7), ('caucasus', '05', 120.1), ('caucasus', '06', 115.4), ('caucasus', '07', 114.8), ('caucasus', '08', 107.3), ('caucasus', '09', 106.0), ('caucasus', '10', 105.0), ('caucasus', '11', 104.3), ('caucasus', '12', 102.3)],
    'lowlatitudes': [('lowlatitudes_andes', '01', 485.3), ('lowlatitudes_andes', '02', 481.4), ('lowlatitudes_andes', '03', 480.5), ('lowlatitudes_andes', '04', 473.9), ('lowlatitudes_africa', '05', 4.4), ('lowlatitudes_mexico', '06', 1.6), ('lowlatitudes_newguinea', '07', 2.1)],
    'westerncanada': [('westerncanada', '01', 1589.6), ('westerncanada', '02', 1265.8), ('westerncanada', '03', 1243.4), ('westerncanada', '04', 1232.2), ('westerncanada', '05', 1178.9), ('westerncanada', '06', 1166.2), ('westerncanada', '07', 1160.2), ('westerncanada', '08', 1152.6), ('westerncanada', '09', 1140.9), ('westerncanada', '10', 1134.9), ('westerncanada', '11', 1131.0), ('westerncanada', '12', 1122.5)],
    'arcticcanadan': [('arcticcanadan', '01', 12306.7), ('arcticcanadan', '02', 11593.5), ('arcticcanadan', '03', 10917.7), ('arcticcanadan', '04', 10585.6), ('arcticcanadan', '05', 10392.5), ('arcticcanadan', '06', 10216.1), ('arcticcanadan', '07', 9896.7), ('arcticcanadan', '08', 9861.5), ('arcticcanadan', '09', 9719.8), ('arcticcanadan', '10', 9572.2)],
    'arcticcanadas': [('arcticcanadas', '01', 4043.2), ('arcticcanadas', '02', 3811.2), ('arcticcanadas', '03', 3756.4), ('arcticcanadas', '04', 3637.4), ('arcticcanadas', '05', 3552.6), ('arcticcanadas', '06', 3387.8), ('arcticcanadas', '07', 3264.5), ('arcticcanadas', '08', 3190.9), ('arcticcanadas', '09', 3078.5), ('arcticcanadas', '10', 3028.2), ('arcticcanadas', '11', 2903.6), ('arcticcanadas', '12', 2852.4)],
    'southasiaeast': [('southasiaeast', '01', 1446.4), ('southasiaeast', '02', 1415.4), ('southasiaeast', '03', 1368.4), ('southasiaeast', '04', 1351.1), ('southasiaeast', '05', 1340.8), ('southasiaeast', '06', 1323.2), ('southasiaeast', '07', 1317.3), ('southasiaeast', '08', 1305.8), ('southasiaeast', '09', 1303.0), ('southasiaeast', '10', 1301.1), ('southasiaeast', '11', 1297.1), ('southasiaeast', '12', 1286.7)],
    'southasiawest': [('southasiawest', '01', 2487.5), ('southasiawest', '02', 2185.1), ('southasiawest', '03', 1918.8), ('southasiawest', '04', 1830.0), ('southasiawest', '05', 1744.0), ('southasiawest', '06', 1684.7), ('southasiawest', '07', 1648.7), ('southasiawest', '08', 1627.8), ('southasiawest', '09', 1614.1), ('southasiawest', '10', 1599.1), ('southasiawest', '11', 1533.7), ('southasiawest', '12', 1523.8), ('southasiawest', '13', 1511.3), ('southasiawest', '14', 1503.3), ('southasiawest', '15', 1493.4), ('southasiawest', '16', 1472.6), ('southasiawest', '17', 1449.4), ('southasiawest', '18', 1438.0), ('southasiawest', '19', 1411.5), ('southasiawest', '20', 1406.3)],
    'centralasia': [('centralasia', '01', 2640.1), ('centralasia', '02', 2432.2), ('centralasia', '03', 2217.9), ('centralasia', '04', 2185.8), ('centralasia', '05', 2155.9), ('centralasia', '06', 2151.6), ('centralasia', '07', 2120.6), ('centralasia', '08', 2098.2), ('centralasia', '09', 2057.1), ('centralasia', '10', 2071.9), ('centralasia', '11', 2069.5), ('centralasia', '12', 2064.1), ('centralasia', '13', 2052.3), ('centralasia', '14', 2047.2), ('centralasia', '15', 2038.8), ('centralasia', '16', 2025.5), ('centralasia', '17', 2018.5), ('centralasia', '18', 2005.6), ('centralasia', '19', 2000.6), ('centralasia', '20', 1992.1), ('centralasia', '21', 1984.3), ('centralasia', '22', 1978.3), ('centralasia', '23', 1976.6), ('centralasia', '24', 1967.0)],
}


def cfg(key, ssp):
    if ssp == "hindcast":
        return f"scripts/gmip4/config_hindcast_rgi7_{key}_gmip4v4.pro"
    return f"scripts/gmip4/config_flow_rgi7_{key}_gmip4v4_{ssp}.pro"


def done_dir(key, ssp):
    # "_rerun_" keeps the watcher's failed-launch circuit breaker (logs/done_*_rerun_*/) working
    return f"logs/done_{key}_rerun_v4_{ssp}"


def entry(key, b, ssp):
    return f"{cfg(key, ssp)}|{b}|v4_{key}_{ssp}|{done_dir(key, ssp)}"


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
            c = f"{CATCHMENTS}/RGI{RGI[r]}_{PREFIX.get(r, r)}_batch{b}.dat"
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
        fh = open(f"logs/feed_v4_{r}.lock", "w")
        try:
            fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            print(time.strftime("%F %T"), f"{r}: another feeder holds logs/feed_v4_{r}.lock -- skipped", flush=True)
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
    for p in glob.glob(f"logs/v4_{key}_{FIRST}_batch{b}_*.log"):
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
    logs = glob.glob(f"logs/v4_{key}_{ssp}_batch{b}_*.log")
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
    bad = [a for a in args if a not in BATCHES and a != "all"]
    if not args or bad:
        sys.exit(f"usage: feed_v4_campaign.py [--check | --verify] REGION... (from {', '.join(BATCHES)}); unknown: {bad}")
    regions = list(BATCHES) if args == ["all"] else list(dict.fromkeys(args))
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
