#!/usr/bin/env python3
"""make_amoc_configs.py - write one GloGEM config per region x scenario x batch for the AMOC runs.

The 7 AMOC scenarios of settings.pro (MIP='AMOC') by index: CESM (GCM 1) with
RCP26_045sv, RCP45_045sv, RCP85_045sv, RCP45_018sv, RCP85_018sv (1-5), and
GFDL_ESM2M (GCM 2) with ENS1_2degC_hos_Eref, ENS1_2degC_ref (6-7). One
scenario per job: rcp_batch=3 would silently drop a 4th scenario in a job.

--kind igmforcing: fixed geometry, Δh off, mass balance on bands below the
front (band_extension), per-band balance files (mb_elevation/belev_*.dat) for IGM.
--kind growth: changing geometry, flow model, every switch for growing glaciers
(flow_mb_elev_cap 'none', blow-up check by mass, outflow at the grid end,
dh_regrowth, band_extension, dh_reseed); growth_dh: the same on the Δh
parameterisation only (twin runs); growth_capall: with flow_mb_elev_cap 'all'. All three write the
decadal band output (hypsometry) and the flowline every 10 years (geometry/flowgrid_*.sav), and send
glaciers whose flow spin-up ends with A_flow below 1e-19 or the ELA bias at its 500 m clamp to the Δh
parameterisation.
Each kind needs its own --run-dir (the output names do not contain the kind).

The calibration must already be in <run-dir>/monthly/<Region>/calibration/.

Usage:
    python3 scripts/amoc/make_amoc_configs.py --kind igmforcing --run-dir <dirres> --out <config dir> \\
        [--regions centraleurope scandinavia] [--tag amocr6] [--end-year 3000] \\
        [--batches 5 12] [--scenarios 1 6]
"""

import argparse
import os

REGIONS = {  # catchment region name: (RGI number, region_id_loop, number of batches)
    'centraleurope': ('11', 14, 24),
    'scandinavia': ('08', 8, 16),
}
SCENARIOS = [  # (GCM index, scenario index, name)
    (1, 1, 'CESM_RCP26_045sv'), (1, 2, 'CESM_RCP45_045sv'), (1, 3, 'CESM_RCP85_045sv'),
    (1, 4, 'CESM_RCP45_018sv'), (1, 5, 'CESM_RCP85_018sv'),
    (2, 6, 'GFDL_ENS1_2degC_hos_Eref'), (2, 7, 'GFDL_ENS1_2degC_ref'),
]
GROWTH = ("frontal_ablation = 'n'\nflow_blowup_check = 'mass'\nflow_domain_end = 'outflow'\n"
          "flow_gridend_outflow = 'melt_if_land'\ndh_regrowth = 'y'\nband_extension = 'y'\ndh_reseed = 'y'\n"
          "write_mb_elevationbands = 'n'\nfull_output = 'n'\nwrite_netcdf = 'n'\nwrite_hypsometry_files = 'y'\n"
          "write_geometry_output = 'flow'\ngeometry_output_every = 10\n"
          "spinup_gate_aflow_min = 1d-19\nspinup_gate_ela_max = 499.9d0\n")
KINDS = {
    # fixed geometry needs find_startyear='n' too: otherwise glogem.pro switches glacier_retreat
    # on after each glacier's survey year
    'igmforcing': ("glacier_retreat = 'n'\nfind_startyear = 'n'\nuse_flow_model = 'n'\nband_extension = 'y'\n"
                   "frontal_ablation = 'n'\nwrite_mb_elevationbands = 'y'\nfull_output = 'n'\nwrite_netcdf = 'n'\n"),
    'growth': "use_flow_model = 'y'\nflow_mb_elev_cap = 'none'\n" + GROWTH,
    'growth_dh': "use_flow_model = 'n'\n" + GROWTH,
    'growth_capall': "use_flow_model = 'y'\nflow_mb_elev_cap = 'all'\n" + GROWTH,
}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--kind', required=True, choices=sorted(KINDS))
    p.add_argument('--run-dir', required=True, help='dirres of the runs')
    p.add_argument('--out', required=True, help='folder for the config files')
    p.add_argument('--regions', nargs='+', default=sorted(REGIONS), choices=sorted(REGIONS))
    p.add_argument('--tag', default='amocr6', help='batch tag: RGI<nn>_<region>_<tag>_batchNN.dat')
    p.add_argument('--end-year', type=int, default=3000)
    p.add_argument('--batches', nargs='+', type=int, help='batch numbers (default: all)')
    p.add_argument('--scenarios', nargs='+', type=int, help='scenario indices 1-7 (default: all)')
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    n = 0
    for region in a.regions:
        rginum, region_id, nbatch = REGIONS[region]
        for gi, ri, scen in SCENARIOS:
            if a.scenarios and ri not in a.scenarios:
                continue
            for b in range(1, nbatch + 1):
                if a.batches and b not in a.batches:
                    continue
                name = f'{a.kind}_{region}_{scen}_b{b:02d}'
                with open(os.path.join(a.out, name + '.pro'), 'w') as fh:
                    fh.write(f'; AMOC {a.kind}: {region} (RGI {rginum}), {scen}, batch {b:02d} '
                             f'- written by scripts/amoc/make_amoc_configs.py\n')
                    fh.write(f"dirres = '{os.path.join(a.run_dir, '')}'\n")
                    fh.write("RGIversion = '6'\ntime_resolution = 'monthly'\nMIP = 'AMOC'\n")
                    fh.write(f'region_id_loop = [{region_id}, {region_id}]\n')
                    fh.write(f"catchment_selection = '{region}_{a.tag}_batch{b:02d}'\n")
                    fh.write(f'GCM_model_idx = [{gi}]\nGCM_rcp_idx = [{ri}]\n')
                    fh.write(f'amoc_end_year = {a.end_year}\n')
                    fh.write(KINDS[a.kind])
                n += 1
    print(f'{n} configs in {a.out}')


if __name__ == '__main__':
    main()
