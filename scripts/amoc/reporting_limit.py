#!/usr/bin/env python3
"""reporting_limit.py - the last year an AMOC run is reported: before its ice reaches the ends of its room.

Decision (Janosch, 2026-10-19): each region and scenario is reported until the first year in which more than 5 %
of the region's ice is in glaciers that lose ice at the end of their room that year: the flowline grid end (1.5
glacier lengths in front of the 2003 glacier) or the lowest Δh band (band_extension_glacier: 1500 m below the 2003 front,
or sea level), on land or into the sea (*_flow_gridend_outflow.dat > 0). From then on the glacier-by-glacier model
is unreliable: growing glaciers would merge, cross into other valleys or advance into the sea.

The share is summed over all batches of a region and scenario found under
<dirres>/monthly/<Region>/files/files_original/<GCM>/<scenario>/ (<region>_Volume_r1_<catchment>.dat with
<region>_<catchment>_flow_gridend_outflow.dat), from 2026 on.

Usage:
    python3 scripts/amoc/reporting_limit.py <dirres> [<dirres> ...] [--threshold 0.05] [--csv <folder>]
--csv writes <Region>_<GCM>_<scenario>_limit_share.csv (year, regional volume km3, share at a limit) per run.
"""

import argparse
import glob
import os
import re

import numpy as np

RGI = {'CentralEurope': '11', 'Scandinavia': '08'}


def read_dat(f):
    with open(f) as fh:
        rows = [l.split() for l in fh if l.strip()]
    years = np.array([int(float(x)) for x in rows[0][1:]])
    ids = [r[0] for r in rows[1:]]
    vals = np.nan_to_num(np.array([[float(x) for x in r[1:]] for r in rows[1:]]))
    return years, ids, vals


def read_outflow(f):
    """{id: outflow per year} from *_flow_gridend_outflow.dat (columns: id, bed, booking, years)"""
    out = {}
    with open(f) as fh:
        fh.readline()
        for line in fh:
            p = line.split()
            if p:
                out[p[0]] = np.array([float(x) for x in p[3:]])
    return out


def run_share(d):
    """years, regional volume, volume in glaciers at a limit, number of batches and glaciers, for one scenario folder"""
    years, vol, lim, nb, ng = None, None, None, 0, 0
    for vf in sorted(glob.glob(f'{d}/*_Volume_r1_*.dat')):
        m = re.match(r'(.+)_Volume_r1_(.+)\.dat$', os.path.basename(vf))
        of = f'{d}/{m.group(1)}_{m.group(2)}_flow_gridend_outflow.dat'
        y, ids, V = read_dat(vf)
        o = read_outflow(of) if os.path.exists(of) else {}
        at = np.array([o[g] > 0 if g in o else np.zeros(len(y), bool) for g in ids])
        if years is None:
            years, vol, lim = y, np.zeros(len(y)), np.zeros(len(y))
        elif not np.array_equal(y, years):
            raise SystemExit(f'{vf}: years differ from the other batches')
        vol += V.sum(axis=0)
        lim += (V * at).sum(axis=0)
        nb += 1
        ng += len(ids)
    return years, vol, lim, nb, ng


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('dirres', nargs='+')
    p.add_argument('--threshold', type=float, default=0.05)
    p.add_argument('--csv', help='folder for the per-year share of each run')
    a = p.parse_args()
    print(f'| Region (RGI ID) | Run | Batches | Glaciers | Reported until | Share at a limit then | Most at a limit |')
    print('|---|---|---|---|---|---|---|')
    for dirres in a.dirres:
        for d in sorted(glob.glob(f'{dirres}/monthly/*/files/files_original/*/*')):
            if not glob.glob(f'{d}/*_Volume_r1_*.dat'):
                continue
            reg, gcm, scen = d.split('/')[-5], d.split('/')[-2], d.split('/')[-1]
            y, vol, lim, nb, ng = run_share(d)
            share = np.where(vol > 0, lim / np.where(vol > 0, vol, 1), 0.)
            k = y >= 2026
            over = np.where(k & (share > a.threshold))[0]
            if len(over):
                last = y[over[0]] - 1
                then = f'{100 * share[over[0]]:.0f} % in {y[over[0]]}'
            else:
                last, then = y[-1], '—'
            imax = np.argmax(np.where(k, share, -1))
            print(f'| {reg} ({RGI.get(reg, "?")}) | {gcm} {scen} | {nb} | {ng} | {last} | {then} | '
                  f'{100 * share[imax]:.0f} % ({y[imax]}) |')
            if a.csv:
                os.makedirs(a.csv, exist_ok=True)
                with open(os.path.join(a.csv, f'{reg}_{gcm}_{scen}_limit_share.csv'), 'w') as fh:
                    fh.write('year,volume_km3,share_at_limit\n')
                    for i in range(len(y)):
                        fh.write(f'{y[i]},{vol[i]:.4f},{share[i]:.4f}\n')


if __name__ == '__main__':
    main()
