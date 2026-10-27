#!/usr/bin/env python3
"""Generate the GMIP4 v4 rerun configs (hindcast + 4 SSPs per region or subregion).

v4 = the v3 settings (one config per region and SSP, the batch from GLOGEM_BATCH,
frontal_ablation 'n') plus dh_small_conserve (G42) and the spin-up parameter gate (F21),
written to <dir>_flow_rgi7_gmip4v4/. The configs are gitignored; this table is the source.

    python3 scripts/make_gmip4v4_configs.py            # write scripts/
    python3 scripts/make_gmip4v4_configs.py --list     # print key, batches, dirres
"""
import pathlib
import sys

SCRATCH = "/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"
RUN = "gmip4v4"

# key: rid (region_batch.dat), dir (campaign dir stem), prefix (catchment batch prefix),
# batches (numbers this config accepts)
REGIONS = {
    "westerncanada":  dict(rid=2,  dir="westerncanada", prefix="westerncanada", batches=range(1, 13)),
    "arcticcanadan":  dict(rid=3,  dir="arcticcanadan", prefix="arcticcanadaN", batches=range(1, 11)),
    "arcticcanadas":  dict(rid=4,  dir="arcticcanadas", prefix="arcticcanadaS", batches=range(1, 13)),
    "iceland":        dict(rid=6,  dir="iceland",       prefix="iceland",       batches=range(1, 5)),
    "svalbard":       dict(rid=7,  dir="svalbard",      prefix="svalbard",      batches=range(1, 9)),
    "scandinavia":    dict(rid=8,  dir="scandinavia",   prefix="scandinavia",   batches=range(1, 17)),
    "russianarctic":  dict(rid=9,  dir="russianarctic", prefix="russianarctic", batches=range(1, 7)),
    "centraleurope":  dict(rid=14, dir="alps",          prefix="alps",          batches=range(1, 25)),
    "caucasus":       dict(rid=15, dir="caucasus",      prefix="caucasus",      batches=range(1, 13)),
    "centralasia":    dict(rid=16, dir="centralasia",   prefix="centralasiaN",  batches=range(1, 25)),
    "southasiawest":  dict(rid=17, dir="southasiawest", prefix="centralasiaW",  batches=range(1, 21)),
    "southasiaeast":  dict(rid=18, dir="southasiaeast", prefix="centralasiaS",  batches=range(1, 13)),
    "newzealand":     dict(rid=24, dir="newzealand",    prefix="newzealand",    batches=range(1, 17)),
    # LowLatitudes: one config per climate subregion, batches numbered per region (as v3)
    "lowlatitudes_andes":     dict(rid=19, dir="lowlatitudes", prefix="lowlatitudes", batches=range(1, 5), sub="Andes"),
    "lowlatitudes_africa":    dict(rid=20, dir="lowlatitudes", prefix="lowlatitudes", batches=[5], sub="Africa"),
    "lowlatitudes_mexico":    dict(rid=21, dir="lowlatitudes", prefix="lowlatitudes", batches=[6], sub="Mexico"),
    "lowlatitudes_newguinea": dict(rid=22, dir="lowlatitudes", prefix="lowlatitudes", batches=[7], sub="Newguinea"),
}

# (GCM_model_idx, GCM_rcp_idx): ssp534-over exists for 4 GCMs only
SSPS = {"ssp126": ("[0]", "[1]"), "ssp370": ("[0]", "[2]"), "ssp585": ("[0]", "[3]"),
        "ssp534over": ("[3,4,5,7]", "[4]")}

V4 = [
    "dh_small_conserve = 'y'           ; G42: glaciers of 4 bands or fewer keep their mass",
    "spinup_gate_aflow_min = 1.2d-18   ; F21: A_flow below that of ice at -30 C (Cuffey and Paterson, 2010) -> no flow model",
    "spinup_gate_ela_max = 499.9d0     ; F21: ELA bias at its 500 m clamp -> no flow model",
]


def batches(r):
    return [f"{b:02d}" for b in r["batches"]]


def dirres(r):
    return f"{SCRATCH}/{r['dir']}_flow_rgi7_{RUN}/"


def render(key, r, ssp):
    bl = batches(r)
    head = f"; GMIP4 v4 {'ERA5 hindcast' if ssp == 'hindcast' else ssp} -- {key} (region_batch.dat id {r['rid']}); batches {bl[0]}-{bl[-1]}"
    lines = [head,
             f"dirres     = '{dirres(r)}'",
             "RGIversion = '7'",
             "time_resolution = 'monthly'",
             f"region_id_loop  = [{r['rid']}, {r['rid']}]",
             "calibrate = 'n'",
             "MIP           = 'GMIP4'"]
    if ssp == "hindcast":
        lines.append("tran          = [1940, 2025]   ; full ERA5 record; firn needs ~5 yr spin-up before 2000")
    else:
        g, s = SSPS[ssp]
        lines += [f"GCM_model_idx = {g}", f"GCM_rcp_idx   = {s}"]
    lines += ["refreezing_parametrised = 'y'",
              "write_netcdf            = 'y'",
              "use_flow_model = 'y'",
              "frontal_ablation = 'n'   ; always: GloGEMflow has no calving sink; paired with a no-calving calibration"]
    lines += V4
    lines += ["_batch = getenv('GLOGEM_BATCH')",
              f"catchment_selection = '{r['prefix']}_batch' + _batch"]
    if "sub" in r:
        allowed = ",".join(f"'{b}'" for b in bl)
        lines += [f"; {r['sub']} runs batches {', '.join(bl)} only; any other value stops the run at the catchment read",
                  f"if total([{allowed}] eq _batch) eq 0 then catchment_selection = '{r['prefix']}_batch' + _batch + '_is_not_a_{r['sub']}_batch'"]
    return "\n".join(lines) + "\n"


def cfg_name(key, ssp):
    if ssp == "hindcast":
        return f"config_hindcast_rgi7_{key}_{RUN}.pro"
    return f"config_flow_rgi7_{key}_{RUN}_{ssp}.pro"


def main():
    out = pathlib.Path(__file__).parent
    if "--list" in sys.argv:
        for key, r in REGIONS.items():
            print(f"{key:24s} batches {','.join(batches(r))}  {dirres(r)}")
        return 0
    n = 0
    for key, r in REGIONS.items():
        for ssp in ["hindcast"] + list(SSPS):
            (out / cfg_name(key, ssp)).write_text(render(key, r, ssp), encoding="utf-8")
            n += 1
    print(f"wrote {n} configs to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
