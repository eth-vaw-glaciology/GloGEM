#!/usr/bin/env python3
"""
create_region_batches.py — split a region's glacier IDs into N catchment
files for parallel batch processing, for any RGI region (not just Alps).

It reads glacier ID + area directly from the "Area (km2): ..." header
line of each per-glacier file in the region's geometricdata bands/
directory, so it works before any run has been done.

Glaciers are sorted by area (largest first) and assigned round-robin
across N batches so each batch gets a balanced mix of large and small
glaciers (no batch holds all the largest, slowest glaciers).

Output: <catchment dir>/RGI{rginum}_{name}_batch{NN}.dat, by default
GLOGEM_DATA_DIR/data/catchments (see gmip4_paths.py).
Catchment IDs are written with the same 'RGI60-{rginum}.{gid}' prefix used
throughout the existing catchment files — this is a fixed template consumed
by catchment_selection.pro via strmid(s,9,5) and is independent of which
RGI version the run itself uses.

--tag adds a name part (RGI{rginum}_{name}_{tag}_batch{NN}.dat), so batches of
another glacier set (e.g. RGI6) never overwrite existing ones; existing files
are not overwritten unless --force is given. --ids-from keeps only the glaciers
listed in a file whose first column is the 5-digit ID (e.g. a calibration file,
so that no batch holds a glacier without calibration parameters).

Usage:
    python scripts/gmip4/create_region_batches.py --region iceland    --rgi-num 06 --rgi-version 7 --n 4
    python scripts/gmip4/create_region_batches.py --region newzealand --rgi-num 18 --rgi-version 7 --n 16
    python scripts/gmip4/create_region_batches.py --region centraleurope --rgi-num 11 --rgi-version 6 --n 24 \
        --tag amocr6 --ids-from <dirres>/monthly/CentralEurope/calibration/calibrate_m1_cID9_centraleurope_final_era5.dat
"""

import os
import re
import sys
import glob
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gmip4_paths import GEOMETRY_DIR, CATCHMENT_DIR  # noqa: E402

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
    parser.add_argument('--geometry-dir', default=str(GEOMETRY_DIR),
                         help='geometricdata folder (default: %(default)s)')
    parser.add_argument('--catchment-dir', default=str(CATCHMENT_DIR),
                         help='folder the catchment files are written to (default: %(default)s)')
    parser.add_argument('--tag', default='',
                         help='extra name part: RGI{rginum}_{region}_{tag}_batchNN.dat')
    parser.add_argument('--ids-from', default='',
                         help='keep only glaciers whose 5-digit ID is the first column of this file')
    parser.add_argument('--force', action='store_true', help='overwrite existing catchment files')
    args = parser.parse_args()
    n = args.n

    bands_dir = os.path.join(args.geometry_dir, f'rgiv{args.rgi_version}', 'bands', args.region)
    files = sorted(glob.glob(os.path.join(bands_dir, '*.dat')))
    if not files:
        raise SystemExit(f'No glacier files found in {bands_dir}')

    glaciers = []
    for fn in files:
        gid = os.path.splitext(os.path.basename(fn))[0]  # e.g. '00001'
        glaciers.append((gid, read_glacier_area(fn)))

    if args.ids_from:
        keep = set()
        with open(args.ids_from) as fh:
            for line in fh:
                first = line.split()[0] if line.split() else ''
                if first.isdigit():
                    keep.add(f'{int(first):05d}')
        missing = [g for g, _ in glaciers if g not in keep]
        glaciers = [(g, a) for g, a in glaciers if g in keep]
        print(f'--ids-from {args.ids_from}: {len(keep)} IDs; {len(missing)} glaciers of the band folder left out'
              + (f' (e.g. {", ".join(missing[:8])})' if missing else ''))

    total = len(glaciers)
    print(f'Region: {args.region} (RGI{args.rgi_num}, geometry from rgiv{args.rgi_version})')
    print(f'Total glaciers: {total}')

    glaciers.sort(key=lambda x: x[1], reverse=True)
    print(f'Largest glacier: {glaciers[0][0]}  {glaciers[0][1]:.3f} km²')
    print(f'Smallest glacier: {glaciers[-1][0]}  {glaciers[-1][1]:.4f} km²')

    batches = [[] for _ in range(n)]
    for i, (gid, _) in enumerate(glaciers):
        batches[i % n].append(gid)

    tag = f'_{args.tag}' if args.tag else ''
    paths = [os.path.join(args.catchment_dir, f'RGI{args.rgi_num}_{args.region}{tag}_batch{i:02d}.dat')
             for i in range(1, n + 1)]
    exist = [p for p in paths if os.path.exists(p)]
    if exist and not args.force:
        raise SystemExit(f'{len(exist)} catchment files exist already (e.g. {exist[0]}); use --tag or --force')
    for i, batch in enumerate(batches, 1):
        fpath = paths[i - 1]
        with open(fpath, 'w') as fh:
            fh.write(f'RGI_ID, {args.region}\n')
            for gid in batch:
                fh.write(f'RGI60-{args.rgi_num}.{gid}\n')
        print(f'  {fpath}  ({len(batch)} glaciers)')

    print(f'\nDone — {n} catchment files in {args.catchment_dir}/')
    print(f'Smallest batch: {min(len(b) for b in batches)}  '
          f'Largest batch: {max(len(b) for b in batches)}')


if __name__ == '__main__':
    main()
