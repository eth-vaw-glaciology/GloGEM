#!/usr/bin/env python3
"""combine_gmip4_output.py — assemble final GlacierMIP4 submission netCDFs.

Our own runs are parallelized into N per-region batches; each batch's
netCDF (files_netcdf/full/GloGEM_rgi{XX}_{region}_batch{NN}_{GCM}_{ssp}_
{annual,monthly}.nc) already holds that batch's own glaciers pre-summed
into the same regional-aggregate variables GMIP4 wants (area, mass,
mass_bsl, frontal_abl, acc, melt, refreeze, runoff_glac, precip, temp)
-- confirmed by inspecting write_netcdf_projections.pro and comparing
against a colleague's (lvantrich's) already-combined regional file for
the same variables/shapes. Nothing downstream ever sums the N batches
into one region-wide file -- write_glaciermip4_projections.pro was
clearly meant to be that step but is dead code (never called; its
gmip4_* input arrays are never populated anywhere).

This script is that missing step. For each GCM x SSP combination it
either:
  - sums our own N batch files together (own runs), or
  - copies a colleague's already-combined file verbatim (reused Δh)
and writes the result as GloGEM_rgi{XX}_{GCM}_{SSP}_{annual,monthly}.nc
into the final r7spec_global_results/{dh,flow}/{Region}/ directory --
matching the naming convention colleagues already use, so a mixed
region (some GCMs ours, some reused) is indistinguishable file-by-file
from a fully colleague-provided one.

Aggregation across batches:
  - area, mass, mass_bsl, frontal_abl (annual, all extensive: m2/kg):
    summed.
  - acc, melt, refreeze, runoff_glac, precip (monthly, extensive: kg):
    summed.
  - temp (monthly, intensive: K): area-weighted mean, NOT summed --
    averaging temperatures requires weighting, and each batch's own
    file only stores the already-divided value (weighted-sum and
    area-denominator aren't kept separately), so this script
    re-weights across batches using that batch's own ANNUAL area
    (broadcast across the 12 months of its year) as the weight -- an
    approximation, since the true per-batch monthly weight
    (nc_reg_temp_a in write_netcdf_projections.pro) isn't recoverable
    from the output file, but area only updates annually in this
    model (see retreat-model.md), so the approximation is exact
    within a year and only approximate at year boundaries where area
    just changed.

Usage:
    python3 combine_gmip4_output.py REGION METHOD [--verify-only] [--v2]

    REGION   region_n from region_batch.dat, e.g. svalbard, caucasus
    METHOD   dh | flow
    --verify-only   print per-file glacier/GCM/SSP coverage and sanity
                    stats without writing anything
    --v2            read the v2 campaign (<region>_<method>_rgi7_gmip4v2)

Reused-Δh sources are declared in REUSE_SOURCES below, per region.
"""

import sys
import glob
import re
import shutil
import datetime as dt
from pathlib import Path

import numpy as np
import netCDF4 as nc

GLOGEM_BASE = Path("/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development")
FINAL_BASE = Path("/scratch_net/vierzack04_fourth/jabeer/GloGEM/r7spec_global_results")

ALL_GCMS = [
    "ACCESS-ESM1-5", "BCC-CSM2-MR", "CESM2-WACCM", "IPSL-CM6A-LR",
    "MIROC6", "MPI-ESM1-2-HR", "MRI-ESM2-0", "NorESM2-MM",
]
OVERSHOOT_GCMS = ["CESM2-WACCM", "IPSL-CM6A-LR", "MIROC6", "MRI-ESM2-0"]
ALL_SSPS = ["ssp126", "ssp370", "ssp585", "ssp534-over"]

RGI_NUM = {
    "svalbard": "07", "iceland": "06", "scandinavia": "08",
    "russianarctic": "09", "caucasus": "12", "centraleurope": "11",
    "newzealand": "18",
    "arcticcanadan": "03", "arcticcanadas": "04",
    "southasiawest": "14", "southasiaeast": "15",
    "alaska": "01", "westerncanada": "02", "centralasia": "13", "southernandes": "17",
}

# campaign directory suffix: <region>_<method>_rgi7_<RUN>; "--v2" selects gmip4v2
RUN = "gmip4"
CATCHMENTS = "/itet-stor/jabeer/glogem/data/catchments"
# first month of the hydrological year (setup_massbalance_year.pro); output index 0
# is this month of the year before the first annual label
HYDRO_START_MONTH = {"southernandes": 4, "newzealand": 4, "lowlatitudes": 4, "antarctic": 4}
KG_PER_KM3 = 900e9   # ice density 900 kg/m3, as in write_netcdf_glacier.pro

