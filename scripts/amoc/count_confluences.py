#!/usr/bin/env python3
"""Which glaciers would run into another one if they advanced (AMOC plan A6/C6)?

usage: count_confluences.py <line dir> <RGI region, e.g. 11> <GloGEM band dir>

Reads lines_rgi<reg>.csv, glaciers_rgi<reg>.csv and outlines_rgi<reg>.gpkg of oggm_valley_lines.py
and, per glacier, follows its valley line down from the front (distance along the line):
  hit   first point inside the outline of another glacier of today (that glacier, distance,
        elevation drop below the front); 0 m means it touches the other glacier at its front
  join  first point where the line joins another glacier's valley line and runs on with it for
        JOIN_RUN m (both glaciers advancing would then share the valley); distance along both lines
  sea   first point at sea level (z <= SEA_Z)
Lines end at the edge of OGGM's map (160 grid cells around the glacier), so every count is "within
the map": contacts further down are missed.
Writes confluence_rgi<reg>.csv and prints a summary with the ice volume (Farinotti 2019, from the
header of the GloGEM band files) of the glaciers concerned.
"""
import os
import re
import sys

import geopandas as gpd
import numpy as np
import pandas as pd
import shapely

JOIN_TOL_MIN = 100.     # m; lines closer than max(this, JOIN_TOL_DX x the coarser map dx) count as joined
JOIN_TOL_DX = 1.5
JOIN_RUN = 500.         # m the lines must stay together after the junction (or to the end of the line)
SEA_Z = 1.              # m
BINS = [0., 1000., 2000., 5000., 10000., np.inf]
BIN_NAMES = ['< 1 km', '1-2 km', '2-5 km', '5-10 km', '> 10 km']


def band_volume(band_dir, rgi_id):
    f = os.path.join(band_dir, rgi_id.split('.')[1] + '.dat')
    try:
        with open(f) as fh:
            for _ in range(6):
                m = re.match(r'\s*Volume \(km3\):\s*([-0-9.eE+]+)', fh.readline())
                if m:
                    return float(m.group(1))
    except FileNotFoundError:
        pass
    return np.nan


def first_hit(line, own, outlines, tree):
    best = (None, np.inf)
    for k in tree.query(line, predicate='intersects'):
        oid = outlines.rgi_id.iat[k]
        if oid == own:
            continue
        inter = shapely.intersection(line, outlines.geometry.iat[k])
        c = shapely.get_coordinates(inter)
        if len(c):
            d = shapely.line_locate_point(line, shapely.points(c)).min()
            if d < best[1]:
                best = (oid, d)
    return best


def first_join(pts, dist, own, dx_own, lines, dxs, tree):
    best = (None, np.inf, np.nan)
    line = shapely.linestrings(pts)
    for k in tree.query(line, predicate='dwithin', distance=max(JOIN_TOL_MIN, JOIN_TOL_DX * 200.)):
        oid = lines.index[k]
        if oid == own:
            continue
        tol = max(JOIN_TOL_MIN, JOIN_TOL_DX * max(dx_own, dxs[oid]))
        near = shapely.distance(shapely.points(pts), lines.geometry.iat[k]) <= tol
        for i in np.flatnonzero(near):
            if dist[i] >= best[1]:
                break
            run = (dist >= dist[i]) & (dist <= dist[i] + JOIN_RUN)
            if near[run].all():
                best = (oid, dist[i], shapely.line_locate_point(lines.geometry.iat[k],
                                                                shapely.points(pts[i])))
                break
    return best


