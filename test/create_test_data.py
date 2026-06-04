#!/usr/bin/env python3
"""
create_test_data.py

Builds a self-contained minimal dataset for the GloGEM Aletsch/Morteratsch
test run from the full production data on network storage.

Run this script ONCE from a machine that has access to the full dataset,
then commit the resulting test/data/, test/climatedata/, and
test/geometricdata/ directories to the repository.

Usage
-----
    python create_test_data.py \
        --src /itet-stor/<username>/glogem/ \
        --dst /path/to/GloGEM/test/

Arguments
---------
--src : path to the root of the full GloGEM data tree
        (should contain data/, climatedata/, geometricdata/)
--dst : path to the GloGEM/test/ directory that will receive
        the trimmed dataset (created if absent)

What is produced
----------------
test/data/
    region_batch.dat                      full copy (31 regions, 1.7 KB)
    regional_parameters_era5.dat          full copy (daily, 3.6 KB)
    regional_parameters_ERA5.dat          full copy (monthly, 2.7 KB)
    catchments/
        RGI11_Aletsch_Morteratsch.dat     full copy (3 lines)
    geodetic/
        RGIv7.0/
            aggregated_2000_2020/
                11_mb_glspec.dat          full copy (307 KB – needed for
                                           regional statistics in calibration)

test/geometricdata/
    rgiv7/
        files/
            thick_centraleurope.dat       2-glacier subset (~200 B)
        files_HF/
            thick_centraleurope.dat       2-glacier subset (~200 B)
        bands/
            centraleurope/
                bands_02596.dat           full copy (22 KB)
                bands_02216.dat           full copy (17 KB)
        bands_HF/
            centraleurope/
                bands_02596.dat           full copy (22 KB)
                bands_02216.dat           full copy (18 KB)

test/climatedata/
    reanalysis/
        daily/
            era5/
                CentralEurope/
                    clim_8.00_46.50.dat   cropped to 1990-2024 (~750 KB)
                    clim_10.00_46.50.dat  cropped to 1990-2024 (~750 KB)
                    clim_10.00_46.25.dat  cropped to 1990-2024 (~750 KB)
                    clim_9.75_46.25.dat   cropped to 1990-2024 (~750 KB)
                    clim_7.75_46.50.dat   cropped to 1990-2024 (~750 KB)
        monthly/
            ERA5/
                CentralEurope/
                    clim_CentralEurope.mdi       bbox subset (~1.4 MB)
                    tgrad_CentralEurope.mdi      bbox subset (~50 KB)
                    variability_CentralEurope.mdi bbox subset (~250 KB)

Spatial bounding box for monthly .mdi subsetting
-------------------------------------------------
lon : 7.0 – 11.0  (covers Aletsch at 7.97 and Morteratsch at 9.97)
lat : 45.5 – 47.5 (both glaciers at ~46.4)

Run period for daily file cropping
-----------------------------------
1990-01-01 onwards  (model test uses tran=[1991, 2020])
"""

import argparse
import os
import shutil
import sys


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def makedirs(path):
    os.makedirs(path, exist_ok=True)


def copy_file(src, dst):
    makedirs(os.path.dirname(dst))
    shutil.copy2(src, dst)
    print(f"  copied  {os.path.relpath(src)}")


def _tokens(lines):
    """Yield all whitespace-separated tokens across all lines."""
    for line in lines:
        yield from line.split()


# ---------------------------------------------------------------------------
# Thick-file filter (keep only 2 Aletsch/Morteratsch entries)
# ---------------------------------------------------------------------------

KEEP_IDS = {"02596", "02216"}   # short 5-char IDs embedded in the semicolon-delimited ID


def filter_thick_file(src, dst):
    makedirs(os.path.dirname(dst))
    with open(src) as f:
        lines = f.readlines()
    header = lines[0]
    kept = [l for l in lines[1:] if any(kid in l.split(";")[0] for kid in KEEP_IDS)]
    with open(dst, "w") as f:
        f.write(header)
        f.writelines(kept)
    print(f"  filtered {os.path.relpath(src)} → {len(kept)} glacier(s)")


# ---------------------------------------------------------------------------
# Daily climate file crop (keep rows where year >= YEAR_START)
# ---------------------------------------------------------------------------

YEAR_START = 1990


