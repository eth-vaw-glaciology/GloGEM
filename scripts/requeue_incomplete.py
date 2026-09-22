#!/usr/bin/env python3
"""Reconcile the rerun campaign: find batch-jobs that are neither finished, nor running,
nor queued -- and (optionally) put them back in a queue.

A job is lost whenever its session dies without writing a .done marker: a host reboot, a
killed tmux session, a launch that failed at once. The queue entry was already popped, so
without this sweep the work silently never happens.

  python3 scripts/requeue_incomplete.py                 # dry run: just report
  python3 scripts/requeue_incomplete.py --to vierzack04 # append the lost ones to that queue

A job counts as lost only if it is not done, not queued, not running on any host we could
reach, AND its log has been silent for --stale-min minutes. That last test is what makes this
safe to run unattended: logs live on shared /home, so their timestamps are visible even when
the host that owns the session is unreachable. Without it, a momentary ssh failure would
re-queue a job that is still running, and two sessions would write the same output file.
"""
import glob, os, re, subprocess, sys, collections, datetime as dt

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = f"{P}/logs"
HOSTS = ["vierzack03", "vierzack04", "vierzack05", "vierzack06", "iceberg"]
NB = {"caucasus": 12, "svalbard": 8, "centraleurope": 24, "southasiaeast": 12,
      "arcticcanadan": 10, "arcticcanadas": 12, "southasiawest": 20, "scandinavia": 16,
      "newzealand": 16, "alaska": 18, "westerncanada": 12, "southernandes": 18,
      "centralasia": 24, "greenland": 20,
      # subregion regions: one job per subregion, selected by region_id_loop (no batches)
      "antarctic_atlantic": 1, "antarctic_indian": 1, "antarctic_pacific": 1,
      "antarctic_maudwilkes": 1, "antarctic_victoria": 1, "antarctic_peninsula": 1,
      "antarctic_mariebyrd": 1, "lowlatitudes_andes": 1, "lowlatitudes_africa": 1,
      "lowlatitudes_mexico": 1, "lowlatitudes_newguinea": 1,
      "iceland": 4, "northasia_altay": 1}
SSPS = ["ssp126", "ssp370", "ssp585", "ssp534over"]


def entry(reg, ssp, b):
    return (f"scripts/config_flow_rgi7_{reg}_gmip4_{ssp}.pro|{b}|"
            f"rerun_{reg}_{ssp}|logs/done_{reg}_rerun_{ssp}")


def main(argv):
    target = argv[argv.index("--to") + 1] if "--to" in argv else None
    stale_min = int(argv[argv.index("--stale-min") + 1]) if "--stale-min" in argv else 90
    now = dt.datetime.now().timestamp()

    queued = set()
    for f in glob.glob(f"{LOGS}/launch_queue_*.txt"):
        if "superseded" in f or "stopped" in f:
            continue
        for l in open(f):
            l = l.strip()
            if l and not l.startswith("#"):
                # compare on the first 4 fields only: a queue entry may carry a 5th field
                # (estimated hours, used by the SHUTDOWN_AT logic) and must still match.
                queued.add("|".join(l.split("|")[:4]))

    running = set()
    for h in HOSTS:
        try:
            out = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", h,
                                  'for s in $(tmux ls 2>/dev/null | cut -d: -f1 | grep "^rerun_"); do '
                                  'p=$(tmux list-panes -t "$s" -F "#{pane_pid}" 2>/dev/null | head -1); '
                                  '[ -n "$p" ] && pstree -p "$p" 2>/dev/null | grep -q "idl(" && echo "$s"; done'],
                                 capture_output=True, text=True, timeout=40).stdout
        except Exception:
            print(f"  ! {h} unreachable -- treating its work as not running"); out = ""
        for s in out.split():
            m = re.match(r"rerun_(.+)_(ssp[a-z0-9]+)_batch(\d+)$", s)
            if m:
                running.add((m.group(1), m.group(2), m.group(3)))

    def last_log_age_min(reg, ssp, b):
        logs = glob.glob(f"{LOGS}/rerun_{reg}_{ssp}_batch{b}_2026*.log")
        if not logs:
            return None
        return (now - max(os.path.getmtime(f) for f in logs)) / 60

    lost, warm = [], []
    for reg, nb in NB.items():
        for ssp in SSPS:
            for i in range(1, nb + 1):
                b = f"{i:02d}"
                if os.path.exists(f"{LOGS}/done_{reg}_rerun_{ssp}/batch{b}.done"):
                    continue
                if (reg, ssp, b) in running:
                    continue
                if entry(reg, ssp, b) in queued:
                    continue
                age = last_log_age_min(reg, ssp, b)
                if age is not None and age < stale_min:
                    warm.append((reg, ssp, b, age))     # log still being written -> leave alone
                    continue
                lost.append((reg, ssp, b))

    total = sum(nb * 4 for nb in NB.values())
    done = sum(len(glob.glob(f"{LOGS}/done_{r}_rerun_{s}/batch*.done")) for r in NB for s in SSPS)
    print(f"batch-jobs: {total} total | {done} done | {len(running)} running | {len(queued)} queued | "
          f"{len(lost)} LOST | {len(warm)} recently-active (left alone)")
    by = collections.Counter(f"{r}/{s}" for r, s, _ in lost)
    for k, n in sorted(by.items()):
        print(f"    {k}: {n}")
    if lost and target:
        f = f"{LOGS}/launch_queue_{target}.txt"
        with open(f, "a") as fh:
            for r, s, b in lost:
                fh.write(entry(r, s, b) + "\n")
        print(f"\n  re-queued {len(lost)} job(s) onto {target}")
    elif lost:
        print("\n  (dry run -- pass --to <host> to re-queue them)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
