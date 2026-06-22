#!/usr/bin/env python3
"""
create_batches.py  —  split all Alpine glacier IDs into N catchment files.

Reads the authoritative full-Alps ID list from the completed dhdt run, then
writes N catchment files in the standard GloGEM format so that N IDL processes
can run in parallel (one batch each).

Output: /itet-stor/jabeer/glogem/data/catchments/RGI11_alps_batch{01..NN}.dat

Usage:
    python scripts/create_batches.py             # 16 batches (default)
    python scripts/create_batches.py --n 8       # 8 batches
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
    parser.add_argument('--n', type=int, default=16, metavar='N_BATCHES',
                        help='Number of parallel batches (default: 16)')
    args = parser.parse_args()
    n = args.n

    # Read glacier IDs from dhdt Area output (authoritative full-Alps list)
    ids = []
    with open(DHDT_AREA) as fh:
        fh.readline()   # skip header
        for line in fh:
            parts = line.split()
            if parts:
                ids.append(parts[0])   # 5-digit RGI ID, e.g. '02596'

    total = len(ids)
    print(f'Total glaciers: {total}')

    # Split into n batches, distributing the remainder across the first batches
    base = total // n
    rem  = total % n
    batches, start = [], 0
    for i in range(n):
        size = base + (1 if i < rem else 0)
        batches.append(ids[start:start + size])
        start += size

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
