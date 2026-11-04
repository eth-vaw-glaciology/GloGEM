#!/bin/bash
# run_icetemp_advfield_variants.sh — englacial-temperature variant matrix for
# Aletsch + Morteratsch, to test whether the cold bias is the initial condition.
#
#   spinup   thermal spin-up on,  strain heating off
#   strain   thermal spin-up off, strain heating on
#   both     thermal spin-up on,  strain heating on
#
# Each variant is run twice, advection on and off, so the slide-7 figure can be
# regenerated on whichever initialisation we decide to present. Members run in
# parallel; pass variant names as arguments to run a subset.
#
#   bash scripts/run_icetemp_advfield_variants.sh            # all three
#   bash scripts/run_icetemp_advfield_variants.sh spinup     # just one

set -euo pipefail
GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT=/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_advfield_aletsch_morteratsch
SRC=/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_test_aletsch_morteratsch
CFG="$GLOGEM_DIR/scripts/config_icetemp_advfield_variants.pro"
LOG_DIR="$GLOGEM_DIR/logs"; mkdir -p "$LOG_DIR"
cd "$GLOGEM_DIR"

variants=("${@:-spinup strain both}")
read -r -a variants <<< "${variants[*]}"
stamp=$(date +%Y%m%d_%H%M%S)

for v in "${variants[@]}"; do
    case "$v" in
        spinup) sp=y; st=n ;;
        strain) sp=n; st=y ;;
        both)   sp=y; st=y ;;
        *) echo "unknown variant: $v" >&2; exit 1 ;;
    esac
    for adv in y n; do
        tag="${v}_$([ "$adv" = y ] && echo adv || echo noadv)"
        # seed the mass-balance calibration so read_parameters='y' has something to read
        src_cal="$SRC/$([ "$adv" = y ] && echo adv || echo no_adv)/monthly/CentralEurope/calibration"
        dst_cal="$OUT/$tag/monthly/CentralEurope/calibration"
        mkdir -p "$dst_cal"; cp -n "$src_cal"/* "$dst_cal"/ 2>/dev/null || true
        # reuse the flow spin-up cache; it is thermally independent
        mkdir -p "$OUT/$tag/spinup_cache"
        cp -n "$OUT/$([ "$adv" = y ] && echo adv || echo no_adv)/spinup_cache"/*.sav \
              "$OUT/$tag/spinup_cache/" 2>/dev/null || true
        log="$LOG_DIR/advfield_${tag}_${stamp}.log"
        echo "launching $tag  (spinup=$sp strain=$st adv=$adv)  log=$log"
        nohup env GLOGEM_CONFIG="$CFG" GLOGEM_TAG="$tag" GLOGEM_ADV="$adv" \
                  GLOGEM_SPINUP="$sp" GLOGEM_STRAIN="$st" \
              bash -c "echo '.r glogem' | idl" > "$log" 2>&1 &
    done
done
wait
echo "all variants finished: $(date)"