# CentralEurope predates the {region}_{method}_rgi7_gmip4 naming
# convention -- its directories are still "alps_dhdt_rgi7_gmip4" /
# "alps_flow_rgi7_gmip4" (dh is spelled "dhdt" there, and the region
# prefix is "alps" not "centraleurope"). find_own_batch_files() and
# process() use these to override the default {region}_{method}
# pattern only for centraleurope; every other region uses the default.
BASE_DIR_OVERRIDE = {("centraleurope", "dh"): "alps_dhdt", ("centraleurope", "flow"): "alps_flow"}
# On-disk filenames embed GloGEM's own internal region_n codename
# (region_batch.dat), which doesn't always match our own directory-naming
# convention (the CLI region arg here) -- confirmed by inspection for each.
BATCH_PREFIX_OVERRIDE = {
    "centraleurope": "alps",
    "arcticcanadan": "arcticcanadaN", "arcticcanadas": "arcticcanadaS",
    "southasiawest": "centralasiaW", "southasiaeast": "centralasiaS",
    "centralasia": "centralasiaN",
}

# On-disk region directory names -- NOT str.capitalize() (which would give
# "Russianarctic", not "RussianArctic").
REGION_DIR = {
    "svalbard": "Svalbard", "iceland": "Iceland", "scandinavia": "Scandinavia",
    "russianarctic": "RussianArctic", "caucasus": "Caucasus",
    "centraleurope": "CentralEurope", "newzealand": "NewZealand",
    "arcticcanadan": "ArcticCanadaN", "arcticcanadas": "ArcticCanadaS",
    "southasiawest": "SouthAsiaWest", "southasiaeast": "SouthAsiaEast",
    "alaska": "Alaska", "westerncanada": "WesternCanada", "centralasia": "CentralAsia",
    "southernandes": "SouthernAndes",
}

# Per-region, per-SSP declaration of which GCMs come from a colleague's
# already-combined file instead of our own batches. Path is the source
# directory (files_netcdf/full-equivalent) containing
# GloGEM_rgi{XX}_{GCM}_{ssp}_{annual,monthly}.nc already summed.
LVT_BASE = "/scratch_net/vierzack05_fourth/lvantrich/GloGEM/r7spec_global_results/monthly"

REUSE_SOURCES = {
    # Svalbard ssp370/585: our own dh waves for these SSPs were never
    # launched (see run_gmip4_single_region_retry.sh SKIP_DH_SSPS) --
    # value-checked against Caucasus (3.46% max deviation from our own
    # independent run, consistent 1940 baseline) before relying on this
    # for the actual submission. ssp126 and ssp534-over still ours:
    # ssp126 was already computed before this was set up; ssp534-over
    # is permission-blocked on lvantrich's side (rw-rw---- group-only).
    "svalbard": {
        "ssp370": {gcm: f"{LVT_BASE}/Svalbard/files/files_netcdf/full" for gcm in ALL_GCMS},
        "ssp585": {gcm: f"{LVT_BASE}/Svalbard/files/files_netcdf/full" for gcm in ALL_GCMS},
    },
}


def gcms_for_ssp(ssp):
    return OVERSHOOT_GCMS if ssp == "ssp534-over" else ALL_GCMS


def campaign_dir(region, method):
    base_dir = BASE_DIR_OVERRIDE.get((region, method), f"{region}_{method}")
    return GLOGEM_BASE / f"{base_dir}_rgi7_{RUN}" / "monthly" / REGION_DIR[region]


def expected_batches(region):
    """batch numbers that have a catchment file -- every one must be combined"""
    prefix = BATCH_PREFIX_OVERRIDE.get(region, region)
    pat = f"{CATCHMENTS}/RGI{RGI_NUM[region]}_{prefix}_batch??.dat"
    return {re.search(r"_batch(\d\d)\.dat$", p).group(1) for p in glob.glob(pat)}


