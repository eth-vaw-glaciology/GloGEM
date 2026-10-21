#!/usr/bin/env python3
"""valley_floor.py - the valley floor below each glacier, for GloGEM's snowline below the front.

GloGEM's option snowline_ext_valley reads one file per region, written by this script:
    <out>/valley_floor_rgi<version>_<region>.dat
<region> must be GloGEM's region name (column region_n of region_batch.dat, e.g. centralasiaW; case matters; the
sub-regions of RGI 10, 16 and 19 share one file). One row per glacier: GloGEM ID (last 5 digits of the RGI ID),
valley floor [m a.s.l.], terrain height at the start [m], path length used [m] and why the path ended (dist: the
set distance; edge: the edge of the terrain read around the glacier; sea). GloGEM uses the depth, start minus floor,
below its own front, so the two terrain models need not agree.

The path starts at the lowest point of the glacier's outline and runs strictly downhill along the valley: the
terrain (smoothed over 250 m) has its hollows filled, then the path always takes the steepest way down and crosses
filled flats (lakes, valley floors) by the shortest way to their outlet. It is cut after --distance metres (default
10 km) or where it reaches the sea; the valley floor is the lowest raw terrain height on it, never below 0 m.
Check the paths with --paths: a path can run onto another glacier (a tributary reaching its trunk glacier).

Terrain: Copernicus GLO-90 (heights above the EGM2008 geoid, as GloGEM's), 1-degree tiles downloaded once into
--dem-dir from the public AWS bucket (a region of about 100 tiles needs a few hundred MB); tiles that do not exist
are open sea. Glaciers within reach of the 180-degree line are left out (GloGEM then uses snowline_ext_depth).

usage:
  python3 valley_floor.py --outlines <RGI outlines (.shp/.gpkg)> --region <GloGEM region name, e.g. centralasiaW>
                          --rgi-version <6|7> --out <folder> --dem-dir <folder>
                          [--distance 10000] [--processes 8] [--ids <file with RGI or 5-digit IDs>]
                          [--paths <csv with the path points, for checking>]
Outlines: e.g. from OGGM: oggm.cfg.initialize_minimal(); oggm.utils.get_rgi_region_file('14', version='62')
(RGI 6.2, column RGIId) or version='70G' (RGI 7.0, column rgi_id). Needs internet access, geopandas, rasterio,
scipy and scikit-image (path to a separate scikit-image in SKIMAGE_DIR if it is not installed).
Exit status 2 if any glacier failed (the file is written without them).
"""
import argparse
import collections
import math
import multiprocessing as mp
import os
import sys
import urllib.error
import urllib.request

import numpy as np

SKIMAGE_DIR = os.environ.get('SKIMAGE_DIR', '')
if SKIMAGE_DIR:
    sys.path.insert(0, SKIMAGE_DIR)

import geopandas as gpd  # noqa: E402
import rasterio  # noqa: E402
from rasterio import features  # noqa: E402
from rasterio.enums import Resampling  # noqa: E402
from rasterio.merge import merge  # noqa: E402
from rasterio.transform import from_origin  # noqa: E402
from scipy.ndimage import gaussian_filter  # noqa: E402
from skimage.morphology import reconstruction  # noqa: E402

URL = 'https://copernicus-dem-90m.s3.amazonaws.com/{n}/{n}.tif'
RES = 3. / 3600.            # 3 arc seconds
M_PER_DEG = 111320.
MARGIN = 2000.              # terrain read this far beyond the distance [m]
SMOOTH = 250.               # smoothing of the terrain for the routing [m], as OGGM's 251 m window
NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

ARGS = None
_open = {}


def tile_name(lat, lon):
    return (f'Copernicus_DSM_COG_30_{"N" if lat >= 0 else "S"}{abs(lat):02d}_00_'
            f'{"E" if lon >= 0 else "W"}{abs(lon):03d}_00_DEM')


def fetch(lat, lon):
    """local path of one tile, downloaded if needed; None for open sea"""
    n = tile_name(lat, lon)
    tif, miss = os.path.join(ARGS.dem_dir, n + '.tif'), os.path.join(ARGS.dem_dir, n + '.missing')
    if os.path.exists(tif):
        return tif
    if os.path.exists(miss):
        return None
    try:
        with urllib.request.urlopen(URL.format(n=n), timeout=120) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            open(miss, 'w').close()
            return None
        raise
    tmp = tif + f'.part{os.getpid()}'
    with open(tmp, 'wb') as f:
        f.write(data)
    os.replace(tmp, tif)
    return tif


