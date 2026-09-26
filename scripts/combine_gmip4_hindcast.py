#!/usr/bin/env python3
"""combine_gmip4_hindcast.py -- assemble the GlacierMIP4 ERA5 hindcast netCDFs.

The hindcast is parallelised into the same per-region batches as the
projections, writing PAST/PAST_netcdf/GloGEM_rgi{XX}_{batch}_ERA5_{annual,
monthly}.nc. GMIP4 wants one regional file per region, so this sums the
batches the way combine_gmip4_output.py does for projections and writes
GloGEM_rgi{XX}_ERA5_{annual,monthly}.nc into the submission folder.

Reuses the summing/writing helpers from combine_gmip4_output.py so the
hindcast and the projections are aggregated by identical code.

Usage:
    python3 combine_gmip4_hindcast.py REGION [REGION ...] [--verify-only] [--v2]
"""
import sys
import re
import glob
import importlib.util
from pathlib import Path

import numpy as np
import netCDF4 as nc

_here = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("cgo", _here / "combine_gmip4_output.py")
cgo = importlib.util.module_from_spec(_spec)
sys.modules["cgo"] = cgo
_spec.loader.exec_module(cgo)


# Runs cover 1940-2025 so firn has its ~5 yr spin-up before 2000, but GMIP4
# asked for 2000-2025; trim on output, never by shortening the run.
TRIM_FROM = 2000


def trim(time, data, units, calendar):
    """keep only steps from TRIM_FROM onwards"""
    yrs = np.array([d.year for d in nc.num2date(time, units, calendar)])
    keep = yrs >= TRIM_FROM
    return time[keep], {k: v[keep] for k, v in data.items()}, int(yrs[keep][0]), int(yrs[keep][-1])


def find_hindcast_batches(region, kind):
    """{batch: path} of per-batch hindcast files, excluding the per-glacier 'indiv' ones"""
    prefix = cgo.BATCH_PREFIX_OVERRIDE.get(region, region)
    d = cgo.campaign_dir(region, "flow") / "PAST" / "PAST_netcdf"
    out = {}
    for p in glob.glob(str(d / f"GloGEM*_rgi*_{prefix}_batch??_ERA5_{kind}.nc")):
        if "indiv" in Path(p).name:
            continue
        b = re.search(r"_batch(\d\d)_", Path(p).name).group(1)
        if b not in out or cgo._newer(p, out[b]):
            out[b] = p
    return out


def process(region, verify_only):
    rgi = cgo.RGI_NUM[region]
    outdir = cgo.FINAL_BASE / "flow" / f"{rgi}_{cgo.REGION_DIR[region]}_GloGEMflow"
    expected = cgo.expected_batches(region)
    ann = find_hindcast_batches(region, "annual")
    mon = find_hindcast_batches(region, "monthly")
    sle = cgo.find_sle_files(region, "flow", None, None, expected)
    # a batch still being written is all-NaN; summing it would silently poison
    # the regional file, so require every expected batch present and finite
    for p_ in ann.values():
        with nc.Dataset(p_) as ds:
            if not np.isfinite(np.ma.filled(ds.variables["area"][:], np.nan)).all():
                print(f"  [UNFINISHED] {region}: {Path(p_).name} has non-finite area")
                return False
    res, why = cgo.combine_batches(region, ann, mon, sle, expected)
    if res is None:
        print(f"  [INCOMPLETE] {region}: {why}")
        return False

    time_a, adata, y0, y1 = trim(res["time_a"], res["adata"], res["units"], res["calendar"])
    time_m, mdata, _, _ = trim(res["time_m"], res["mdata"], res["units"], res["calendar"])
    aattrs, mattrs = res["aattrs"], res["mattrs"]
    for attrs in (aattrs, mattrs):
        attrs["period"] = f"{y0}-{y1}"
        attrs["spinup_note"] = "computed from 1940; output trimmed to the GMIP4 period"

    print(f"  [combine]  {region:15s} ERA5 {y0}-{y1} <- {res['n']} batches "
          f"({len(time_a)} yr, {len(time_m)} mon, area[0]={adata['area'][0]:.3e} m2, "
          f"area[-1]={adata['area'][-1]:.3e} m2, mass_bsl from {res['bsl_src']})")
    if not verify_only:
        outdir.mkdir(parents=True, exist_ok=True)
        cgo.write_annual(outdir / f"GloGEMflow_rgi{rgi}_ERA5_annual.nc", time_a, adata, aattrs,
                         res["units"], res["calendar"])
        cgo.write_monthly(outdir / f"GloGEMflow_rgi{rgi}_ERA5_monthly.nc", time_m, mdata, mattrs,
                          res["units"], res["calendar"])
    return True


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    verify = "--verify-only" in sys.argv
    if "--v2" in sys.argv:
        cgo.RUN = "gmip4v2"
    if not args:
        print(__doc__)
        sys.exit(1)
    ok = all([process(r, verify) for r in args])   # list: don't short-circuit
    sys.exit(0 if ok else 1)
