#!/usr/bin/env python3
"""OGGM valley lines below the glaciers of an RGI region (AMOC plan A6).

usage:
  oggm_valley_lines.py extract <region tar> <work dir>
  oggm_valley_lines.py lines <work dir> <RGI region, e.g. 11> <out dir> [processes]

extract  unpacks one archive of OGGM's preprocessed glacier directories (RGI 6.2, level 2,
         elevation-band flowlines, e.g. border 160) into <work dir>/per_glacier/. The server's
         pickles (*.pkl) are never unpacked; OGGM recomputes them here from the CSV, netCDF and
         GeoTIFF files. Only regular files inside each glacier's own folder are written.
lines    runs OGGM's own tasks on every glacier (fixed_dx_elevation_band_flowline,
         compute_downstream_line, compute_downstream_bedshape) and writes to <out dir>:
           lines_rgi<reg>.csv      one row per point of each valley line: rgi_id, k, dist_m (along
                                   the line from the glacier), x, y (EPSG:3035, m), lon, lat,
                                   z (smoothed terrain, m), w0 (bottom width of OGGM's trapezoid, m)
           glaciers_rgi<reg>.csv   one row per glacier: area, terminus type, DEM source, map grid,
                                   line length, start and end elevation, status
           outlines_rgi<reg>.gpkg  the RGI 6.2 outlines in EPSG:3035
         Lines are also computed below lake- and sea-terminating glaciers.

Needs OGGM 1.6 and scikit-image (OGGM routes the line with skimage.graph.route_through_array).
Run with python -I; scikit-image is taken from SKIMAGE_DIR if it is not installed.
"""
import io
import os
import re
import sys
import tarfile

import numpy as np
import pandas as pd

SKIMAGE_DIR = '/scratch_net/vierzack04/jabeer/pydeps/skimage024'
EPSG_OUT = 'EPSG:3035'
RGI_ID = re.compile(r'RGI60-\d\d\.\d{5}')

try:
    import skimage  # noqa: F401
except ImportError:
    sys.path.insert(0, SKIMAGE_DIR)


def extract(region_tar, work):
    n = 0
    with tarfile.open(region_tar, mode='r:') as outer:
        for m in outer.getmembers():
            if not (m.isfile() and m.name.endswith('.tar.gz')):
                continue
            rgi_id = os.path.basename(m.name)[:-len('.tar.gz')]
            if not RGI_ID.fullmatch(rgi_id):
                raise ValueError(f'unexpected member {m.name!r}')
            dest = os.path.join(work, 'per_glacier', rgi_id[:8], rgi_id[:11])
            data = outer.extractfile(m).read()
            with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as inner:
                keep = []
                for im in inner.getmembers():
                    parts = im.name.split('/')
                    if parts[0] != rgi_id or '..' in parts or im.name.startswith('/'):
                        raise ValueError(f'{rgi_id}: unexpected path {im.name!r}')
                    if not (im.isfile() or im.isdir()):
                        raise ValueError(f'{rgi_id}: not a file or folder: {im.name!r}')
                    if im.name.endswith('.pkl'):
                        continue
                    keep.append(im)
                inner.extractall(dest, members=keep, filter='data')
            n += 1
    print(f'{region_tar}: {n} glaciers unpacked')