def crop_daily_clim(src, dst):
    makedirs(os.path.dirname(dst))
    with open(src) as f:
        lines = f.readlines()
    # First 3 lines are header; data starts at line 3
    header = lines[:3]
    data = [l for l in lines[3:] if l.strip() and float(l.split()[0]) >= YEAR_START]
    with open(dst, "w") as f:
        f.writelines(header)
        f.writelines(data)
    print(f"  cropped  {os.path.relpath(src)} ({len(data)} days from {YEAR_START})")


# ---------------------------------------------------------------------------
# Monthly .mdi spatial subset
# ---------------------------------------------------------------------------

# Bounding box (inclusive, degrees)
LON_MIN, LON_MAX = 7.0, 11.0
LAT_MIN, LAT_MAX = 45.5, 47.5


def _subset_mdi_clim(src, dst):
    """Subset the main climate .mdi (T and P, ntime × nlons × nlats)."""
    with open(src) as f:
        raw = f.readlines()

    header_line = raw[0]
    ntime = int(raw[1])
    nlons = int(raw[2])
    nlats = int(raw[3])
    nvar2d = int(raw[4])
    nvar3d = int(raw[5])

    idx = 6
    rtime = [float(raw[idx + i]) for i in range(ntime)];  idx += ntime
    rlon_raw = [float(raw[idx + i]) for i in range(nlons)]; idx += nlons
    rlat = [float(raw[idx + i]) for i in range(nlats)];  idx += nlats

    # Convert longitudes to -180..180
    rlon = [l - 360 if l >= 180 else l for l in rlon_raw]

    # Find bbox indices
    lon_idx = [i for i, l in enumerate(rlon) if LON_MIN <= l <= LON_MAX]
    lat_idx = [i for i, l in enumerate(rlat) if LAT_MIN <= l <= LAT_MAX]
    nlons_new = len(lon_idx)
    nlats_new = len(lat_idx)
    print(f"  mdi clim: {nlons}x{nlats} → {nlons_new}x{nlats_new} "
          f"(lon {rlon[lon_idx[0]]:.2f}–{rlon[lon_idx[-1]]:.2f}, "
          f"lat {rlat[lat_idx[0]]:.2f}–{rlat[lat_idx[-1]]:.2f})")

    # Read elevation rows: nlons rows, each with nlats values
    elev_rows = []
    for h in range(nlons):
        vals = list(map(float, raw[idx].split()))
        if h in lon_idx:
            elev_rows.append([vals[j] for j in lat_idx])
        idx += 1

    # Read temperature: ntime * nlons rows, each with nlats values
    temp_rows = []
    for t in range(ntime):
        for h in range(nlons):
            vals = list(map(float, raw[idx].split()))
            if h in lon_idx:
                temp_rows.append([vals[j] for j in lat_idx])
            idx += 1

    # Read precipitation: ntime * nlons rows, each with nlats values
    prec_rows = []
    for t in range(ntime):
        for h in range(nlons):
            vals = list(map(float, raw[idx].split()))
            if h in lon_idx:
                prec_rows.append([vals[j] for j in lat_idx])
            idx += 1

    makedirs(os.path.dirname(dst))
    with open(dst, "w") as f:
        f.write(header_line)
        f.write(f"      {ntime}\n")
        f.write(f"          {nlons_new}\n")
        f.write(f"          {nlats_new}\n")
        f.write(f"       {nvar2d}\n")
        f.write(f"       {nvar3d}\n")
        for v in rtime:
            f.write(f"     {v:.4f}\n")
        for i in lon_idx:
            f.write(f"     {rlon_raw[i]:.6f}\n")
        for i in lat_idx:
            f.write(f"     {rlat[i]:.6f}\n")
        for row in elev_rows:
            f.write(" " + " ".join(f"{v:12.3f}" for v in row) + "\n")
        for row in temp_rows:
            f.write(" " + " ".join(f"{v:12.4f}" for v in row) + "\n")
        for row in prec_rows:
            f.write(" " + " ".join(f"{v:12.5f}" for v in row) + "\n")

    size_mb = os.path.getsize(dst) / 1e6
    print(f"  wrote    {os.path.relpath(dst)} ({size_mb:.1f} MB)")


