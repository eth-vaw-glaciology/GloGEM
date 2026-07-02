"""Data-reading and plotting helpers for visualise_test_results.ipynb.

Kept in a separate module so the notebook stays focused on the
run-through-the-results narrative rather than matplotlib boilerplate.
"""

import zipfile

import numpy as np
import matplotlib.pyplot as plt


def setup_style():
    """Grid on every axes, >=250 dpi output, Arial where available
    (falls back to DejaVu Sans on systems without Arial installed, e.g. most Linux)."""
    plt.rcParams['font.family'] = ['Arial', 'DejaVu Sans']
    plt.rcParams['axes.grid'] = True
    plt.rcParams['grid.alpha'] = 0.3
    plt.rcParams['savefig.dpi'] = 250


# ---------------------------------------------------------------------------
# Data readers
# ---------------------------------------------------------------------------

def read_calibration(path):
    with open(path) as f:
        header = f.readline()
        rows = [line.split() for line in f if line.strip()]
    return {
        'id':    np.array([r[0] for r in rows]),
        'ba':    np.array([float(r[1]) for r in rows]),
        'ela':   np.array([float(r[4]) for r in rows]),
        'aar':   np.array([float(r[5]) for r in rows]),
        'ddfs':  np.array([float(r[8]) for r in rows]),
        'ddfi':  np.array([float(r[9]) for r in rows]),
        'cprec': np.array([float(r[10]) for r in rows]),
        'toff':  np.array([float(r[11]) for r in rows]),
        'header': header,
    }


def read_series(path):
    with open(path) as f:
        header = f.readline().split()
        years = np.array([float(y) for y in header[1:]])
        ids, data = [], []
        for line in f:
            if not line.strip():
                continue
            p = line.split()
            ids.append(p[0])
            data.append([float(v) for v in p[1:]])
    return np.array(ids), years, np.array(data)


def read_band_geometry(path):
    with open(path) as f:
        lines = f.readlines()
    rows = [line.split() for line in lines[5:] if line.strip()]  # 5 header lines
    hstart = np.array([float(r[1]) for r in rows])
    thick = np.array([float(r[4]) for r in rows])       # initial (survey-date) ice thickness
    length_m = np.array([float(r[6]) for r in rows])    # cumulative along-flow distance
    elev = hstart + 5                                    # band midpoint elevation
    return {
        'elev': elev,
        'thick': thick,
        'bed_elev': elev - thick,
        'dist_km': length_m / 1000.,
    }


def read_hypso_evolution(zip_path, glacier_id, kind):
    # kind: 'hypso' (area per band per decade) or 'volume' (area*thickness)
    with zipfile.ZipFile(zip_path) as zf:
        name = next(n for n in zf.namelist() if n.endswith(f'{kind}_{glacier_id}.dat'))
        text = zf.read(name).decode()
    lines = text.splitlines()
    header_years = np.array([float(y) for y in lines[0].split()])
    n_cols = len(header_years) + 1
    # tokenize everything after the header by whitespace, ignoring original line
    # breaks — IDL's fixed-width printf wraps rows whose last (always-empty,
    # since tran[1] is never reached) decade column doesn't fit the format width
    data_tokens = ' '.join(lines[1:]).split()
    data = np.array([float(x) for x in data_tokens]).reshape(-1, n_cols)
    return header_years, data


def glacier_profile(glacier_id, geometry_path, hypso_zip):
    geo = read_band_geometry(geometry_path)
    years, area_data = read_hypso_evolution(hypso_zip, glacier_id, 'hypso')
    _, vol_data = read_hypso_evolution(hypso_zip, glacier_id, 'volume')
    # drop the row-label column (col 0) and the final decade (always unfilled
    # sentinel, since tran[1]=2100 is never itself simulated — GloGEM
    # hard-clamps tran[1]=2100 for standard forward runs and treats it as
    # exclusive, so the last calendar year actually simulated is 2099)
    decade_years = years[:-1]
    area = area_data[:, 1:-1]
    vol = vol_data[:, 1:-1]
    # When advance='y' (implied by glacier_retreat='y'), GloGEM prepends extra
    # placeholder bands below the terminus to allow for future advance, so the
    # model's internal band count exceeds the bundled geometry file's. These
    # are always the first rows written; strip them so indices line up 1:1
    # with the geometry file (they stay ice-free throughout in a retreat
    # scenario, so nothing of interest is lost).
    n_extra = area.shape[0] - len(geo['elev'])
    if n_extra > 0:
        area = area[n_extra:]
        vol = vol[n_extra:]
    with np.errstate(divide='ignore', invalid='ignore'):
        thick_decade = np.where(area > 0, vol / area, 0.)
    return geo, decade_years, thick_decade


def smooth(y, window=5):
    # simple moving average, edge-padded so the output stays the same length
    # and doesn't shrink or lag at the ends — for visual clarity only, the
    # unsmoothed values are what all the actual model physics uses
    if window < 3 or len(y) < window:
        return y
    pad = window // 2
    y_padded = np.pad(y, pad, mode='edge')
    return np.convolve(y_padded, np.ones(window) / window, mode='valid')


