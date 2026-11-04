#!/usr/bin/env python3
"""sync_spinup_cache.py — mirror each region's GloGEMflow spin-up cache
(A_flow/ELA_bias fits, one .sav per glacier -- see
procedures/flow/glogemflow_coupled.pro) into the consolidated results
tree, alongside the dh/ and flow/ output combine_gmip4_output.py
writes.

Source:  {region}_flow_rgi7_gmip4/spinup_cache/{glacier_id}_spinup.sav
Dest:    r7spec_global_results/spinup_cache/{Region}/{glacier_id}_spinup.sav

Flow-only (Δh doesn't do this A_flow/ELA fitting, so there's no dh-side
equivalent) and region-only (not split by GCM/SSP -- the cache itself
isn't, since it's SSP-independent by design, see glogemflow_coupled.pro
lines ~50-54).

Uses rsync -a rather than a one-shot copy: the source directories are
still being written to as remaining SSP waves process glaciers that
weren't yet cached, so this is meant to be re-run (cheap, incremental)
rather than treated as a single final snapshot.

Usage:
    python3 sync_spinup_cache.py [REGION ...]     # default: all known regions
"""

import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from combine_gmip4_output import GLOGEM_BASE, FINAL_BASE, REGION_DIR, BASE_DIR_OVERRIDE  # noqa: E402

DEST_ROOT = FINAL_BASE / "spinup_cache"


def sync_region(region):
    base_dir = BASE_DIR_OVERRIDE.get((region, "flow"), f"{region}_flow")
    src = GLOGEM_BASE / f"{base_dir}_rgi7_gmip4" / "spinup_cache"
    dst = DEST_ROOT / REGION_DIR[region]

    if not src.is_dir():
        print(f"  [MISSING] {region}: no spinup_cache at {src}")
        return

    dst.mkdir(parents=True, exist_ok=True)
    # Some regions' spinup_cache/ still holds old backup_* subdirectories
    # from pre-fix debugging (e.g. backup_buggy_20260805, seen under
    # newzealand/iceland/centraleurope) -- exclude all subdirectories so
    # only the live, flat, per-glacier *_spinup.sav files get synced.
    result = subprocess.run(
        ["rsync", "-a", "--stats", "--include=*.sav", "--exclude=*/", f"{src}/", f"{dst}/"],
        capture_output=True, text=True,
    )
    n_files = len(list(dst.glob("*.sav")))
    if result.returncode != 0:
        print(f"  [ERROR] {region}: rsync failed -- {result.stderr.strip()}")
    else:
        transferred = next(
            (l for l in result.stdout.splitlines() if "Number of regular files transferred" in l), ""
        )
        print(f"  [synced] {region:15s} -> {dst}  ({n_files} files total, {transferred.split(':')[-1].strip() if transferred else '?'} new/changed)")


if __name__ == "__main__":
    regions = sys.argv[1:] or list(REGION_DIR.keys())
    for r in regions:
        sync_region(r)
