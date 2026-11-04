#!/usr/bin/env python3
"""Generate the per-region GMIP4 ERA5 hindcast configs.

The configs themselves are one-off run artifacts and are gitignored; this
generator is the tracked source of truth for them. It exists because the
per-region values are not guessable: several regions reuse another region's
batch prefix (southasiaeast batches are named centralasiaS_*, centraleurope's
are alps_*), and the subregion regions carry no catchment_selection at all.

    python3 scripts/make_gmip4_configs.py            # write scripts/
    python3 scripts/make_gmip4_configs.py --check    # compare, write nothing
"""
import argparse
import pathlib
import re
import sys

SCRATCH = "/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"

# rid   region_id_loop value (see region_batch.dat)
# dir   campaign output directory under SCRATCH; subregions share the parent's
# batch catchment_selection prefix, or None when region_id alone selects the run
# note  why frontal_ablation is pinned to 'n' for this region
REGIONS = {
    "alaska":                  dict(rid= 1, dir="alaska_flow_rgi7_gmip4", batch="alaska"        , note="confirmed 0 calving-flux rows in mhuss's calibration data (2026-09-07)"),
    "antarctic_atlantic":      dict(rid=25, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_indian":        dict(rid=26, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_mariebyrd":     dict(rid=31, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_maudwilkes":    dict(rid=28, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_pacific":       dict(rid=27, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_peninsula":     dict(rid=30, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "antarctic_victoria":      dict(rid=29, dir="antarctic_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "arcticcanadan":           dict(rid= 3, dir="arcticcanadan_flow_rgi7_gmip4", batch="arcticcanadaN" , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "arcticcanadas":           dict(rid= 4, dir="arcticcanadas_flow_rgi7_gmip4", batch="arcticcanadaS" , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "caucasus":                dict(rid=15, dir="caucasus_flow_rgi7_gmip4", batch="caucasus"      , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "centralasia":             dict(rid=16, dir="centralasia_flow_rgi7_gmip4", batch="centralasiaN"  , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "centraleurope":           dict(rid=14, dir="alps_flow_rgi7_gmip4", batch="alps"          , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "greenland":               dict(rid= 5, dir="greenland_flow_rgi7_gmip4", batch="greenland"     , note="paired with Lander's no-calving MB calibration (r7spec_global_results_nocalving, staged 2026-09-11)"),
    "iceland":                 dict(rid= 6, dir="iceland_flow_rgi7_gmip4", batch="iceland"       , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "lowlatitudes_africa":     dict(rid=20, dir="lowlatitudes_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "lowlatitudes_andes":      dict(rid=19, dir="lowlatitudes_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "lowlatitudes_mexico":     dict(rid=21, dir="lowlatitudes_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "lowlatitudes_newguinea":  dict(rid=22, dir="lowlatitudes_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "newzealand":              dict(rid=24, dir="newzealand_flow_rgi7_gmip4", batch="newzealand"    , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "northasia_altay":         dict(rid=10, dir="northasia_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "northasia_chukotka":      dict(rid=11, dir="northasia_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "northasia_east":          dict(rid=12, dir="northasia_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "northasia_north":         dict(rid=13, dir="northasia_flow_rgi7_gmip4", batch=None            , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "russianarctic":           dict(rid= 9, dir="russianarctic_flow_rgi7_gmip4", batch="russianarctic" , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "scandinavia":             dict(rid= 8, dir="scandinavia_flow_rgi7_gmip4", batch="scandinavia"   , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "southasiaeast":           dict(rid=18, dir="southasiaeast_flow_rgi7_gmip4", batch="centralasiaS"  , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "southasiawest":           dict(rid=17, dir="southasiawest_flow_rgi7_gmip4", batch="centralasiaW"  , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "southernandes":           dict(rid=23, dir="southernandes_flow_rgi7_gmip4", batch="southernandes" , note="confirmed 0 calving-flux rows in mhuss's calibration data (2026-09-07)"),
    "svalbard":                dict(rid= 7, dir="svalbard_flow_rgi7_gmip4", batch="svalbard"      , note="must match how mass-balance calibration was done (2026-09-02 fix, see feedback-calving-region-policy)"),
    "westerncanada":           dict(rid= 2, dir="westerncanada_flow_rgi7_gmip4", batch="westerncanada" , note="confirmed 0 calving-flux rows in mhuss's calibration data (2026-09-07)"),
}


def render(key, r):
    lines = [
        f"; GloGEM config -- RGI7 GloGEMflow GMIP4 ERA5 hindcast ({key})",
        "; Generated by scripts/make_gmip4_configs.py -- edit the table there, not this file.",
        "",
        f"dirres     = '{SCRATCH}/{r['dir']}/'",
        "RGIversion = '7'",
        "",
        "time_resolution = 'monthly'",
        f"region_id_loop  = [{r['rid']}, {r['rid']}]",
        "",
        "calibrate = 'n'",
        "",
        "MIP           = 'GMIP4'",
        "tran          = [1940, 2025]   ; full ERA5 record; firn needs ~5 yr spin-up before 2000",
        "",
        "refreezing_parametrised = 'y'",
        "write_netcdf            = 'y'",
        "use_flow_model = 'y'",
        f"frontal_ablation = 'n'   ; explicit -- {r['note']}",
    ]
    if r["batch"]:
        lines += [
            "_batch = getenv('GLOGEM_BATCH')",
            f"if _batch ne '' then catchment_selection = '{r['batch']}_batch' + _batch $",
            "else catchment_selection = ''",
        ]
    else:
        lines += ["; subregion: selected by region_id_loop alone, no catchment_selection"]
    return "\n".join(lines) + "\n"


# every assignment the model reads, so --check compares values and ignores comments
SETTING = re.compile(r"^\s*([A-Za-z_]\w*)\s*=\s*(.+?)\s*(?:;.*)?$")


def settings_of(text):
    out = {}
    for ln in text.splitlines():
        if ln.lstrip().startswith(";"):
            continue
        m = SETTING.match(ln)
        if m:
            out[m.group(1)] = m.group(2).rstrip("$").strip()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="compare against the files on disk instead of writing")
    ap.add_argument("--outdir", default=str(pathlib.Path(__file__).parent))
    a = ap.parse_args()

    outdir = pathlib.Path(a.outdir)
    bad = 0
    for key, r in sorted(REGIONS.items()):
        path = outdir / f"config_hindcast_rgi7_{key}_gmip4.pro"
        text = render(key, r)
        if not a.check:
            path.write_text(text, encoding="utf-8")
            continue
        if not path.exists():
            print(f"  MISSING  {path.name}")
            bad += 1
            continue
        want, have = settings_of(text), settings_of(path.read_text(encoding="utf-8"))
        diff = {k for k in set(want) | set(have) if want.get(k) != have.get(k)}
        if diff:
            print(f"  DIFFERS  {path.name}")
            for k in sorted(diff):
                print(f"             {k}: generated={want.get(k)!r} on-disk={have.get(k)!r}")
            bad += 1

    verb = "checked" if a.check else "wrote"
    print(f"  {verb} {len(REGIONS)} configs" + (f", {bad} mismatched" if bad else ", all match" if a.check else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