def _subset_mdi_tgrad(src, dst):
    """Subset the temperature-gradient .mdi (nmonths × nlons × nlats)."""
    with open(src) as f:
        raw = f.readlines()

    header_line = raw[0]
    nmonths = int(raw[1])
    nlons = int(raw[2])
    nlats = int(raw[3])
    nvar = int(raw[4])

    idx = 5
    rvmon = [float(raw[idx + i]) for i in range(nmonths)]; idx += nmonths
    rlon_raw = [float(raw[idx + i]) for i in range(nlons)]; idx += nlons
    rlat = [float(raw[idx + i]) for i in range(nlats)]; idx += nlats

    rlon = [l - 360 if l >= 180 else l for l in rlon_raw]
    lon_idx = [i for i, l in enumerate(rlon) if LON_MIN <= l <= LON_MAX]
    lat_idx = [i for i, l in enumerate(rlat) if LAT_MIN <= l <= LAT_MAX]
    nlons_new = len(lon_idx)
    nlats_new = len(lat_idx)
    print(f"  mdi tgrad: {nlons}x{nlats} → {nlons_new}x{nlats_new}")

    data_rows = []
    for m in range(nmonths):
        for h in range(nlons):
            vals = list(map(float, raw[idx].split()))
            if h in lon_idx:
                data_rows.append([vals[j] for j in lat_idx])
            idx += 1

    makedirs(os.path.dirname(dst))
    with open(dst, "w") as f:
        f.write(header_line)
        f.write(f"      {nmonths}\n")
        f.write(f"          {nlons_new}\n")
        f.write(f"          {nlats_new}\n")
        f.write(f"       {nvar}\n")
        for v in rvmon:
            f.write(f"       {int(v)}\n")
        for i in lon_idx:
            f.write(f"     {rlon_raw[i]:.6f}\n")
        for i in lat_idx:
            f.write(f"     {rlat[i]:.6f}\n")
        for row in data_rows:
            f.write(" " + " ".join(f"{v:.10f}" for v in row) + "\n")

    size_kb = os.path.getsize(dst) / 1e3
    print(f"  wrote    {os.path.relpath(dst)} ({size_kb:.0f} KB)")