# ---------------------------------------------------------------------------
# Plots
# ---------------------------------------------------------------------------

def plot_annual_mb(yrs_d, mb_d, idx_al, idx_mo, plot_dir):
    fig, ax = plt.subplots(figsize=(8.2, 4.2))
    ax.plot(yrs_d, mb_d[idx_al], '-o', ms=3, color='#4682B4', label='Aletsch (daily)')
    ax.plot(yrs_d, mb_d[idx_mo], '-o', ms=3, color='#D25A1E', label='Morteratsch (daily)')
    ax.plot([1991, 2020], [-1.216, -1.216], ':', color='#4682B4', lw=1.5, label='Aletsch (Hugonnet et al. 2021)')
    ax.plot([1991, 2020], [-1.022, -1.022], ':', color='#D25A1E', lw=1.5, label='Morteratsch (Hugonnet et al. 2021)')
    ax.set_xlabel('Year'); ax.set_ylabel('Mass balance (m w.e.)'); ax.set_ylim(-5, 3)
    ax.set_title('Daily model: Annual mass balance 1991-2020')
    ax.legend(fontsize=9, loc='lower left')
    fig.tight_layout()
    fig.savefig(plot_dir / 'plot1_annual_mb.png')
    return fig


def plot_ela_aar(yrs_d, ela_d, aar_d, idx_al, plot_dir):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(9.6, 4.0))
    ax1.plot(yrs_d, ela_d[idx_al], 'k-o', ms=3)
    ax1.set_title('Equilibrium Line Altitude'); ax1.set_xlabel('Year'); ax1.set_ylabel('ELA (m a.s.l.)')
    ax2.plot(yrs_d, aar_d[idx_al], 'k--o', ms=3)
    ax2.set_title('Accumulation Area Ratio'); ax2.set_xlabel('Year'); ax2.set_ylabel('AAR (%)')
    fig.suptitle('Daily model: ELA and AAR - Aletschgletscher')
    fig.tight_layout()
    fig.savefig(plot_dir / 'plot2_ela_aar.png')
    return fig


def plot_daily_vs_monthly(yrs_d, mb_d, yrs_m, mb_m, idx_al, idx_mo, idx_al_m, idx_mo_m, plot_dir):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10.2, 4.3))
    ax1.plot(yrs_d, mb_d[idx_al], '-o', ms=3, color='#4682B4', label='Daily')
    ax1.plot(yrs_m, mb_m[idx_al_m], '--o', ms=3, color='#4682B4', label='Monthly')
    ax1.plot([1991, 2020], [-1.216, -1.216], 'k:', label='Geodetic (Hugonnet et al. 2021)')
    ax1.set_title('Aletschgletscher'); ax1.set_xlabel('Year'); ax1.set_ylabel('MB (m w.e.)'); ax1.set_ylim(-5, 3)
    ax1.legend(fontsize=9)

    ax2.plot(yrs_d, mb_d[idx_mo], '-o', ms=3, color='#D25A1E', label='Daily')
    ax2.plot(yrs_m, mb_m[idx_mo_m], '--o', ms=3, color='#D25A1E', label='Monthly')
    ax2.plot([1991, 2020], [-1.022, -1.022], 'k:', label='Geodetic (Hugonnet et al. 2021)')
    ax2.set_title('Morteratschgletscher'); ax2.set_xlabel('Year'); ax2.set_ylabel('MB (m w.e.)'); ax2.set_ylim(-5, 3)
    ax2.legend(fontsize=9)

    fig.suptitle('Annual mass balance: daily vs monthly (1991-2020)')
    fig.tight_layout()
    fig.savefig(plot_dir / 'plot3_daily_vs_monthly.png')
    return fig


def plot_calibrated_params(cal_d, cal_m, idx_al_c, idx_mo_c, idx_al_cm, idx_mo_cm, plot_dir):
    bar_labels = ['Al-d', 'Al-m', 'Mo-d', 'Mo-m']
    x = np.arange(4)
    ddfs  = [cal_d['ddfs'][idx_al_c],  cal_m['ddfs'][idx_al_cm],  cal_d['ddfs'][idx_mo_c],  cal_m['ddfs'][idx_mo_cm]]
    ddfi  = [cal_d['ddfi'][idx_al_c],  cal_m['ddfi'][idx_al_cm],  cal_d['ddfi'][idx_mo_c],  cal_m['ddfi'][idx_mo_cm]]
    cprec = [cal_d['cprec'][idx_al_c], cal_m['cprec'][idx_al_cm], cal_d['cprec'][idx_mo_c], cal_m['cprec'][idx_mo_cm]]
    colors = ['#4682B4', '#4682B4', '#D25A1E', '#D25A1E']

    fig, axes = plt.subplots(1, 3, figsize=(10.2, 4.4))
    for ax, vals, title, ylabel in zip(axes, [ddfs, ddfi, cprec],
                                        ['DDFsnow (mm/d/°C)', 'DDFice (mm/d/°C)', 'c_prec (-)'],
                                        ['mm/d/°C', 'mm/d/°C', '-']):
        ax.bar(x, vals, color=colors)
        ax.set_xticks(x); ax.set_xticklabels(bar_labels)
        ax.set_title(title); ax.set_ylabel(ylabel)
        ax.set_ylim(0, max(vals) * 1.2)

    fig.suptitle('Calibrated parameters (Al=Aletsch, Mo=Morteratsch, d=daily, m=monthly)')
    fig.text(0.5, 0.02, 'Aletsch', ha='right', color='#4682B4', fontweight='bold')
    fig.text(0.51, 0.02, 'Morteratsch', ha='left', color='#D25A1E', fontweight='bold')
    fig.tight_layout(rect=[0, 0.05, 1, 1])
    fig.savefig(plot_dir / 'plot4_calibrated_params.png')
    return fig


