#!/bin/bash
# run_icetemp_advfield_pair.sh — paired advection ON/OFF run for Aletsch + Morteratsch,
# writing the full englacial temperature field T(band, layer) (firnice_write[2]='y').
#
# Produces the data for the advection-on vs advection-off cross-section figure
# (GGMW2026 talk, slide 7). Both members run concurrently; each is a single IDL
# process over 2 glaciers, 1 GCM, 1 SSP, so this adds 2 processes total.
#
# Mass-balance calibration is copied from the earlier paired run rather than recomputed
# (calibrate='n', read_parameters='y' in the configs).
#
# Launch:
#   cd ~/projects/glogemflow_development/GloGEM
#   tmux new-session -d -s advfield "bash scripts/run_icetemp_advfield_pair.sh"

set -euo pipefail

GLOGEM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT=/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_advfield_aletsch_morteratsch
SRC=/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_test_aletsch_morteratsch
LOG_DIR="$GLOGEM_DIR/logs"
mkdir -p "$LOG_DIR"

cd "$GLOGEM_DIR"

for member in adv no_adv; do
    # Seed the mass-balance calibration from the earlier paired run so this one can go
    # straight to the forward integration. Without these files read_parameters='y' fails.
    src_cal="$SRC/$member/monthly/CentralEurope/calibration"
    dst_cal="$OUT/$member/monthly/CentralEurope/calibration"
    if [ ! -d "$src_cal" ]; then
        echo "ERROR: calibration source missing: $src_cal" >&2
        exit 1
    fi
    mkdir -p "$dst_cal"
    cp -n "$src_cal"/* "$dst_cal"/ 2>/dev/null || true
    echo "seeded calibration for $member from $src_cal"
done

for member in adv no_adv; do
    cfg="$GLOGEM_DIR/scripts/config_icetemp_advfield_aletsch.pro"
    [ "$member" = "no_adv" ] && cfg="$GLOGEM_DIR/scripts/config_icetemp_advfield_aletsch_noadv.pro"
    log="$LOG_DIR/advfield_${member}_$(date +%Y%m%d_%H%M%S).log"
    echo "launching $member  cfg=$(basename "$cfg")  log=$log"
    nohup env GLOGEM_CONFIG="$cfg" bash -c "echo '.r glogem' | idl" > "$log" 2>&1 &
done

wait
echo "both members finished: $(date)"