def window(w, s, e, n):
    """terrain covering w..e, s..n on the tiles' own 3-arc-second grid; open sea = 0"""
    srcs = []
    for lat in range(math.floor(s), math.floor(n) + 1):
        for lon in range(math.floor(w), math.floor(e) + 1):
            p = fetch(lat, lon)
            if p is not None:
                if p not in _open:
                    _open[p] = rasterio.open(p)
                srcs.append(_open[p])
    fx = fy = 0.
    if srcs:   # align with the tiles' pixel grid, so the values are not shifted
        fx = srcs[0].transform.c / RES - math.floor(srcs[0].transform.c / RES)
        fy = srcs[0].transform.f / RES - math.floor(srcs[0].transform.f / RES)
    w = (math.floor(w / RES - fx) + fx) * RES
    n = (math.ceil(n / RES - fy) + fy) * RES
    nx, ny = int(math.ceil((e - w) / RES)), int(math.ceil((n - s) / RES))
    tr = from_origin(w, n, RES, RES)
    if not srcs:
        return np.zeros((ny, nx)), tr
    z, tr = merge(srcs, bounds=(w, n - ny * RES, w + nx * RES, n), res=RES, nodata=-32767.,
                  resampling=Resampling.nearest)
    z = z[0].astype(float)
    z[(z <= -1000) | ~np.isfinite(z)] = 0.
    return z, tr


def fill(z):
    """hollows filled: every cell drains to the edge of the window or to the sea without going up"""
    seed = np.full(z.shape, z.max())
    seed[0, :], seed[-1, :], seed[:, 0], seed[:, -1] = z[0, :], z[-1, :], z[:, 0], z[:, -1]
    sea = z <= 0
    seed[sea] = z[sea]
    return reconstruction(seed, z, method='erosion')


def downhill(f, head, dy, dx, dmax):
    """path from head on the filled terrain f: steepest descent; across a flat the shortest way to its outlet"""
    ny, nx = f.shape
    step = {(a, b): math.hypot(a * dy, b * dx) for a, b in NB}
    path, dist = [head], [0.]
    i, j = head
    while dist[-1] < dmax:
        if i in (0, ny - 1) or j in (0, nx - 1):
            break
        best = None
        for a, b in NB:
            g = (f[i, j] - f[i + a, j + b]) / step[(a, b)]
            if g > 0 and (best is None or g > best[0]):
                best = (g, a, b)
        if best is not None:
            i, j = i + best[1], j + best[2]
            path.append((i, j)); dist.append(dist[-1] + step[(best[1], best[2])])
            continue
        # flat: breadth-first over cells of the same height to the nearest one with a lower neighbour or the edge
        level, prev, q, out = f[i, j], {(i, j): None}, collections.deque([(i, j)]), None
        while q and out is None:
            c = q.popleft()
            for a, b in NB:
                p = (c[0] + a, c[1] + b)
                if p in prev or not (0 <= p[0] < ny and 0 <= p[1] < nx) or f[p] != level:
                    continue
                prev[p] = c
                if p[0] in (0, ny - 1) or p[1] in (0, nx - 1) or any(
                        0 <= p[0] + a2 < ny and 0 <= p[1] + b2 < nx and f[p[0] + a2, p[1] + b2] < level
                        for a2, b2 in NB):
                    out = p
                    break
                q.append(p)
        if out is None:
            break
        hop = []
        while out != (i, j):
            hop.append(out); out = prev[out]
        for p in reversed(hop):
            path.append(p); dist.append(dist[-1] + step[(p[0] - i, p[1] - j)])
            i, j = p
    return np.array(path), np.array(dist)


def one(row):
    gid, geom = row
    try:
        w, s, e, n = geom.bounds
        lat0 = 0.5 * (s + n)
        dy = RES * M_PER_DEG
        dx = dy * math.cos(math.radians(lat0))
        my = (ARGS.distance + MARGIN) / M_PER_DEG
        mx = my / math.cos(math.radians(lat0))
        if w - mx < -180 or e + mx > 180:
            return gid, np.nan, np.nan, 0., 'skip180', None
        z, tr = window(w - mx, s - my, e + mx, n + my)
        mask = features.rasterize([(geom, 1)], out_shape=z.shape, transform=tr, all_touched=True).astype(bool)
        if not mask.any():
            raise ValueError('outline covers no terrain cell')
        sm = gaussian_filter(z, sigma=(SMOOTH / 2. / dy, SMOOTH / 2. / dx))
        head = np.unravel_index(np.argmin(np.where(mask, sm, np.inf)), z.shape)
        z0 = z[head]
        if z0 <= 0:
            return gid, 0., float(z0), 0., 'sea', None
        path, dist = downhill(fill(sm), head, dy, dx, ARGS.distance)
        zp = z[path[:, 0], path[:, 1]]
        stop = np.searchsorted(dist, ARGS.distance, side='right')
        reason = 'dist' if dist[-1] >= ARGS.distance else 'edge'
        sea = np.where(zp <= 0)[0]
        if len(sea) and sea[0] < stop:
            stop, reason = sea[0] + 1, 'sea'
        pts = None
        if ARGS.paths:
            r, c = path[:stop, 0], path[:stop, 1]
            pts = np.column_stack([dist[:stop], tr.c + (c + 0.5) * tr.a, tr.f + (r + 0.5) * tr.e, zp[:stop]])
        return gid, max(float(zp[:stop].min()), 0.), float(z0), float(dist[stop - 1]), reason, pts
    except Exception as ex:  # one bad glacier must not stop the region; reported at the end
        print(f'{gid}: {type(ex).__name__}: {ex}', flush=True)
        return gid, np.nan, np.nan, 0., 'failed', None


