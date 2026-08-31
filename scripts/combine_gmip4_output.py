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
    python3 combine_gmip4_output.py REGION METHOD [--verify-only]

    REGION   region_n from region_batch.dat, e.g. svalbard, caucasus
    METHOD   dh | flow
    --verify-only   print per-file glacier/GCM/SSP coverage and sanity
                    stats without writing anything

Reused-Δh sources are declared in REUSE_SOURCES below, per region.
"""

import sys
import glob
import re
import shutil
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
}

# CentralEurope predates the {region}_{method}_rgi7_gmip4 naming
# convention -- its directories are still "alps_dhdt_rgi7_gmip4" /
# "alps_flow_rgi7_gmip4" (dh is spelled "dhdt" there, and the region
# prefix is "alps" not "centraleurope"). find_own_batch_files() and
# process() use these to override the default {region}_{method}
# pattern only for centraleurope; every other region uses the default.
BASE_DIR_OVERRIDE = {("centraleurope", "dh"): "alps_dhdt", ("centraleurope", "flow"): "alps_flow"}
BATCH_PREFIX_OVERRIDE = {"centraleurope": "alps"}

# On-disk region directory names -- NOT str.capitalize() (which would give
# "Russianarctic", not "RussianArctic").
REGION_DIR = {
    "svalbard": "Svalbard", "iceland": "Iceland", "scandinavia": "Scandinavia",
    "russianarctic": "RussianArctic", "caucasus": "Caucasus",
    "centraleurope": "CentralEurope", "newzealand": "NewZealand",
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


def find_own_batch_files(region, method, gcm, ssp, kind):
    base_dir = BASE_DIR_OVERRIDE.get((region, method), f"{region}_{method}")
    batch_prefix = BATCH_PREFIX_OVERRIDE.get(region, region)
    d = GLOGEM_BASE / f"{base_dir}_rgi7_gmip4" / "monthly" / REGION_DIR[region] / "files" / "files_netcdf" / "full"
    # GCM segment wildcarded and matched back case-insensitively: on-disk
    # netCDF filenames don't reliably preserve GMIP4's canonical GCM-name
    # casing (e.g. Caucasus has "..._NORESM2-MM_..." on disk, all-caps,
    # while its files_original/ directory is "NorESM2-MM" -- confirmed by
    # inspection, not assumed). batch?? (exactly 2 digits then '_')
    # excludes the per-glacier "...batch01indiv_..." files, which
    # glob's 'batch*' would also match.
    pattern = str(d / f"GloGEM_rgi*_{batch_prefix}_batch??_*_{ssp}_{kind}.nc")
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
    return sorted(matches)


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
                total[v] += np.asarray(ds.variables[v][:], dtype=np.float64)
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


def write_annual(outpath, time, data, attrs):
    with nc.Dataset(outpath, "w", format="NETCDF4") as ds:
        for k, v in attrs.items():
            ds.setncattr(k, v)
        ds.createDimension("time", len(time))
        tv = ds.createVariable("time", "i4", ("time",))
        tv.units = "days since 1850-01-01"
        tv.calendar = "standard"
        tv[:] = time
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
            v[:] = data[k]


def write_monthly(outpath, time, data, attrs):
    with nc.Dataset(outpath, "w", format="NETCDF4") as ds:
        for k, v in attrs.items():
            ds.setncattr(k, v)
        ds.createDimension("time", len(time))
        tv = ds.createVariable("time", "i4", ("time",))
        tv.units = "days since 1850-01-01"
        tv.calendar = "standard"
        tv[:] = time
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
            v[:] = data[k]


def process(region, method, verify_only):
    rgi = RGI_NUM[region]
    outdir = FINAL_BASE / method / REGION_DIR[region]
    n_combined, n_reused, n_missing = 0, 0, 0

    for ssp in ALL_SSPS:
        for gcm in gcms_for_ssp(ssp):
            # REUSE_SOURCES is colleague *Δh* output -- must never apply to
            # method == "flow" (GloGEMflow is our own, uncomputed-elsewhere
            # contribution; substituting Δh data into it would silently
            # mislabel a different physical model's results as ours).
            reuse = REUSE_SOURCES.get(region, {}).get(ssp, {}).get(gcm) if method == "dh" else None
            ann_out = outdir / f"GloGEM_rgi{rgi}_{gcm}_{ssp}_annual.nc"
            mon_out = outdir / f"GloGEM_rgi{rgi}_{gcm}_{ssp}_monthly.nc"

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

            ann_paths = find_own_batch_files(region, method, gcm, ssp, "annual")
            mon_paths = find_own_batch_files(region, method, gcm, ssp, "monthly")
            if not ann_paths or not mon_paths:
                print(f"  [MISSING own batches] {region}/{method} {gcm}/{ssp}: "
                      f"{len(ann_paths)} annual, {len(mon_paths)} monthly files found")
                n_missing += 1
                continue

            time_a, adata, aattrs = sum_annual(ann_paths)
            per_batch_area = []
            for p in ann_paths:
                with nc.Dataset(p) as ds:
                    per_batch_area.append(np.asarray(ds.variables["area"][:], dtype=np.float64))
            time_m, mdata, mattrs = sum_monthly(mon_paths, per_batch_area, len(time_a))

            # aattrs/mattrs were copied from batch01's own file, whose
            # 'catchment' attribute names just that one batch -- replace
            # with region-wide provenance now that N batches are combined.
            for attrs in (aattrs, mattrs):
                attrs.pop("catchment", None)
                attrs["region"] = REGION_DIR[region]
                attrs["n_batches_combined"] = len(ann_paths)

            print(f"  [combine]  {gcm:15s} {ssp:12s} <- {len(ann_paths)} batches "
                  f"(area[0]={adata['area'][0]:.3e} m2, area[-1]={adata['area'][-1]:.3e} m2)")
            n_combined += 1
            if not verify_only:
                outdir.mkdir(parents=True, exist_ok=True)
                write_annual(ann_out, time_a, adata, aattrs)
                write_monthly(mon_out, time_m, mdata, mattrs)

    print(f"\n{region}/{method}: {n_combined} combined, {n_reused} reused, {n_missing} missing "
          f"(of {sum(len(gcms_for_ssp(s)) for s in ALL_SSPS)} GCM x SSP combinations)")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    region_arg, method_arg = sys.argv[1], sys.argv[2]
    verify = "--verify-only" in sys.argv
    process(region_arg, method_arg, verify)
