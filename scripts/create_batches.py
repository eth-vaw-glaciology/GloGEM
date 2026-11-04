#!/usr/bin/env python3
"""
create_batches.py  —  split all Alpine glacier IDs into N catchment files.

Reads the authoritative full-Alps ID list from the completed Δh parameterisation run, sorts
glaciers by 2003 area (largest first), then assigns them to batches via round-
robin so every batch contains a balanced mix of large and small glaciers.
This eliminates the persistent bottleneck where batch02/batch11 held the largest
glaciers while others finished early.

Output: /itet-stor/jabeer/glogem/data/catchments/RGI11_alps_batch{01..NN}.dat

Usage:
    python scripts/create_batches.py             # 24 batches (default)
    python scripts/create_batches.py --n 16      # 16 batches
"""

import os
import argparse

DHDT_AREA = (
    '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/'
    'alps_dhdt/monthly/CentralEurope/files/files_original/BCC-CSM2-MR/'
    'ssp126/centraleurope_Area_r1.dat'
)
CATCHMENT_DIR = '/itet-stor/jabeer/glogem/data/catchments'


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--n', type=int, default=24, metavar='N_BATCHES',
                        help='Number of parallel batches (default: 24)')
    args = parser.parse_args()
    n = args.n

    # Read glacier IDs and 2003 area from Δh parameterisation Area output
    glaciers = []
    with open(DHDT_AREA) as fh:
        header = fh.readline().split()
        years = [int(y) for y in header[1:]]
        yr2003_col = years.index(2003) + 1   # +1 because parts[0] = ID
        for line in fh:
            parts = line.split()
            if parts:
                gid = parts[0]
                try:
                    area = float(parts[yr2003_col])
                except (IndexError, ValueError):
                    area = 0.0
                glaciers.append((gid, area))

    total = len(glaciers)
    print(f'Total glaciers: {total}')

    # Sort largest first so round-robin spreads large glaciers evenly across batches
    glaciers.sort(key=lambda x: x[1], reverse=True)
    print(f'Largest glacier: {glaciers[0][0]}  {glaciers[0][1]:.3f} km²')
    print(f'Smallest glacier: {glaciers[-1][0]}  {glaciers[-1][1]:.4f} km²')

    # Round-robin assignment: glacier 0 → batch 0, glacier 1 → batch 1, ...
    # glacier N → batch 0, ... — every batch gets a balanced size distribution
    batches = [[] for _ in range(n)]
    for i, (gid, _) in enumerate(glaciers):
        batches[i % n].append(gid)

    # Write catchment files — format matches existing RGI11_Alps.dat
    for i, batch in enumerate(batches, 1):
        name  = f'alps_batch{i:02d}'
        fpath = os.path.join(CATCHMENT_DIR, f'RGI11_{name}.dat')
        with open(fpath, 'w') as fh:
            fh.write('RGI_ID, Alps\n')
            for gid in batch:
                fh.write(f'RGI60-11.{gid}\n')
        print(f'  {fpath}  ({len(batch)} glaciers)')

    print(f'\nDone — {n} catchment files in {CATCHMENT_DIR}/')
    print(f'Smallest batch: {min(len(b) for b in batches)}  '
          f'Largest batch: {max(len(b) for b in batches)}')


if __name__ == '__main__':
    main()