def find_own_batch_files(region, method, gcm, ssp, kind):
    """{batch: path} of the per-batch regional files (one per batch)"""
    batch_prefix = BATCH_PREFIX_OVERRIDE.get(region, region)
    d = campaign_dir(region, method) / "files" / "files_netcdf" / "full"
    # GCM segment wildcarded and matched back case-insensitively: on-disk
    # netCDF filenames don't reliably preserve GMIP4's canonical GCM-name
    # casing (e.g. Caucasus has "..._NORESM2-MM_..." on disk, all-caps,
    # while its files_original/ directory is "NorESM2-MM" -- confirmed by
    # inspection, not assumed). batch?? (exactly 2 digits then '_')
    # excludes the per-glacier "...batch01indiv_..." files, which
    # glob's 'batch*' would also match.
    pattern = str(d / f"GloGEM*_rgi*_{batch_prefix}_batch??_*_{ssp}_{kind}.nc")
    matches = []
    for p in glob.glob(pattern):
        fname = Path(p).name
        # strip the known, fixed head and tail to isolate the GCM token
        head = f"_{ssp}_{kind}.nc"
        if not fname.endswith(head):
            continue
        stem = fname[: -len(head)]
        token = stem.rsplit("_", 1)[-1]
        if token.lower() == gcm.lower():
            matches.append(p)

    # One batch can be on disk twice: GloGEM_* from before the GloGEMflow
    # rename and GloGEMflow_* from a later re-run. Both match the glob, and
    # summing both counts that batch twice (RussianArctic came out at exactly
    # 2x its real area). Keep one file per batch: GloGEMflow_ wins, then mtime.
    by_batch = {}
    for p in matches:
        m = re.search(r"_batch(\d\d)_", Path(p).name)
        if not m:
            continue
        b = m.group(1)
        cur = by_batch.get(b)
        if cur is None or _newer(p, cur):
            by_batch[b] = p
    return by_batch


def _newer(a, b):
    """GloGEMflow_ beats GloGEM_; otherwise the newer file wins."""
    fa, fb = Path(a).name.startswith("GloGEMflow_"), Path(b).name.startswith("GloGEMflow_")
    if fa != fb:
        return fa
    return Path(a).stat().st_mtime > Path(b).stat().st_mtime


def find_sle_files(region, method, gcm, ssp, batches):
    """{batch: path} of <prefix>_<batch>_SLE_volbz.dat; ssp None = ERA5 hindcast"""
    batch_prefix = BATCH_PREFIX_OVERRIDE.get(region, region)
    d = campaign_dir(region, method)
    if ssp is None:
        dirs = glob.glob(str(d / "PAST" / "PAST_original" / "*"))
    else:
        dirs = [g for g in glob.glob(str(d / "files" / "files_original" / "*"))
                if Path(g).name.lower() == gcm.lower()]
        dirs = [str(Path(g) / ssp) for g in dirs]
    out = {}
    for b in batches:
        hits = [p for g in dirs for p in glob.glob(f"{g}/*_{batch_prefix}_batch{b}_SLE_volbz.dat")]
        if len(hits) == 1:
            out[b] = hits[0]
    return out


def read_sle(path, years):
    """batch mass below sea level [kg] per year from <prefix>_<batch>_SLE_volbz.dat (km3, 2 decimals)"""
    vol = {}
    with open(path) as fh:
        fh.readline()
        for ln in fh:
            q = ln.split()
            if len(q) >= 2:
                vol[int(q[0])] = float(q[1])
    missing = [y for y in years if y not in vol]
    if missing:
        raise ValueError(f"{Path(path).name} lacks years {missing[:3]}...")
    return np.array([vol[y] for y in years]) * KG_PER_KM3


def batch_mass_bsl(ann_path, batch, sle_kg):
    """exact batch mass below sea level [kg] and where it came from.

    Runs without the 86e4f4c fix wrote each glacier's mass_bsl as the running total over
    the batch, so their batch value is a sum of running totals; the per-glacier file's
    last (= largest) entry is then the batch total. The SLE_volbz.dat total (rounded to
    0.01 km3) decides which case applies and checks the result."""
    tol = 0.0051 * KG_PER_KM3 + 1e-5 * np.abs(sle_kg)
    with nc.Dataset(ann_path) as ds:
        reg = np.ma.filled(ds.variables["mass_bsl"][:], np.nan).astype(np.float64)
    if np.all(np.abs(reg - sle_kg) <= tol):
        return reg, "batch"
    indiv = ann_path.replace(f"_batch{batch}_", f"_batch{batch}indiv_")
    with nc.Dataset(indiv) as ds:
        v = ds.variables["mass_bsl"]
        run = np.nanmax(np.ma.filled(v[:], np.nan).astype(np.float64), axis=v.dimensions.index("glacier"))
    if not np.all(np.abs(run - sle_kg) <= tol):
        raise ValueError(f"mass_bsl of {Path(ann_path).name} matches neither the batch nor the "
                         f"running-total form of {Path(indiv).name}")
    return run, "running total"


