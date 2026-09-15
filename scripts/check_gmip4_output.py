#!/usr/bin/env python3
"""check_gmip4_output.py -- post-run sanity gate for GloGEMflow GMIP4 output.

A clean, error-free GloGEMflow run can still be scientifically wrong: on
2026-09-08 glaciers were found regrowing from a melted-out state to hundreds
of km3 (one to 4486 km3 -- 7x its entire region), driven by two faults in the
flow integration, with no error or warning anywhere in the logs. This script
is the check that would have caught it. Run it on a region before combining
or submitting; it exits non-zero if anything is flagged, so it works as a gate.

The criterion is MAGNITUDE, not "grew from zero". Small remnants regrowing
under overshoot / low-emission scenarios is real physics, and the pure-dh
model does it correctly -- lvantrich's submitted runs show 2,217 such glaciers,
every one staying below 1 km3 and below 5 % of any regional total. The
corruption signature is a glacier reaching absurd absolute volume, or an
implied mean thickness (volume/area) no real glacier has.

Two checks per region:
  1. Per-glacier, from the batch Volume/Area .dat files, for every GCM/SSP:
       peak volume  > VOL_ABS_KM3  AND  peak volume > VOL_REL_X * volume(2020)
       OR  peak mean thickness (vol/area) > THICK_MAX_M
  2. Regional, from the combined canonical *_annual.nc files (if present):
       mass at 2099 > (1 + REGROW_TOL) * mass at 2050  under ssp370/ssp585
     (regional volume rising late-century under high emissions is a runaway
     until proven otherwise).

Usage:
    python3 scripts/check_gmip4_output.py REGION [REGION ...] [--all] [--quiet]

    REGION   lower-case as used in combine_gmip4_output.py, e.g. svalbard,
             arcticcanadan, southasiaeast

Thresholds were set against the 2026-09-08 findings and against what
healthy runs look like (largest legitimate single glacier: an ArcticCanadaN
ice cap at ~1007 km3 and ~330 m mean thickness).
"""

import sys
import glob
import re
import os
import numpy as np

VOL_ABS_KM3 = 50.0     # never legitimately reached by regrowth (< 1 km3 in pure dh)
VOL_REL_X   = 20.0     # ...and far beyond anything a glacier had in 2020
THICK_MAX_M = 2000.0   # runaways show 4-125 km; real ice is a few hundred m
REGROW_TOL  = 0.05     # regional 2099 > 2050 + 5 % under ssp370/585 is a runaway

GLOGEM_BASE = "/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"
FINAL_BASE  = "/scratch_net/vierzack04_fourth/jabeer/GloGEM/r7spec_global_results/flow"

# Kept in sync by hand with combine_gmip4_output.py (which cannot be imported:
# it runs process() at module level).
REGION_DIR = {
    "svalbard": "Svalbard", "iceland": "Iceland", "scandinavia": "Scandinavia",
    "russianarctic": "RussianArctic", "caucasus": "Caucasus",
    "centraleurope": "CentralEurope", "newzealand": "NewZealand",
    "arcticcanadan": "ArcticCanadaN", "arcticcanadas": "ArcticCanadaS",
    "southasiawest": "SouthAsiaWest", "southasiaeast": "SouthAsiaEast",
    "alaska": "Alaska", "westerncanada": "WesternCanada", "southernandes": "SouthernAndes",
}
# on-disk filename prefix (GloGEM's internal region_n codename), where it
# differs from the region key
FILE_PREFIX = {
    "centraleurope": "centraleurope", "arcticcanadan": "arcticcanadaN",
    "arcticcanadas": "arcticcanadaS", "southasiawest": "centralasiaW",
    "southasiaeast": "centralasiaS",
}
BASE_DIR_OVERRIDE = {"centraleurope": "alps_flow"}
BATCH_PREFIX_OVERRIDE = {"centraleurope": "alps"}
RGI_NUM = {
    "svalbard": "07", "iceland": "06", "scandinavia": "08", "russianarctic": "09",
    "caucasus": "12", "centraleurope": "11", "newzealand": "18",
    "arcticcanadan": "03", "arcticcanadas": "04", "southasiawest": "14",
    "southasiaeast": "15", "alaska": "01", "westerncanada": "02", "southernandes": "17",
}
I2020 = 80  # column index for year 2020 (series start 1940)


def read_rows(path):
    """Yield (glacier_id, float array) per row; '*' -> 0, NaN -> 0."""
    with open(path) as fh:
        fh.readline()
        for line in fh:
            q = line.split()
            if len(q) < 2:
                continue
            vals = []
            for t in q[1:]:
                try:
                    v = float(t)
                except ValueError:
                    v = 0.0
                vals.append(0.0 if np.isnan(v) else v)
            yield q[0], np.array(vals)


