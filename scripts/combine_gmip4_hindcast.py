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
    python3 combine_gmip4_hindcast.py REGION [REGION ...] [--verify-only]
"""
import sys
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

CATCHMENTS = "/itet-stor/jabeer/glogem/data/catchments"

# Runs cover 1940-2025 so firn has its ~5 yr spin-up before 2000, but GMIP4
# asked for 2000-2025; trim on output, never by shortening the run.
TRIM_FROM = 2000


def trim(time, data, units, calendar):
    """keep only steps from TRIM_FROM onwards"""
    yrs = np.array([d.year for d in nc.num2date(time, units, calendar)])
    keep = yrs >= TRIM_FROM
    return time[keep], {k: v[keep] for k, v in data.items()}, int(yrs[keep][0]), int(yrs[keep][-1])


def find_hindcast_batches(region, kind):
    """per-batch hindcast files, excluding the per-glacier 'indiv' ones"""
    base_dir = cgo.BASE_DIR_OVERRIDE.get((region, "flow"), f"{region}_flow")
    prefix = cgo.BATCH_PREFIX_OVERRIDE.get(region, region)
    d = (cgo.GLOGEM_BASE / f"{base_dir}_rgi7_gmip4" / "monthly"
         / cgo.REGION_DIR[region] / "PAST" / "PAST_netcdf")
    pat = str(d / f"GloGEM*_rgi*_{prefix}_batch??_ERA5_{kind}.nc")
    return sorted(p for p in glob.glob(pat) if "indiv" not in Path(p).name)


def process(region, verify_only):
    rgi = cgo.RGI_NUM[region]
    outdir = cgo.FINAL_BASE / "flow" / f"{rgi}_{cgo.REGION_DIR[region]}_GloGEMflow"
    ann_paths = find_hindcast_batches(region, "annual")
    mon_paths = find_hindcast_batches(region, "monthly")
    if not ann_paths or not mon_paths:
        print(f"  [MISSING] {region}: {len(ann_paths)} annual, {len(mon_paths)} monthly batch files")
        return False
    if len(ann_paths) != len(mon_paths):
        print(f"  [MISMATCH] {region}: {len(ann_paths)} annual vs {len(mon_paths)} monthly")
        return False

    # a batch still being written is all-NaN; summing it would silently poison
    # the regional file, so require every expected batch present and finite
    expected = len(glob.glob(f"{CATCHMENTS}/RGI{rgi}_"
                             f"{cgo.BATCH_PREFIX_OVERRIDE.get(region, region)}_batch*.dat"))
    if expected and len(ann_paths) != expected:
        print(f"  [INCOMPLETE] {region}: {len(ann_paths)} of {expected} batches present")
        return False
    for p_ in ann_paths:
        with nc.Dataset(p_) as ds:
            if not np.isfinite(np.ma.filled(ds.variables["area"][:], np.nan)).all():
                print(f"  [UNFINISHED] {region}: {Path(p_).name} has non-finite area")
                return False

    time_a, adata, aattrs = cgo.sum_annual(ann_paths)
    per_batch_area = []
    for p in ann_paths:
        with nc.Dataset(p) as ds:
            per_batch_area.append(np.asarray(ds.variables["area"][:], dtype=np.float64))
    time_m, mdata, mattrs = cgo.sum_monthly(mon_paths, per_batch_area, len(time_a))

    for attrs in (aattrs, mattrs):
        attrs.pop("catchment", None)
        attrs["region"] = cgo.REGION_DIR[region]
        attrs["n_batches_combined"] = len(ann_paths)

    with nc.Dataset(ann_paths[0]) as ds:
        tu, tc = ds.variables["time"].units, ds.variables["time"].calendar
    time_a, adata, y0, y1 = trim(time_a, adata, tu, tc)
    time_m, mdata, _, _ = trim(time_m, mdata, tu, tc)
    for attrs in (aattrs, mattrs):
        attrs["period"] = f"{y0}-{y1}"
        attrs["spinup_note"] = "computed from 1940; output trimmed to the GMIP4 period"

    print(f"  [combine]  {region:15s} ERA5 {y0}-{y1} <- {len(ann_paths)} batches "
          f"({len(time_a)} yr, {len(time_m)} mon, area[0]={adata['area'][0]:.3e} m2, "
          f"area[-1]={adata['area'][-1]:.3e} m2)")
    if not verify_only:
        outdir.mkdir(parents=True, exist_ok=True)
        cgo.write_annual(outdir / f"GloGEMflow_rgi{rgi}_ERA5_annual.nc", time_a, adata, aattrs)
        cgo.write_monthly(outdir / f"GloGEMflow_rgi{rgi}_ERA5_monthly.nc", time_m, mdata, mattrs)
    return True


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    verify = "--verify-only" in sys.argv
    if not args:
        print(__doc__)
        sys.exit(1)
    ok = all([process(r, verify) for r in args])   # list: don't short-circuit
    sys.exit(0 if ok else 1)