def _subset_mdi_variability(src, dst):
    """Subset the sub-monthly variability .mdi (nmonths × ndays × nlons × nlats)."""
    with open(src) as f:
        raw = f.readlines()

    header_line = raw[0]
    nmonths = int(raw[1])
    ndays = int(raw[2])
    nlons = int(raw[3])
    nlats = int(raw[4])
    nvar = int(raw[5])

    idx = 6
    rvmon = [float(raw[idx + i]) for i in range(nmonths)]; idx += nmonths
    rvday = [float(raw[idx + i]) for i in range(ndays)]; idx += ndays
    rlon_raw = [float(raw[idx + i]) for i in range(nlons)]; idx += nlons
    rlat = [float(raw[idx + i]) for i in range(nlats)]; idx += nlats

    rlon = [l - 360 if l >= 180 else l for l in rlon_raw]
    lon_idx = [i for i, l in enumerate(rlon) if LON_MIN <= l <= LON_MAX]
    lat_idx = [i for i, l in enumerate(rlat) if LAT_MIN <= l <= LAT_MAX]
    nlons_new = len(lon_idx)
    nlats_new = len(lat_idx)
    print(f"  mdi variab: {nlons}x{nlats} → {nlons_new}x{nlats_new}")

    data_rows = []
    for m in range(nmonths):
        for d in range(ndays):
            for h in range(nlons):
                vals = list(map(float, raw[idx].split()))
                if h in lon_idx:
                    data_rows.append([vals[j] for j in lat_idx])
                idx += 1

    makedirs(os.path.dirname(dst))
    with open(dst, "w") as f:
        f.write(header_line)
        f.write(f"      {nmonths}\n")
        f.write(f"      {ndays}\n")
        f.write(f"          {nlons_new}\n")
        f.write(f"          {nlats_new}\n")
        f.write(f"       {nvar}\n")
        for v in rvmon:
            f.write(f"       {int(v)}\n")
        for v in rvday:
            f.write(f"       {int(v)}\n")
        for i in lon_idx:
            f.write(f"     {rlon_raw[i]:.6f}\n")
        for i in lat_idx:
            f.write(f"     {rlat[i]:.6f}\n")
        for row in data_rows:
            f.write(" " + " ".join(f"{v:.8f}" for v in row) + "\n")

    size_kb = os.path.getsize(dst) / 1e3
    print(f"  wrote    {os.path.relpath(dst)} ({size_kb:.0f} KB)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

DAILY_CLIM_FILES = [
    "clim_8.00_46.50.dat",    # nearest to Aletsch (lon 7.97, lat 46.48)
    "clim_7.75_46.50.dat",    # 1st fallback
    "clim_10.00_46.50.dat",   # nearest to Morteratsch (lon 9.97, lat 46.40)
    "clim_10.00_46.25.dat",   # 2nd fallback
    "clim_9.75_46.25.dat",    # 3rd fallback
]


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", required=True,
                        help="Root of the full GloGEM data tree (contains data/, climatedata/, geometricdata/)")
    parser.add_argument("--dst", required=True,
                        help="GloGEM/test/ directory to populate")
    args = parser.parse_args()

    src = args.src.rstrip("/")
    dst = args.dst.rstrip("/")

    if not os.path.isdir(src):
        sys.exit(f"ERROR: source directory not found: {src}")

    print(f"\nSource : {src}")
    print(f"Dest   : {dst}\n")

    # ------------------------------------------------------------------
    # 1. Static small files
    # ------------------------------------------------------------------
    print("=== Static data files ===")
    copy_file(f"{src}/data/region_batch.dat",
              f"{dst}/data/region_batch.dat")
    copy_file(f"{src}/data/regional_parameters_era5.dat",
              f"{dst}/data/regional_parameters_era5.dat")
    copy_file(f"{src}/data/regional_parameters_ERA5.dat",
              f"{dst}/data/regional_parameters_ERA5.dat")
    copy_file(f"{src}/data/catchments/RGI11_Aletsch_Morteratsch.dat",
              f"{dst}/data/catchments/RGI11_Aletsch_Morteratsch.dat")
    copy_file(f"{src}/data/geodetic/RGIv7.0/aggregated_2000_2020/11_mb_glspec.dat",
              f"{dst}/data/geodetic/RGIv7.0/aggregated_2000_2020/11_mb_glspec.dat")

    # ------------------------------------------------------------------
    # 2. Glacier inventory (thick files) – filtered to 2 glaciers
    # ------------------------------------------------------------------
    print("\n=== Glacier inventory (filtered) ===")
    filter_thick_file(
        f"{src}/geometricdata/rgiv7/files/thick_centraleurope.dat",
        f"{dst}/geometricdata/rgiv7/files/thick_centraleurope.dat")
    filter_thick_file(
        f"{src}/geometricdata/rgiv7/files_HF/thick_centraleurope.dat",
        f"{dst}/geometricdata/rgiv7/files_HF/thick_centraleurope.dat")

    # ------------------------------------------------------------------
    # 3. Hypsometry band files
    # ------------------------------------------------------------------
    print("\n=== Band files ===")
    for gid in ["02596", "02216"]:
        copy_file(
            f"{src}/geometricdata/rgiv7/bands/centraleurope/bands_{gid}.dat",
            f"{dst}/geometricdata/rgiv7/bands/centraleurope/bands_{gid}.dat")
        copy_file(
            f"{src}/geometricdata/rgiv7/bands_HF/centraleurope/bands_{gid}.dat",
            f"{dst}/geometricdata/rgiv7/bands_HF/centraleurope/bands_{gid}.dat")

    # ------------------------------------------------------------------
    # 4. Daily ERA5 climate files – cropped to 1990+
    # ------------------------------------------------------------------
    print("\n=== Daily ERA5 climate files (cropped to 1990+) ===")
    era5_daily_src = f"{src}/climatedata/reanalysis/daily/era5/CentralEurope"
    era5_daily_dst = f"{dst}/climatedata/reanalysis/daily/era5/CentralEurope"
    for fname in DAILY_CLIM_FILES:
        src_path = f"{era5_daily_src}/{fname}"
        if os.path.exists(src_path):
            crop_daily_clim(src_path, f"{era5_daily_dst}/{fname}")
        else:
            print(f"  SKIP     {fname} (not found at source)")

    # ------------------------------------------------------------------
    # 5. Monthly ERA5 .mdi files – spatially subsetted
    # ------------------------------------------------------------------
    print("\n=== Monthly ERA5 .mdi files (spatial subset) ===")
    mdi_src = f"{src}/climatedata/reanalysis/monthly/ERA5/CentralEurope"
    mdi_dst = f"{dst}/climatedata/reanalysis/monthly/ERA5/CentralEurope"
    _subset_mdi_clim(f"{mdi_src}/clim_CentralEurope.mdi",
                     f"{mdi_dst}/clim_CentralEurope.mdi")
    _subset_mdi_tgrad(f"{mdi_src}/tgrad_CentralEurope.mdi",
                      f"{mdi_dst}/tgrad_CentralEurope.mdi")
    _subset_mdi_variability(f"{mdi_src}/variability_CentralEurope.mdi",
                            f"{mdi_dst}/variability_CentralEurope.mdi")

    print("\nDone. Commit test/data/, test/climatedata/, and test/geometricdata/ to the repo.")


if __name__ == "__main__":
    main()
