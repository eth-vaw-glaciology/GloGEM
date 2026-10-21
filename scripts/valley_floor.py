#!/usr/bin/env python3
"""valley_floor.py - the valley floor below each glacier, for GloGEM's snowline below the front.

GloGEM's option snowline_ext_valley reads one file per region, written by this script:
    <out>/valley_floor_rgi<version>_<region>.dat
with one row per glacier: GloGEM ID (last 5 digits of the RGI ID), valley floor [m a.s.l.], terrain height at the
start [m], path length used [m] and why the path ended (dist, edge, sea).

For each glacier the path starts at the lowest point of its outline and follows the valley downhill, as OGGM's
downstream lines do (Maussion et al., 2019): the cheapest route to the edge of a map around the glacier, with the
cost of a step growing with the 8th power of the (smoothed) terrain height, so it keeps to the valley bottom. The
path is cut after --distance metres (default 10 km), or where it reaches the sea; the valley floor is the lowest raw
terrain height on it, never below 0 m.

Terrain: Copernicus GLO-90 (heights above the EGM2008 geoid, as GloGEM's), 1-degree tiles downloaded once into
--dem-dir from the public AWS bucket; tiles that do not exist are open sea.

usage:
  python3 -I valley_floor.py --outlines <RGI outlines (.shp/.gpkg)> --region <GloGEM region name, e.g. centralasiaW>
                             --rgi-version <6|7> --out <folder> --dem-dir <folder>
                             [--distance 10000] [--processes 8] [--ids <file with RGI or 5-digit IDs>]
                             [--paths <csv with the path points, for checking>]
Outlines: e.g. from OGGM, oggm.utils.get_rgi_region_file('14', version='62').
Needs geopandas, rasterio, scipy and scikit-image (skimage.graph.MCP_Geometric).
"""
import argparse
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
from scipy.ndimage import distance_transform_edt, gaussian_filter  # noqa: E402
from skimage.graph import MCP_Geometric  # noqa: E402

URL = 'https://copernicus-dem-90m.s3.amazonaws.com/{n}/{n}.tif'
RES = 3. / 3600.            # 3 arc seconds
M_PER_DEG = 111320.
MARGIN = 2000.              # map reaches this far beyond the distance [m]
SMOOTH = 250.               # smoothing of the terrain for the routing [m], as OGGM's 251 m window

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
        if e.code in (403, 404):
            open(miss, 'w').close()
            return None
        raise
    tmp = tif + f'.part{os.getpid()}'
    with open(tmp, 'wb') as f:
        f.write(data)
    os.replace(tmp, tif)
    return tif


def window(w, s, e, n):
    """terrain on a regular 3-arc-second grid covering w..e, s..n; open sea = 0"""
    srcs = []
    for lat in range(math.floor(s), math.floor(n) + 1):
        for lon in range(math.floor(w), math.floor(e) + 1):
            p = fetch(lat, lon)
            if p is not None:
                if p not in _open:
                    _open[p] = rasterio.open(p)
                srcs.append(_open[p])
    w, n = math.floor(w / RES) * RES, math.ceil(n / RES) * RES
    nx, ny = int(math.ceil((e - w) / RES)), int(math.ceil((n - s) / RES))
    tr = from_origin(w, n, RES, RES)
    if not srcs:
        return np.zeros((ny, nx)), tr
    z, tr = merge(srcs, bounds=(w, n - ny * RES, w + nx * RES, n), res=RES, nodata=-32767., resampling=Resampling.nearest)
    z = z[0].astype(float)
    z[(z <= -1000) | ~np.isfinite(z)] = 0.
    return z, tr


def one(row):
    gid, geom = row
    try:
        w, s, e, n = geom.bounds
        lat0 = 0.5 * (s + n)
        dy = RES * M_PER_DEG
        dx = dy * math.cos(math.radians(lat0))
        m = ARGS.distance + MARGIN
        z, tr = window(w - m / (M_PER_DEG * math.cos(math.radians(lat0))), s - m / M_PER_DEG,
                       e + m / (M_PER_DEG * math.cos(math.radians(lat0))), n + m / M_PER_DEG)
        mask = features.rasterize([(geom, 1)], out_shape=z.shape, transform=tr, all_touched=True).astype(bool)
        if not mask.any():
            return gid, np.nan, np.nan, 0., 'none', None
        sm = gaussian_filter(z, sigma=(SMOOTH / 2. / dy, SMOOTH / 2. / dx))
        k = np.argmin(np.where(mask, sm, np.inf))
        head = np.unravel_index(k, z.shape)
        z0 = z[head]
        if z0 <= 0:
            return gid, 0., z0, 0., 'sea', None
        cost = np.clip(sm, 1., None) ** 8 + distance_transform_edt(~mask)
        mcp = MCP_Geometric(cost, fully_connected=True, sampling=(dy, dx))
        costs, _ = mcp.find_costs([head])
        edge = np.zeros(z.shape, bool)
        edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
        end = np.unravel_index(np.argmin(np.where(edge, costs, np.inf)), z.shape)
        path = np.array(mcp.traceback(end))
        step = np.hypot(np.diff(path[:, 0]) * dy, np.diff(path[:, 1]) * dx)
        dist = np.concatenate([[0.], np.cumsum(step)])
        zp = z[path[:, 0], path[:, 1]]
        sea = np.where(zp <= 0)[0]
        stop = np.searchsorted(dist, ARGS.distance, side='right')
        reason = 'dist' if stop < len(dist) else 'edge'
        if len(sea) and sea[0] < stop:
            stop, reason = sea[0] + 1, 'sea'
        pts = None
        if ARGS.paths:
            r, c = path[:stop, 0], path[:stop, 1]
            pts = np.column_stack([dist[:stop], tr.c + (c + 0.5) * tr.a, tr.f + (r + 0.5) * tr.e, zp[:stop]])
        return gid, max(float(zp[:stop].min()), 0.), float(z0), float(dist[stop - 1]), reason, pts
    except Exception as ex:  # one bad glacier must not stop the region
        print(f'{gid}: {type(ex).__name__}: {ex}', flush=True)
        return gid, np.nan, np.nan, 0., 'none', None


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
    col = 'RGIId' if 'RGIId' in g.columns else 'rgi_id'
    g['gid'] = g[col].astype(str).str[-5:]
    if args.ids:
        want = {line.strip()[-5:] for line in open(args.ids) if line.strip() and line.strip()[-1].isdigit()}
        g = g[g.gid.isin(want)]
    rows = list(zip(g.gid, g.geometry))
    print(f'{len(rows)} glaciers, distance {args.distance:.0f} m', flush=True)

    init(args)
    if args.processes > 1:
        # download the tiles first, one process, so the workers only read
        for _, geom in rows:
            w, s, e, n = geom.bounds
            my = (args.distance + MARGIN) / M_PER_DEG
            mx = my / math.cos(math.radians(0.5 * (s + n)))
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
    bad = sum(1 for r in res if not np.isfinite(r[1]))
    print(f'wrote {fn}: {len(res) - bad} glaciers, {bad} without a floor', flush=True)


if __name__ == '__main__':
    main()
