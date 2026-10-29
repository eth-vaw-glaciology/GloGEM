#!/bin/bash
# Swap combined v4 rerun regions into the GlacierMIP4 publish folders.
# usage: publish_gmip4v4.sh REGION_FOLDER... | all      (e.g. 06_Iceland_GloGEMflow)
# A staged region needs all 58 netCDF files (28 GCM x SSP + ERA5, annual + monthly) and CHECKS_PASSED.txt.
# The submitted folder moves whole (with its SUBMITTED marker) to flow/_superseded_2026-10-29/, the staged
# one moves in, and MD5SUMS.txt + READY_FOR_UPLOAD_GMIP4.txt are written. Both moves are renames on one disk;
# nothing is copied or deleted.
set -euo pipefail
R=/scratch_net/vierzack04_fourth/jabeer/GloGEM/r7spec_global_results/flow
S=${GMIP4_FINAL_BASE:-/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/gmip4v4_staging}/flow
A=$R/_superseded_2026-10-29
ALL="02_WesternCanada 03_ArcticCanadaN 04_ArcticCanadaS 06_Iceland 07_Svalbard 08_Scandinavia 09_RussianArctic
     11_CentralEurope 12_Caucasus 13_CentralAsia 14_SouthAsiaWest 15_SouthAsiaEast 16_LowLatitudes 18_NewZealand"
COMMIT=$(git -C "$(dirname "$0")/.." rev-parse --short HEAD)
[ $# -ge 1 ] || { echo "usage: $0 REGION_FOLDER... | all" >&2; exit 1; }
[ "$1" = all ] && set -- $(for r in $ALL; do echo "${r}_GloGEMflow"; done)

# all regions are checked before anything moves
for d in "$@"; do
  src=$S/$d
  [ -d "$src" ] || { echo "$d: not staged ($src)" >&2; exit 1; }
  n=$(find "$src" -maxdepth 1 -name 'GloGEMflow_rgi*_*.nc' | wc -l)
  [ "$n" -eq 58 ] || { echo "$d: $n of 58 files staged" >&2; exit 1; }
  [ -s "$src/CHECKS_PASSED.txt" ] || { echo "$d: no CHECKS_PASSED.txt" >&2; exit 1; }
  [ ! -e "$A/$d" ] || { echo "$d: already archived in $A" >&2; exit 1; }
done

mkdir -p "$A"
for d in "$@"; do
  src=$S/$d; dst=$R/$d
  [ -d "$dst" ] && mv "$dst" "$A/$d"
  mv "$src" "$dst"
  (cd "$dst" && md5sum GloGEMflow_rgi*_*.nc > MD5SUMS.txt)
  cat > "$dst/READY_FOR_UPLOAD_GMIP4.txt" <<EOF
GMIP4 v4 rerun, combined and checked $(date +%F). NOT yet uploaded: add SUBMITTED_GMIP4.txt after the upload.

Model      : GloGEMflow (GloGEM + SIA flowline module)
Code       : branch glogemflow-v4 at $COMMIT = tag gmip4-v3 + RGI7 area correction in the flowline (F15),
             GCM grid search across 0 deg longitude (G26), spin-up cache keyed by RGI version and region,
             small-glacier mass conservation dh_small_conserve='y' (G42), spin-up parameter gate (F21)
Calibration: no-calving, region-wide (calibration_provenance.txt in the run folder)
Projections: 56 files, 28 GCM x SSP, annual + monthly
Hindcast   : GloGEMflow_rgiNN_ERA5_{annual,monthly}.nc, ERA5 2000-2025 (computed from 1940)
Checks     : see CHECKS_PASSED.txt
Replaces   : the earlier submission, archived whole in $A/$d
Checksums  : MD5SUMS.txt
EOF
  echo "$d: published ($(wc -l < "$dst/MD5SUMS.txt") files), old folder in $A/$d"
done