def init(args):
    global ARGS
    ARGS = args


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--outlines', required=True)
    ap.add_argument('--region', required=True)
    ap.add_argument('--rgi-version', required=True, choices=['6', '7'])
    ap.add_argument('--out', required=True)
    ap.add_argument('--dem-dir', required=True)
    ap.add_argument('--distance', type=float, default=10000.)
    ap.add_argument('--processes', type=int, default=1)
    ap.add_argument('--ids', default='')
    ap.add_argument('--paths', default='', help='also write the path points to this CSV (for checking)')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    os.makedirs(args.dem_dir, exist_ok=True)

    g = gpd.read_file(args.outlines).to_crs('EPSG:4326')
    col = {'6': 'RGIId', '7': 'rgi_id'}[args.rgi_version]
    if col not in g.columns:
        sys.exit(f'--rgi-version {args.rgi_version} expects the ID column {col}, which the outlines do not have')
    g['gid'] = g[col].astype(str).str[-5:]
    if args.ids:
        want = {line.strip()[-5:].zfill(5) for line in open(args.ids)
                if line.strip() and line.strip()[-1].isdigit()}
        g = g[g.gid.isin(want)]
        if len(want - set(g.gid)):
            print(f'NOTE: {len(want - set(g.gid))} IDs of {args.ids} are not in the outlines', flush=True)
    rows = list(zip(g.gid, g.geometry))
    print(f'{len(rows)} glaciers, distance {args.distance:.0f} m', flush=True)

    init(args)
    if args.processes > 1:
        # download the tiles first, one process, so the workers only read
        for _, geom in rows:
            w, s, e, n = geom.bounds
            my = (args.distance + MARGIN) / M_PER_DEG
            mx = my / math.cos(math.radians(0.5 * (s + n)))
            if w - mx < -180 or e + mx > 180:
                continue
            for lat in range(math.floor(s - my), math.floor(n + my) + 1):
                for lon in range(math.floor(w - mx), math.floor(e + mx) + 1):
                    fetch(lat, lon)
        with mp.Pool(args.processes, initializer=init, initargs=(args,)) as pool:
            res = pool.map(one, rows, chunksize=20)
    else:
        res = [one(r) for r in rows]

    fn = os.path.join(args.out, f'valley_floor_rgi{args.rgi_version}_{args.region}.dat')
    with open(fn, 'w') as f:
        f.write(f'ID  floor_m  start_m  path_m  end   (scripts/valley_floor.py, distance {args.distance:.0f} m, '
                'Copernicus GLO-90)\n')
        for gid, zf, z0, d, why, _ in sorted(res, key=lambda r: r[0]):
            if np.isfinite(zf):
                f.write(f'{gid} {zf:8.1f} {z0:8.1f} {d:8.0f} {why}\n')
    if args.paths:
        with open(args.paths, 'w') as f:
            f.write('id,dist_m,lon,lat,z\n')
            for r in sorted(res, key=lambda r: r[0]):
                if r[5] is not None:
                    for d, lo, la, zz in r[5]:
                        f.write(f'{r[0]},{d:.0f},{lo:.5f},{la:.5f},{zz:.1f}\n')
    failed = [r[0] for r in res if r[4] == 'failed']
    skipped = [r[0] for r in res if r[4] == 'skip180']
    print(f'wrote {fn}: {len(res) - len(failed) - len(skipped)} glaciers', flush=True)
    if skipped:
        print(f'left out, within reach of the 180-degree line: {len(skipped)} ({" ".join(skipped[:20])})', flush=True)
    if failed:
        print(f'FAILED: {len(failed)} glaciers ({" ".join(failed[:20])})', flush=True)
        sys.exit(2)


if __name__ == '__main__':
    main()
