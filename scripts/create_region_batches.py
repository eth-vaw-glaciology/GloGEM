#!/usr/bin/env python3
"""
create_region_batches.py — split a region's glacier IDs into N catchment
files for parallel batch processing, for any RGI region (not just Alps).

Unlike create_batches.py (Alps-specific, sources areas from a completed
Δh run's Area output), this reads glacier ID + area directly from the
"Area (km2): ..." header line of each per-glacier file in the region's
geometricdata bands/ directory — so it works before any run has been done.

Glaciers are sorted by area (largest first) and assigned round-robin
across N batches so each batch gets a balanced mix of large and small
glaciers (same rationale as create_batches.py: avoids one batch holding
all the largest, slowest glaciers).

Output: /itet-stor/jabeer/glogem/data/catchments/RGI{rginum}_{name}_batch{NN}.dat
Catchment IDs are written with the same 'RGI60-{rginum}.{gid}' prefix used
throughout the existing catchment files — this is a fixed template consumed
by catchment_selection.pro via strmid(s,9,5) and is independent of which
RGI version the run itself uses.

Usage:
    python scripts/create_region_batches.py --region iceland    --rgi-num 06 --rgi-version 7 --n 4
    python scripts/create_region_batches.py --region newzealand --rgi-num 18 --rgi-version 7 --n 16
"""

import os
import re
import glob
import argparse

GEOM_BASE = '/itet-stor/jabeer/glogem/geometricdata'
CATCHMENT_DIR = '/itet-stor/jabeer/glogem/data/catchments'

AREA_RE = re.compile(r'Area \(km2\):\s*([\d.]+)')


def read_glacier_area(fn):
    with open(fn) as fh:
        for line in fh:
            m = AREA_RE.search(line)
            if m:
                return float(m.group(1))
    return 0.0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                      formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--region', required=True,
                         help="region folder name under geometricdata/rgiv{N}/bands/ (e.g. iceland, newzealand)")
    parser.add_argument('--rgi-num', required=True,
                         help="2-digit RGI region number for the catchment filename/ID prefix (e.g. 06, 18)")
    parser.add_argument('--rgi-version', default='7',
                         help="RGI version subdir to read geometry from (default: 7)")
    parser.add_argument('--n', type=int, default=8, metavar='N_BATCHES',
                         help='Number of parallel batches (default: 8)')
    args = parser.parse_args()
    n = args.n

    bands_dir = os.path.join(GEOM_BASE, f'rgiv{args.rgi_version}', 'bands', args.region)
    files = sorted(glob.glob(os.path.join(bands_dir, '*.dat')))
    if not files:
        raise SystemExit(f'No glacier files found in {bands_dir}')

    glaciers = []
    for fn in files:
        gid = os.path.splitext(os.path.basename(fn))[0]  # e.g. '00001'
        glaciers.append((gid, read_glacier_area(fn)))

    total = len(glaciers)
    print(f'Region: {args.region} (RGI{args.rgi_num}, geometry from rgiv{args.rgi_version})')
    print(f'Total glaciers: {total}')

    glaciers.sort(key=lambda x: x[1], reverse=True)
    print(f'Largest glacier: {glaciers[0][0]}  {glaciers[0][1]:.3f} km²')
    print(f'Smallest glacier: {glaciers[-1][0]}  {glaciers[-1][1]:.4f} km²')

    batches = [[] for _ in range(n)]
    for i, (gid, _) in enumerate(glaciers):
        batches[i % n].append(gid)

    for i, batch in enumerate(batches, 1):
        name = f'{args.region}_batch{i:02d}'
        fpath = os.path.join(CATCHMENT_DIR, f'RGI{args.rgi_num}_{name}.dat')
        with open(fpath, 'w') as fh:
            fh.write(f'RGI_ID, {args.region}\n')
            for gid in batch:
                fh.write(f'RGI60-{args.rgi_num}.{gid}\n')
        print(f'  {fpath}  ({len(batch)} glaciers)')

    print(f'\nDone — {n} catchment files in {CATCHMENT_DIR}/')
    print(f'Smallest batch: {min(len(b) for b in batches)}  '
          f'Largest batch: {max(len(b) for b in batches)}')


if __name__ == '__main__':
    main()