def check_region_glaciers(region, quiet):
    rdir = REGION_DIR[region]
    pref = FILE_PREFIX.get(region, region)
    base = BASE_DIR_OVERRIDE.get(region, f"{region}_flow")
    bp = BATCH_PREFIX_OVERRIDE.get(region, pref)
    d = f"{GLOGEM_BASE}/{base}_rgi7_gmip4/monthly/{rdir}/files/files_original"
    flagged = []
    vol_files = sorted(glob.glob(f"{d}/*/*/{pref}_Volume_r1_{bp}_batch??.dat"))
    if not vol_files:
        print(f"[{region}] no batch Volume files under {d}")
        return flagged
    for vf in vol_files:
        m = re.search(r"/([^/]+)/(ssp[0-9a-z\-]+)/[^/]+_batch(\d\d)\.dat$", vf)
        if not m:
            continue
        gcm, ssp, batch = m.groups()
        af = vf.replace("_Volume_r1_", "_Area_r1_")
        areas = dict(read_rows(af)) if os.path.exists(af) else {}
        for gid, v in read_rows(vf):
            if len(v) <= I2020:
                continue
            pk = int(np.argmax(v))
            peak = v[pk]
            v20 = v[I2020]
            reason = None
            if peak > VOL_ABS_KM3 and v20 > 0 and peak > VOL_REL_X * v20:
                reason = f"peak {peak:.0f} km3 = {peak/v20:.0f}x its 2020 volume"
            a = areas.get(gid)
            if a is not None and pk < len(a) and a[pk] > 0:
                thick_m = peak / a[pk] * 1000.0   # km3/km2 -> km -> m
                if thick_m > THICK_MAX_M:
                    reason = (reason + "; " if reason else "") + \
                             f"mean thickness {thick_m/1000:.1f} km at peak"
            if reason:
                flagged.append((gcm, ssp, batch, gid, reason))
    return flagged


def check_region_canonical(region, quiet):
    rdir = REGION_DIR[region]
    rgi = RGI_NUM[region]
    flagged = []
    try:
        import netCDF4 as nc
    except ImportError:
        print(f"[{region}] netCDF4 not available -- regional check skipped")
        return flagged
    for p in sorted(glob.glob(f"{FINAL_BASE}/{rdir}/GloGEM_rgi{rgi}_*_annual.nc")):
        if "indiv" in p:
            continue
        m = re.match(rf"GloGEM_rgi{rgi}_(.+)_(ssp[0-9a-z\-]+)_annual\.nc", os.path.basename(p))
        if not m:
            continue
        gcm, ssp = m.groups()
        if ssp not in ("ssp370", "ssp585"):
            continue
        try:
            f = nc.Dataset(p)
            t = f.variables["time"]
            yrs = np.array([x.year for x in nc.num2date(t[:], t.units, t.calendar)])
            mass = f.variables["mass"][:]
            f.close()
        except Exception as e:
            flagged.append((gcm, ssp, "-", "-", f"unreadable canonical file: {e}"))
            continue
        i50 = np.where(yrs == 2050)[0]
        i99 = np.where(yrs == 2099)[0]
        if len(i50) and len(i99) and mass[i99[0]] > (1 + REGROW_TOL) * mass[i50[0]]:
            flagged.append((gcm, ssp, "-", "regional",
                            f"mass 2099 ({mass[i99[0]]/900/1e9:.0f} km3) > 2050 "
                            f"({mass[i50[0]]/900/1e9:.0f} km3) under {ssp}"))
    return flagged


def main(argv):
    quiet = "--quiet" in argv
    regions = [a for a in argv if not a.startswith("--")]
    if "--all" in argv or not regions:
        regions = list(REGION_DIR)
    total = 0
    for region in regions:
        if region not in REGION_DIR:
            print(f"unknown region '{region}'"); continue
        fg = check_region_glaciers(region, quiet)
        fc = check_region_canonical(region, quiet)
        n = len(fg) + len(fc)
        total += n
        status = "OK" if n == 0 else f"FLAGGED ({n})"
        print(f"[{region}] {status}")
        if not quiet:
            for gcm, ssp, batch, gid, why in fg:
                print(f"    glacier {gid} batch{batch} {gcm}/{ssp}: {why}")
            for gcm, ssp, _, _, why in fc:
                print(f"    REGIONAL {gcm}/{ssp}: {why}")
    print(f"\n{total} finding(s) across {len(regions)} region(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