def plot_projection_mosaic(yrs_proj_d, area_d, vol_d, yrs_proj_m, area_m, vol_m,
                            idx_al_pd, idx_mo_pd, idx_al_pm, idx_mo_pm, plot_dir):
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 8.5), sharex=True)

    panels = [
        (axes[0, 0], area_d[idx_al_pd], area_m[idx_al_pm], '#4682B4', 'Aletsch — Area'),
        (axes[0, 1], area_d[idx_mo_pd], area_m[idx_mo_pm], '#D25A1E', 'Morteratsch — Area'),
        (axes[1, 0], vol_d[idx_al_pd],  vol_m[idx_al_pm],  '#4682B4', 'Aletsch — Volume'),
        (axes[1, 1], vol_d[idx_mo_pd],  vol_m[idx_mo_pm],  '#D25A1E', 'Morteratsch — Volume'),
    ]
    for ax, d_series, m_series, color, title in panels:
        ax.plot(yrs_proj_d, d_series, '-', color=color, label='Daily')
        ax.plot(yrs_proj_m, m_series, '--', color=color, label='Monthly')
        ax.set_title(title)
        ax.legend(fontsize=9)

    axes[1, 0].set_xlabel('Year'); axes[1, 1].set_xlabel('Year')
    axes[0, 0].set_ylabel('Area (km²)'); axes[1, 0].set_ylabel('Volume (km³)')

    fig.suptitle('Projected glacier area and volume 1991-2100 (GMIP4 MRI-ESM2-0 ssp126)')
    fig.tight_layout()
    fig.savefig(plot_dir / 'plot5_projected_area_volume.png')
    return fig


def _surface_line(bed, thick_raw, order, threshold=1.0):
    # bed (smoothed) + thickness (smoothed) guarantees surface >= bedrock
    # everywhere by construction, since a smoothed non-negative array stays
    # non-negative. Points below the thickness threshold become NaN so
    # matplotlib actually breaks the line there (a real gap, e.g. a nunatak)
    # instead of drawing a straight shortcut across it.
    thick_s = smooth(thick_raw[order])
    out = bed + thick_s
    out[thick_s <= threshold] = np.nan
    return out


def _plot_profile_panel(ax, geo, decade_years, thick_decade, title):
    order = np.argsort(geo['dist_km'])
    dist = geo['dist_km'][order]
    bed = smooth(geo['bed_elev'][order])  # single smoothed bedrock baseline, used everywhere below

    ax.plot(dist, bed, color='black', lw=0.6, label='Bedrock', zorder=3)

    ax.plot(dist, _surface_line(bed, geo['thick'], order), color='#1c3f6e', lw=2,
            label='~2003 (inventory)', zorder=3)

    for d in range(len(decade_years) - 1):
        ax.plot(dist, _surface_line(bed, thick_decade[:, d], order), color='0.65', lw=0.8,
                alpha=0.8, label='Every 10 yr' if d == 0 else None, zorder=2)

    ax.plot(dist, _surface_line(bed, thick_decade[:, -1], order), color='#c0392b', lw=2,
            label='2100 (final)', zorder=3)

    ax.set_xlim(left=0)
    ylo = min(bed.min(), ax.get_ylim()[0]) - 20
    ax.fill_between(dist, ylo, bed, color='0.85', zorder=1)
    ax.set_ylim(bottom=ylo + 20)

    ax.set_title(title)
    ax.set_xlabel('Distance from terminus (km)')
    ax.legend(fontsize=8)


def plot_glacier_profile(geo_al, geo_mo, decade_years, thick_decade_al, thick_decade_mo, plot_dir):
    fig, (axL, axR) = plt.subplots(1, 2, figsize=(11.5, 5.8), sharey=False)
    _plot_profile_panel(axL, geo_al, decade_years, thick_decade_al, 'Aletsch')
    _plot_profile_panel(axR, geo_mo, decade_years, thick_decade_mo, 'Morteratsch')
    axL.set_ylabel('Elevation (m a.s.l.)')
    fig.suptitle('Bedrock and glacier surface through time (daily model, GMIP4 MRI-ESM2-0 ssp126)')
    fig.tight_layout()
    fig.savefig(plot_dir / 'plot6_glacier_profile.png')
    return fig
