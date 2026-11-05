#!/usr/bin/env python3
"""check_gmip4_budget.py -- does the annual mass change of combined GMIP4 files match their monthly fluxes?

For every annual/monthly pair in a region folder: the yearly mass change against the sum of 12 monthly
(acc + refreeze - melt) minus that year's frontal ablation. The combined files follow the hydrological
year, so the month offset is fitted on 2027-2080; earlier years are avoided because GloGEM holds each
glacier's mass fixed until its outline date while still writing the monthly fluxes.

A period passes if its residual is within BUDGET_TOL of the period's budget or within MASS_TOL of the
2000 mass (remnant and near-balance periods, where the budget itself is close to zero). A pair also
fails on NaN annual mass or on mass_bsl > mass. Exit code 1 if anything fails.

usage: check_gmip4_budget.py REGION_FOLDER...
"""
import glob
import os
import sys

import netCDF4 as nc
import numpy as np

PERIODS = ((2013, 2026), (2026, 2101), (2101, 2200), (2200, 2300))
BUDGET_TOL = 0.02
MASS_TOL = 0.001


def series(ya, M, FA, ym, mm, smb, lag):
    """rows (year, mass change to the next label, budget of the 12 months starting lag months before Jan)"""
    out = []
    for i, Y in enumerate(ya[:-1]):
        idx0 = np.where((ym == Y) & (mm == 1))[0]
        if not len(idx0):
            continue
        s = idx0[0] + lag
        if s < 0 or s + 12 > len(smb):
            continue
        out.append((Y, M[i + 1] - M[i], np.nansum(smb[s:s + 12]) - np.nan_to_num(FA[i])))
    return np.array(out)


def check_pair(fa, fm):
    a = nc.Dataset(fa); m = nc.Dataset(fm)
    ya = np.array([t.year for t in nc.num2date(a['time'][:], a['time'].units, a['time'].calendar)])
    tm = nc.num2date(m['time'][:], m['time'].units, m['time'].calendar)
    ym = np.array([t.year for t in tm]); mm = np.array([t.month for t in tm])
    g = lambda d, v: np.ma.filled(d[v][:].astype(float), np.nan) * 1e-12   # Gt
    M = g(a, 'mass')
    FA = g(a, 'frontal_abl') if 'frontal_abl' in a.variables else np.zeros_like(M)
    BSL = g(a, 'mass_bsl') if 'mass_bsl' in a.variables else np.zeros_like(M)
    smb = g(m, 'acc') + g(m, 'refreeze') - g(m, 'melt')
    best = None
    for lag in range(-12, 13):
        s = series(ya, M, FA, ym, mm, smb, lag)
        w = (s[:, 0] >= 2027) & (s[:, 0] < 2081)
        if not w.any():
            w = s[:, 0] >= 2013
        r = np.nanmean(np.abs(s[w, 2] - s[w, 1]))
        if best is None or r < best[1]:
            best = (lag, r)
    s = series(ya, M, FA, ym, mm, smb, best[0])
    m2000 = M[np.argmin(np.abs(ya - 2000))]
    periods = {}
    for lo, hi in PERIODS:
        w = (s[:, 0] >= lo) & (s[:, 0] < hi)
        if w.sum() < 5:
            continue
        bud = s[w, 2].sum(); res = bud - s[w, 1].sum()
        ok = abs(res) <= BUDGET_TOL * abs(bud) or abs(res) <= MASS_TOL * m2000
        periods[lo] = (100 * res / abs(bud) if bud else 0.0, res, ok)
    problems = []
    if np.isnan(M).any():
        problems.append(f'{int(np.isnan(M).sum())} NaN in annual mass')
    if (BSL > M + 1e-12).any():
        problems.append(f'{int((BSL > M + 1e-12).sum())} years mass_bsl > mass')
    return best[0], periods, problems


def main(folders):
    failed = False
    for folder in folders:
        pairs = sorted(glob.glob(os.path.join(folder, 'GloGEMflow_rgi*_annual.nc')))
        worst, lags, bad = {}, set(), []
        for fa in pairs:
            tag = os.path.basename(fa).split('_', 2)[2].replace('_annual.nc', '')
            lag, periods, problems = check_pair(fa, fa.replace('_annual.nc', '_monthly.nc'))
            lags.add(lag)
            for lo, (pct, res, ok) in periods.items():
                if lo not in worst or abs(pct) > abs(worst[lo][0]):
                    worst[lo] = (pct, res, tag)
                if not ok:
                    bad.append(f'{tag} {lo}-{dict(PERIODS)[lo] - 1}: {pct:.2f} % ({res:+.4f} Gt)')
            bad += [f'{tag}: {p}' for p in problems]
        print(f'== {os.path.basename(folder)}: {len(pairs)} pairs, month offset {sorted(lags)}')
        for lo, hi in PERIODS:
            if lo in worst:
                pct, res, tag = worst[lo]
                print(f'   worst {lo}-{hi - 1}: {pct:7.2f} % of the budget ({res:+.4f} Gt) in {tag}')
        for b in bad:
            print('   FAIL', b)
        print('   ' + ('FAILED' if bad else 'OK'))
        failed |= bool(bad) or not pairs
    return 1 if failed else 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1:]))