def hydro_month_time(n_months, first_label_year, start_month, units, calendar):
    """time values for monthly data in model order: index 0 is start_month of the
    year before the first annual label (the first hydrological year's first month)"""
    dates = []
    for k in range(n_months):
        mm = start_month - 1 + k
        dates.append(dt.datetime(first_label_year - 1 + mm // 12, mm % 12 + 1, 1))
    return np.round(nc.date2num(dates, units, calendar)).astype(np.int64)


def to_calendar_years(time_m, data, first_year, last_year, units, calendar):
    """place monthly values (true dates in time_m) on Jan first_year .. Dec last_year;
    months not simulated (end of the last hydrological year) become NaN"""
    dates = nc.num2date(time_m, units, calendar)
    pos = {(d.year, d.month): i for i, d in enumerate(dates)}
    cal = [(y, m) for y in range(first_year, last_year + 1) for m in range(1, 13)]
    out_t = np.round(nc.date2num([dt.datetime(y, m, 1) for y, m in cal], units, calendar)).astype(np.int64)
    out = {}
    for k, v in data.items():
        a = np.full(len(cal), np.nan)
        for j, ym in enumerate(cal):
            i = pos.get(ym)
            if i is not None:
                a[j] = v[i]
        out[k] = a
    return out_t, out


def sum_annual(paths):
    """Sum area/mass/mass_bsl/frontal_abl across batch files. Returns
    (time_array, dict of summed vars, global_attrs_from_first_file)."""
    total = None
    time = None
    attrs = None
    for p in paths:
        with nc.Dataset(p) as ds:
            if time is None:
                time = ds.variables["time"][:].copy()
                attrs = {a: ds.getncattr(a) for a in ds.ncattrs()}
                total = {v: np.zeros_like(ds.variables[v][:], dtype=np.float64)
                         for v in ("area", "mass", "mass_bsl", "frontal_abl")}
            for v in total:
                arr = np.asarray(ds.variables[v][:], dtype=np.float64)
                # a NaN anywhere poisons the whole regional sum, and the result
                # still looks like a valid file (SouthAsiaWest shipped 4 of them)
                if v in ("area", "mass") and not np.isfinite(arr).all():
                    raise ValueError(f"{v} has non-finite values in {Path(p).name}")
                total[v] += arr
    return time, total, attrs


def sum_monthly(paths, annual_area_by_batch, n_years):
    """Sum acc/melt/refreeze/runoff_glac/precip; area-weight temp using
    each batch's own annual area (broadcast to 12 months/year)."""
    time = None
    attrs = None
    sums = None
    temp_weighted_sum = None
    weight_sum = None
    for p, area in zip(paths, annual_area_by_batch):
        with nc.Dataset(p) as ds:
            if time is None:
                time = ds.variables["time"][:].copy()
                attrs = {a: ds.getncattr(a) for a in ds.ncattrs()}
                n_months = len(time)
                sums = {v: np.zeros(n_months, dtype=np.float64)
                        for v in ("acc", "melt", "refreeze", "runoff_glac", "precip")}
                temp_weighted_sum = np.zeros(n_months, dtype=np.float64)
                weight_sum = np.zeros(n_months, dtype=np.float64)
            for v in sums:
                sums[v] += np.asarray(ds.variables[v][:], dtype=np.float64)
            w = np.repeat(np.asarray(area, dtype=np.float64), 12)[:n_months]
            temp_weighted_sum += np.asarray(ds.variables["temp"][:], dtype=np.float64) * w
            weight_sum += w
    temp = np.where(weight_sum > 0, temp_weighted_sum / np.maximum(weight_sum, 1e-30), np.nan)
    sums["temp"] = temp
    return time, sums, attrs


def combine_batches(region, ann, mon, sle, expected):
    """Sum a region's per-batch files ({batch: path} each). Returns (result, None) or
    (None, reason) when a batch is missing in any of the three file kinds."""
    gaps = {k: sorted(expected - set(v)) for k, v in (("annual", ann), ("monthly", mon), ("SLE_volbz", sle))}
    if not expected or any(gaps.values()):
        return None, "missing batches " + ", ".join(f"{k} {v}" for k, v in gaps.items() if v) \
            if expected else "no catchment files found"
    order = sorted(expected)
    ann_paths = [ann[b] for b in order]
    mon_paths = [mon[b] for b in order]
    time_a, adata, aattrs = sum_annual(ann_paths)
    with nc.Dataset(ann_paths[0]) as ds:
        units, cal = ds.variables["time"].units, ds.variables["time"].calendar
    years = [d.year for d in nc.num2date(time_a, units, cal)]
    bsl = np.zeros(len(years))
    src = {}
    for b in order:
        v, how = batch_mass_bsl(ann[b], b, read_sle(sle[b], years))
        bsl += v
        src[how] = src.get(how, 0) + 1
    adata["mass_bsl"] = bsl
    per_batch_area = []
    for p in ann_paths:
        with nc.Dataset(p) as ds:
            per_batch_area.append(np.asarray(ds.variables["area"][:], dtype=np.float64))
    time_m, mdata, mattrs = sum_monthly(mon_paths, per_batch_area, len(time_a))
    start = HYDRO_START_MONTH.get(region, 10)
    time_m = hydro_month_time(len(time_m), years[0], start, units, cal)
    time_m, mdata = to_calendar_years(time_m, mdata, years[0], years[-1], units, cal)
    for attrs in (aattrs, mattrs):
        attrs.pop("catchment", None)
        attrs["region"] = REGION_DIR[region]
        attrs["n_batches_combined"] = len(order)
        attrs["hydrological_year_start_month"] = start
    aattrs["mass_bsl_source"] = ("per-batch totals; batches written as running totals (runs "
                                 "without the 86e4f4c fix) recovered from the per-glacier file")
    aattrs["time_note"] = (f"area, mass and mass_bsl are the state at the start of the hydrological year "
                           f"labelled Y (1 {dt.date(2000, start, 1):%b} of Y-1), frontal_abl is the sum over it; "
                           f"stamped 1 Jan Y as in all GloGEM GMIP4 files")
    mattrs["time_note"] = ("each value stamped at the start of its calendar month (bounds give the interval); "
                           "months outside the simulated hydrological years are NaN")
    return dict(time_a=time_a, adata=adata, aattrs=aattrs, time_m=time_m, mdata=mdata,
                mattrs=mattrs, units=units, calendar=cal, n=len(order), bsl_src=src), None


CELL_METHODS = {"area": "time: point", "mass": "time: point", "mass_bsl": "time: point",
                "frontal_abl": "time: sum", "acc": "time: sum", "melt": "time: sum",
                "refreeze": "time: sum", "runoff_glac": "time: sum", "precip": "time: sum",
                "temp": "time: mean"}


def _time_with_bounds(ds, time, units, calendar, monthly):
    """time coordinate plus time_bounds: [1st of the stamp's month or year, 1st of the next]"""
    ds.createDimension("time", len(time))
    ds.createDimension("nv", 2)
    tv = ds.createVariable("time", "i4", ("time",))
    tv.units = units
    tv.calendar = calendar
    tv.long_name = "time"
    tv.bounds = "time_bounds"
    tv[:] = time
    starts = nc.num2date(time, units, calendar)
    ends = [dt.datetime(d.year + (d.month == 12), d.month % 12 + 1, 1) if monthly
            else dt.datetime(d.year + 1, 1, 1) for d in starts]
    bv = ds.createVariable("time_bounds", "i4", ("time", "nv"))
    bv[:, 0] = np.asarray(time)
    bv[:, 1] = np.round(nc.date2num(ends, units, calendar)).astype(np.int64)


def write_annual(outpath, time, data, attrs, units="days since 1850-01-01", calendar="standard"):
    with nc.Dataset(outpath, "w", format="NETCDF4") as ds:
        for k, v in attrs.items():
            ds.setncattr(k, v)
        _time_with_bounds(ds, time, units, calendar, monthly=False)
        meta = {
            "area": ("Glacier area", "m2"),
            "mass": ("Glacier mass", "kg"),
            "mass_bsl": ("Glacier mass below sea level", "kg"),
            "frontal_abl": ("Total annual frontal ablation", "kg"),
        }
        for k, (long_name, units) in meta.items():
            v = ds.createVariable(k, "f4", ("time",), fill_value=np.nan)
            v.long_name = long_name
            v.units = units
            v.cell_methods = CELL_METHODS[k]
            v[:] = data[k]


def write_monthly(outpath, time, data, attrs, units="days since 1850-01-01", calendar="standard"):
    with nc.Dataset(outpath, "w", format="NETCDF4") as ds:
        for k, v in attrs.items():
            ds.setncattr(k, v)
        _time_with_bounds(ds, time, units, calendar, monthly=True)
        meta = {
            "acc": ("Total accumulation", "kg"),
            "melt": ("Total glacier melt (snow, ice, firn)", "kg"),
            "refreeze": ("Total refreezing", "kg"),
            "runoff_glac": ("Glacier runoff from glacierized area", "kg"),
            "precip": ("Total precipitation over initial glacierized area", "kg"),
            "temp": ("Near-surface air temperature over initial glacierized area", "K"),
        }
        for k, (long_name, units) in meta.items():
            v = ds.createVariable(k, "f4", ("time",), fill_value=np.nan)
            v.long_name = long_name
            v.units = units
            v.cell_methods = CELL_METHODS[k]
            v[:] = data[k]


def process(region, method, verify_only):
    rgi = RGI_NUM[region]
    outdir = FINAL_BASE / method / f"{rgi}_{REGION_DIR[region]}_GloGEMflow"
    n_combined, n_reused, n_missing = 0, 0, 0

    for ssp in ALL_SSPS:
        for gcm in gcms_for_ssp(ssp):
            # REUSE_SOURCES is colleague *Δh* output -- must never apply to
            # method == "flow" (GloGEMflow is our own, uncomputed-elsewhere
            # contribution; substituting Δh data into it would silently
            # mislabel a different physical model's results as ours).
            reuse = REUSE_SOURCES.get(region, {}).get(ssp, {}).get(gcm) if method == "dh" else None
            # flow runs are a different model from the Delta-h GloGEM and must say so
            model = "GloGEMflow" if method == "flow" else "GloGEM"
            ann_out = outdir / f"{model}_rgi{rgi}_{gcm}_{ssp}_annual.nc"
            mon_out = outdir / f"{model}_rgi{rgi}_{gcm}_{ssp}_monthly.nc"

            if reuse:
                src_ann = Path(reuse) / f"GloGEM_rgi{rgi}_{gcm}_{ssp}_annual.nc"
                src_mon = Path(reuse) / f"GloGEM_rgi{rgi}_{gcm}_{ssp}_monthly.nc"
                if not (src_ann.exists() and src_mon.exists()):
                    print(f"  [MISSING reuse source] {region}/{method} {gcm}/{ssp}: {src_ann}")
                    n_missing += 1
                    continue
                print(f"  [reuse]    {gcm:15s} {ssp:12s} <- {reuse}")
                n_reused += 1
                if not verify_only:
                    outdir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_ann, ann_out)
                    shutil.copy2(src_mon, mon_out)
                continue

            expected = expected_batches(region)
            ann = find_own_batch_files(region, method, gcm, ssp, "annual")
            mon = find_own_batch_files(region, method, gcm, ssp, "monthly")
            sle = find_sle_files(region, method, gcm, ssp, expected)
            res, why = combine_batches(region, ann, mon, sle, expected)
            if res is None:
                print(f"  [MISSING own batches] {region}/{method} {gcm}/{ssp}: {why}")
                n_missing += 1
                continue
            adata = res["adata"]
            print(f"  [combine]  {gcm:15s} {ssp:12s} <- {res['n']} batches "
                  f"(area[0]={adata['area'][0]:.3e} m2, area[-1]={adata['area'][-1]:.3e} m2, "
                  f"mass_bsl from {res['bsl_src']})")
            n_combined += 1
            if not verify_only:
                outdir.mkdir(parents=True, exist_ok=True)
                write_annual(ann_out, res["time_a"], adata, res["aattrs"], res["units"], res["calendar"])
                write_monthly(mon_out, res["time_m"], res["mdata"], res["mattrs"], res["units"], res["calendar"])

    print(f"\n{region}/{method}: {n_combined} combined, {n_reused} reused, {n_missing} missing "
          f"(of {sum(len(gcms_for_ssp(s)) for s in ALL_SSPS)} GCM x SSP combinations)")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    region_arg, method_arg = sys.argv[1], sys.argv[2]
    verify = "--verify-only" in sys.argv
    if "--v2" in sys.argv:
        RUN = "gmip4v2"
    process(region_arg, method_arg, verify)
