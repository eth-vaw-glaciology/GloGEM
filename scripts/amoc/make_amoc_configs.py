#!/usr/bin/env python3
"""make_amoc_configs.py - write one GloGEM config per region x scenario x batch for the AMOC runs.

The 7 AMOC scenarios of settings.pro (MIP='AMOC') by index: CESM (GCM 1) with
RCP26_045sv, RCP45_045sv, RCP85_045sv, RCP45_018sv, RCP85_018sv (1-5), and
GFDL_ESM2M (GCM 2) with ENS1_2degC_hos_Eref, ENS1_2degC_ref (6-7). One
scenario per job: rcp_batch=3 would silently drop a 4th scenario in a job.

--kind igmforcing: fixed geometry, Δh off, mass balance on bands below the
front (band_extension), per-band balance files (mb_elevation/belev_*.dat) for IGM.

The calibration must already be in <run-dir>/monthly/<Region>/calibration/.

Usage:
    python3 scripts/amoc/make_amoc_configs.py --kind igmforcing --run-dir <dirres> --out <config dir> \\
        [--regions centraleurope scandinavia] [--tag amocr6] [--end-year 3000]
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
KINDS = {
    'igmforcing': ("glacier_retreat = 'n'\nuse_flow_model = 'n'\nband_extension = 'y'\n"
                   "write_mb_elevationbands = 'y'\nfull_output = 'n'\nwrite_netcdf = 'n'\n"),
}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--kind', required=True, choices=sorted(KINDS))
    p.add_argument('--run-dir', required=True, help='dirres of the runs')
    p.add_argument('--out', required=True, help='folder for the config files')
    p.add_argument('--regions', nargs='+', default=sorted(REGIONS), choices=sorted(REGIONS))
    p.add_argument('--tag', default='amocr6', help='batch tag: RGI<nn>_<region>_<tag>_batchNN.dat')
    p.add_argument('--end-year', type=int, default=3000)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    n = 0
    for region in a.regions:
        rginum, region_id, nbatch = REGIONS[region]
        for gi, ri, scen in SCENARIOS:
            for b in range(1, nbatch + 1):
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