def lines(work, reg, out, nproc):
    from oggm import cfg, workflow
    cfg.initialize_minimal(logging_level='WARNING')
    cfg.PATHS['working_dir'] = work
    cfg.PARAMS['use_multiprocessing'] = nproc > 1
    cfg.PARAMS['mp_processes'] = nproc
    cfg.PARAMS['continue_on_error'] = True

    top = os.path.join(work, 'per_glacier', f'RGI60-{reg}')
    ids = sorted(g for sub in sorted(os.listdir(top)) for g in os.listdir(os.path.join(top, sub))
                 if RGI_ID.fullmatch(g))
    gdirs = workflow.init_glacier_directories(ids)
    res = workflow.execute_entity_task(valley_line, gdirs)
    outl = workflow.execute_entity_task(outline_wkb, gdirs)

    import geopandas as gpd
    import shapely
    pts, rows = [], []
    for gdir, r in zip(gdirs, res):
        if r is None:
            st = [gdir.get_task_status(t) for t in ('fixed_dx_elevation_band_flowline',
                                                     'compute_downstream_line',
                                                     'compute_downstream_bedshape', 'valley_line')]
            rows.append(dict(base_record(gdir), status='failed: ' + ' | '.join(str(s) for s in st)))
        else:
            p, rec = r
            pts.append(p)
            rows.append(rec)
    os.makedirs(out, exist_ok=True)
    pts = pd.concat(pts).round(dict(dist_m=2, x=2, y=2, lon=6, lat=6, z=2, w0=2))
    pts.to_csv(os.path.join(out, f'lines_rgi{reg}.csv'), index=False)
    pd.DataFrame(rows).to_csv(os.path.join(out, f'glaciers_rgi{reg}.csv'), index=False)
    ok = [(g.rgi_id, w) for g, w in zip(gdirs, outl) if w is not None]
    gpd.GeoDataFrame(dict(rgi_id=[i for i, _ in ok]),
                     geometry=[shapely.from_wkb(w) for _, w in ok], crs=EPSG_OUT
                     ).to_file(os.path.join(out, f'outlines_rgi{reg}.gpkg'), driver='GPKG')
    print(f'RGI {reg}: {len(gdirs)} glaciers, {len(pts)} lines, {len(ok)} outlines')


def base_record(gdir):
    with open(gdir.get_filepath('dem_source')) as fh:
        dem = fh.readline().strip()
    return dict(rgi_id=gdir.rgi_id, area_km2=gdir.rgi_area_km2, term_type=gdir.terminus_type,
                dem_source=dem, map_dx=gdir.grid.dx, map_nx=gdir.grid.nx, map_ny=gdir.grid.ny)


def _entity_task(f):
    import logging
    from oggm import entity_task
    return entity_task(logging.getLogger(__name__))(f)


@_entity_task
def valley_line(gdir):
    """OGGM's valley line and trapezoid below one glacier, as a table of points and a summary row."""
    from oggm import tasks
    from pyproj import Transformer
    gdir.is_tidewater = False
    tasks.fixed_dx_elevation_band_flowline(gdir)
    tasks.compute_downstream_line(gdir)
    tasks.compute_downstream_bedshape(gdir)
    d = gdir.read_pickle('downstream_line')   # written by OGGM in this run
    i, j = np.array(d['downstream_line'].xy)
    x, y = gdir.grid.ij_to_crs(i, j)
    lon, lat = Transformer.from_crs(gdir.grid.proj.srs, 'EPSG:4326', always_xy=True).transform(x, y)
    X, Y = Transformer.from_crs('EPSG:4326', EPSG_OUT, always_xy=True).transform(lon, lat)
    dist = np.r_[0., np.cumsum(np.hypot(np.diff(x), np.diff(y)))]
    z = np.asarray(d['surface_h'], dtype=float)
    p = pd.DataFrame(dict(rgi_id=gdir.rgi_id, k=np.arange(len(x)), dist_m=dist, x=X, y=Y, lon=lon,
                          lat=lat, z=z, w0=np.asarray(d['w0s'], dtype=float)))
    rec = dict(base_record(gdir), line_dx=float(np.median(np.diff(dist))), n_points=len(x),
               length_m=float(dist[-1]), z_start=float(z[0]), z_end=float(z[-1]), status='ok')
    return p, rec


@_entity_task
def outline_wkb(gdir):
    """The glacier's RGI outline in EPSG_OUT, as WKB."""
    return gdir.read_shapefile('outlines').to_crs(EPSG_OUT).geometry.iloc[0].wkb


if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'extract':
        extract(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 5 and sys.argv[1] == 'lines':
        lines(sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]) if len(sys.argv) > 5 else 1)
    else:
        sys.exit(__doc__)