def main(ldir, reg, band_dir):
    pts = pd.read_csv(os.path.join(ldir, f'lines_rgi{reg}.csv'))
    gl = pd.read_csv(os.path.join(ldir, f'glaciers_rgi{reg}.csv')).set_index('rgi_id')
    outl = gpd.read_file(os.path.join(ldir, f'outlines_rgi{reg}.gpkg'))
    otree = shapely.STRtree(outl.geometry.values)
    by = {g: d.sort_values('k') for g, d in pts.groupby('rgi_id')}
    lines = gpd.GeoSeries({g: shapely.linestrings(d[['x', 'y']].values) for g, d in by.items()})
    ltree = shapely.STRtree(lines.values)
    dxs = gl.map_dx.to_dict()

    rows = []
    for g in gl.index:
        r = dict(rgi_id=g, area_km2=gl.area_km2[g], volume_km3=band_volume(band_dir, g),
                 term_type=gl.term_type[g], line=g in by)
        if g in by:
            d = by[g]
            xy, dist, z = d[['x', 'y']].values, d.dist_m.values, d.z.values
            line = lines[g]
            hid, hd = first_hit(line, g, outl, otree)
            jid, jd, jdo = first_join(xy, dist, g, dxs[g], lines, dxs, ltree)
            sea = np.flatnonzero(z <= SEA_Z)
            r.update(length_m=dist[-1], z_front=z[0], z_end=z[-1],
                     hit_id=hid, hit_m=hd if hid else np.nan, hit_dz=z[0] - np.interp(hd, dist, z) if hid else np.nan,
                     join_id=jid, join_m=jd if jid else np.nan, join_other_m=jdo,
                     join_dz=z[0] - np.interp(jd, dist, z) if jid else np.nan,
                     sea_m=dist[sea[0]] if len(sea) else np.nan)
        rows.append(r)
    df = pd.DataFrame(rows)
    df = df.round(dict(area_km2=4, volume_km3=6, length_m=1, z_front=1, z_end=1, hit_m=1, hit_dz=1, join_m=1,
                       join_other_m=1, join_dz=1, sea_m=1))
    df.to_csv(os.path.join(ldir, f'confluence_rgi{reg}.csv'), index=False)
    summary(df, reg)


def summary(df, reg):
    v = df.volume_km3.fillna(0.)
    V, N = v.sum(), len(df)
    ok = df.line.astype(bool)
    print(f'\nRGI {reg}: {N} glaciers, {V:.1f} km3; valley line for {ok.sum()} '
          f'(median length {df.length_m[ok].median() / 1000:.1f} km, 10th percentile '
          f'{df.length_m[ok].quantile(0.1) / 1000:.1f} km)')
    both = df.join_other_m.where(df.join_id.notna())
    cases = [('runs into another glacier (its outline today)', df.hit_m.where(df.hit_id.notna())),
             ('joins another glacier\'s valley line (advance of this glacier)', df.join_m.where(df.join_id.notna())),
             ('  same, both glaciers must reach the junction (larger of the two advances)',
              np.fmax(df.join_m.where(df.join_id.notna()), both)),
             ('reaches sea level', df.sea_m)]
    print('| distance below the front | ' + ' | '.join(BIN_NAMES) + ' | total |')
    print('|---|' + '---|' * (len(BIN_NAMES) + 1))
    for name, d in cases:
        cells = []
        for lo, hi in zip(BINS[:-1], BINS[1:]):
            m = (d >= lo) & (d < hi)
            cells.append(f'{m.sum()} ({100 * v[m].sum() / V:.0f} %)')
        m = d.notna()
        print(f'| {name} | ' + ' | '.join(cells) + f' | {m.sum()} ({100 * v[m].sum() / V:.0f} %) |')
    # who is involved: the glaciers that run into another, the glaciers they reach, pairs of larger glaciers
    g = df.set_index('rgi_id')
    for d in (1000., 2000., 5000.):
        s = df[df.hit_m < d]
        recv = g.loc[s.hit_id.unique()]
        nbig = int(((s.area_km2.values >= 1) & (g.area_km2.reindex(s.hit_id).values >= 1)).sum())
        print(f'runs into another glacier within {d / 1000:.0f} km: {len(s)} glaciers ({s.volume_km3.sum():.2f} km3,'
              f' median {s.area_km2.median():.3f} km2, {int((s.area_km2 >= 1).sum())} of at least 1 km2) reach {len(recv)}'
              f' glaciers ({recv.volume_km3.sum():.1f} km3); pairs of glaciers both of at least 1 km2: {nbig}')
    both = np.fmax(df.join_m, df.join_other_m)
    for d in (1000., 2000., 5000.):
        s = df[both < d]
        pa = g.area_km2.reindex(s.join_id).values
        big = s[(s.area_km2.values >= 1) & (pa >= 1)]
        print(f'share a valley if both advance less than {d / 1000:.0f} km: {len(s)} glaciers ({s.volume_km3.sum():.1f} km3);'
              f' both of at least 1 km2: {len(big)} ({big.volume_km3.sum():.1f} km3)')
    t = df.hit_m.where(df.hit_id.notna()) <= 1.
    print(f'touching another glacier at the front already: {t.sum()} glaciers ({100 * v[t].sum() / V:.1f} % of the ice)')


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
