#!/bin/bash
# Stage the no-calving calibration of each GMIP4 v4 region into <dir>_flow_rgi7_gmip4v4/monthly/<R>/calibration/.
# usage: stage_calibration_v4.sh REGION... | all
# Rule (as v3): always no-calving; Lander's no-calving file where it exists, else our merged no-calving
# recalibration; regions without calving glaciers take Matthias's region-wide file (= Lander's). Per-batch
# calibrations of v1 (08, 12, 14, 18) and CentralEurope's July file were tuned to the batch-dependent
# climate point (G4) and are not used. Sources are pinned by md5; a staged file that differs is replaced
# only with REPLACE=1. Catchment-specific files (calibrate_*_final_era5_<catchment>.dat) are removed.
# Every change is logged in calibration_provenance.txt next to the files.
set -euo pipefail
B=/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development
M=/scratch_net/iceberg_second/mhuss/r7spec_global_results/monthly
L=/scratch_net/vierzack05_fourth/lvantrich/GloGEM/r7spec_global_results/monthly
LN=/scratch_net/vierzack05_fourth/lvantrich/GloGEM/r7spec_global_results_nocalving/monthly
LL=$B/lowlatitudes_nocalv_calibration_v3/merged/monthly/LowLatitudes/calibration
f() { echo "calibrate_m1_cID9_$1_final_era5.dat"; }

# region: dir stem | region folder | source:md5 ...
table() {
  case $1 in
    westerncanada) echo "westerncanada WesternCanada $B/westerncanada_flow_rgi7_gmip4v2/monthly/WesternCanada/calibration/$(f westerncanada):b2522c60c1b3360d07c9e979a70c6fad" ;;
    arcticcanadan) echo "arcticcanadan ArcticCanadaN $LN/ArcticCanadaN/calibration/$(f arcticcanadaN):b695c540c97fa688d12382f29b702990" ;;
    arcticcanadas) echo "arcticcanadas ArcticCanadaS $LN/ArcticCanadaS/calibration/$(f arcticcanadaS):9661eead38729fe5ded9aa27e94747e0" ;;
    iceland)       echo "iceland Iceland $LN/Iceland/calibration/$(f iceland):85632ecd14e1394bb9b1450cf77536e5" ;;
    svalbard)      echo "svalbard Svalbard $LN/Svalbard/calibration/$(f svalbard):a49c413983cd52664c212ebbfc70d4a0" ;;
    scandinavia)   echo "scandinavia Scandinavia $M/Scandinavia/calibration/$(f scandinavia):793d8a487989e314d85d325c3097c5b6" ;;
    russianarctic) echo "russianarctic RussianArctic $B/russianarctic_nocalv_calibration/merged/monthly/RussianArctic/calibration/$(f russianarctic):861914baad84109bec1927cc8aab3a2e" ;;
    centraleurope) echo "alps CentralEurope $M/CentralEurope/calibration/$(f centraleurope):8825396c1e484e0adad82389e76d09fa" ;;
    caucasus)      echo "caucasus Caucasus $M/Caucasus/calibration/$(f caucasus):8c377e8a307b32833ad35f027902ca8a" ;;
    centralasia)   echo "centralasia CentralAsia $M/CentralAsia/calibration/$(f centralasiaN):34ed93d94a6c51189bfce28e0e29b017" ;;
    southasiawest) echo "southasiawest SouthAsiaWest $M/SouthAsiaWest/calibration/$(f centralasiaW):a898644ab22287ab4f4a180cc73870dc" ;;
    southasiaeast) echo "southasiaeast SouthAsiaEast $L/SouthAsiaEast/calibration/$(f centralasiaS):b2959019c3da86baa74a043ca4cad9d2" ;;
    newzealand)    echo "newzealand NewZealand $M/NewZealand/calibration/$(f newzealand):4eb25d55a657a967d6e72d9b2464e9e4" ;;
    lowlatitudes)  echo "lowlatitudes LowLatitudes $LL/$(f Andes):85c43b6b869c3e68cf33f833803f44cd $LL/$(f Africa):aa8dbf15c7eb225347aa0a9382d3d9e3 $LL/$(f Mexico):951622af152806be08eda388e15a3a18 $LL/$(f Newguinea):57ef8947a080bceebccd7a7b26f379ab" ;;
    *) return 1 ;;
  esac
}
ALL="westerncanada arcticcanadan arcticcanadas iceland svalbard scandinavia russianarctic centraleurope caucasus centralasia southasiawest southasiaeast newzealand lowlatitudes"
[ $# -ge 1 ] || { echo "usage: $0 REGION... | all" >&2; exit 1; }
[ "$1" = all ] && set -- $ALL

for r in "$@"; do
  row=$(table "$r") || { echo "unknown region $r" >&2; exit 1; }
  read -r stem R srcs <<< "$row"
  D=$B/${stem}_flow_rgi7_gmip4v4/monthly/$R/calibration
  P=$D/calibration_provenance.txt
  for sm in $srcs; do
    s=${sm%%:*}; want=${sm##*:}
    test -s "$s" || { echo "$r: missing source $s" >&2; exit 1; }
    [ "$(md5sum < "$s" | cut -c1-32)" = "$want" ] || { echo "$r: source md5 changed: $s" >&2; exit 1; }
  done
  mkdir -p "$D"
  for sm in $srcs; do
    s=${sm%%:*}; t=$D/$(basename "$s")
    if [ -e "$t" ]; then
      cmp -s "$s" "$t" && continue
      [ "${REPLACE:-0}" = 1 ] || { echo "$t exists and differs -- rerun with REPLACE=1 to replace it" >&2; exit 1; }
      echo "$(date +%F_%T) $(basename "$t") replaced, old md5 $(md5sum < "$t" | cut -c1-32)" >> "$P"
      rm -f "$t"
    fi
    cp -p "$s" "$t"
    echo "$(date +%F_%T) $(basename "$t") <- $s md5 $(md5sum < "$t" | cut -c1-32)" >> "$P"
  done
  for t in "$D"/calibrate_m1_cID9_*_final_era5_*.dat; do
    [ -e "$t" ] || continue
    echo "$(date +%F_%T) $(basename "$t") removed (would override the region file), md5 $(md5sum < "$t" | cut -c1-32)" >> "$P"
    rm -f "$t"
  done
  echo "== $r: $D"; cat "$P"
done
