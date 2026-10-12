# GMIP4 campaign scripts

These scripts ran the 2026 GlacierMIP4 (GMIP4) campaign with GloGEM and GloGEMflow:
they split a region into batches, write the run configs, start the IDL jobs in `tmux`,
keep the hosts busy, combine the per-batch netCDF files into the regional GMIP4 files
and check the result before submission. They are written for the ETH vierzack hosts
and a shared network drive; the folders can be changed with environment variables
(see below). The model itself does not need any of them.

Every script prints its usage with `--help`. Run them from the repository root.

## What each script does

| Script | What it does | Writes |
|---|---|---|
| `create_region_batches.py` | Splits a region into N catchment files of similar size (largest glaciers spread round-robin), read from the glacier band files. | `RGI<NN>_<region>_batch<KK>.dat` in the catchment folder |
| `make_gmip4_configs.py` | Writes the ERA5 hindcast config of every region (`tran=[1940,2025]`, flow model on, no calving, `catchment_selection` from `GLOGEM_BATCH`). `--check` compares the configs on disk with the table and writes nothing. | `scripts/config_hindcast_rgi7_<region>_gmip4.pro` (git-ignored) |
| `launch_batches.sh` | Starts one IDL job per batch in its own `tmux` session, each with its own config (`CONFIG_FILE`) and journal folder. Marks a batch `.done` only when its log has a `FINISHED region` line for every GCM. Skips a session that still runs IDL. `DRY_RUN=1` prints what it would start. | `logs/<prefix>_batch<KK>_<time>.log`, `DONE_DIR/batch<KK>.done` or `.failed` |
| `auto_relaunch_watcher.sh` | Runs on one host and starts queued jobs (through `launch_batches.sh`) whenever fewer than `LICENSE_CEILING` IDL jobs run there. | its own log in `logs/` |
| `requeue_incomplete.py` | Finds jobs that are neither done, running nor queued and puts them back in a queue (dry run without `--to`). Its region table and file names are those of the 2026 rerun; adapt them for a new campaign. | `logs/launch_queue_<host>.txt` (with `--to`) |
| `combine_gmip4_output.py` | Sums the per-batch projection files of a region into one GMIP4 file per GCM and SSP: area, mass, mass below sea level (repaired where it was written as a running total), frontal ablation, monthly fluxes; temperature weighted by the initial glacier area; every month stamped with its real date, whole calendar years. Skips every GCM/SSP with a missing batch. `--verify-only` writes nothing. | `GMIP4_RESULTS_DIR/flow/<NN>_<Region>_GloGEMflow/` |
| `combine_gmip4_hindcast.py` | The same for the ERA5 hindcast, trimmed to 2000-2025. | same folder, `*_ERA5_{annual,monthly}.nc` |
| `check_gmip4_output.py` | Output gate, read-only: flags runaway glaciers (absurd volume or mean thickness), glaciers that turn NaN, an empty run folder, non-finite values in the combined files, regional regrowth under ssp370/ssp585 and mass below sea level larger than the mass. Runaways worth less than 1 % of the regional ice are tolerated; any other finding makes it exit non-zero. | nothing |
| `sync_spinup_cache.py` | Copies each region's flow spin-up cache next to the combined results. `--dry-run` writes nothing. | `GMIP4_RESULTS_DIR/spinup_cache/<Region>/` |
| `gmip4_paths.py` | The folders above, from environment variables (imported by the Python scripts). | - |

## Order of a campaign

```
1. batches     create_region_batches.py --region <r> --rgi-num <NN> --n <N>
2. configs     make_gmip4_configs.py (hindcast); one config per SSP for the projections
3. stage       calibration file into <dirres>/monthly/<Region>/calibration/, empty spinup_cache/
4. launch      launch_batches.sh  or  queue + auto_relaunch_watcher.sh;  requeue_incomplete.py for lost jobs
5. combine     combine_gmip4_output.py <region> flow [--v2|--v3];  combine_gmip4_hindcast.py <region>
6. gate        check_gmip4_output.py <region> [--v2|--v3]   -> submit only when it passes
```

Notes on the steps:

- **Configs.** The projection configs are the hindcast config without `tran` and with
  `GCM_model_idx = [0]` (all 8 GCMs) and `GCM_rcp_idx = [1]` (ssp126), `[2]` (ssp370),
  `[3]` (ssp585), or `GCM_model_idx = [3,4,5,7]` with `GCM_rcp_idx = [4]` (ssp534-over).
  Set `frontal_ablation` explicitly: `settings.pro` defaults to `'y'`. A flow run without
  calving needs a calibration made without calving.
- **Staging.** `read_calibration_params.pro` takes a catchment-specific calibration file if
  one exists next to the region-wide one, so leave only the file you mean to use. Any change
  of climate, calibration or flow code makes the spin-up cache invalid: empty
  `<dirres>/spinup_cache/` before the first job.
- **Launch order.** Run each batch's ERA5 hindcast first, then its ssp126 projection, then the
  other SSPs once ssp126 has finished its first GCM: the projections then read the cached
  spin-ups instead of computing them again, and no two jobs write the same spin-up.
  A queue line is `CONFIG_FILE|BATCH|SESSION_PREFIX|DONE_DIR[|EXPECTED_HOURS]`.
- **Combine.** Campaign folders are named `<region>_flow_rgi7_gmip4` (v1), `..._gmip4v2`
  (`--v2`) or `..._gmip4v3` (`--v3`). Region keys are those of `REGION_DIR` in
  `combine_gmip4_output.py`; the tables there and in `check_gmip4_output.py` must be kept
  in step by hand.

## Environment variables

| Variable | Used by | Default (the 2026 campaign) |
|---|---|---|
| `GMIP4_RUN_DIR` | configs, combine, check, sync: the folder that holds the campaign run folders | `/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development` |
| `GMIP4_RESULTS_DIR` | combine, check, sync: the submission tree | `/scratch_net/vierzack04_fourth/jabeer/GloGEM/r7spec_global_results` |
| `GLOGEM_DATA_DIR` | batches, combine: GloGEM data root (`data/catchments/`, `geometricdata/`), as `main_dir` in `settings.pro` | `/itet-stor/<user>/glogem` |
| `GMIP4_REUSE_DIR` | combine: a colleague's combined Δh files, where `REUSE_SOURCES` says so | `/scratch_net/vierzack05_fourth/lvantrich/GloGEM/r7spec_global_results/monthly` |
| `GLOGEM_LOGDIR` | `launch_batches.sh` (one journal folder per job below it); `glogem.pro` (journal folder) | launcher: `/itet-stor/jabeer/net_scratch/glogem_logs/runlogs`; model: `<repository>/logs` |
| `CONFIG_FILE`, `DONE_DIR`, `BATCH_LIST`, `EXPECTED_GCMS`, `DRY_RUN` | `launch_batches.sh` | see `launch_batches.sh --help` |
| `QUEUE_FILE`, `LICENSE_CEILING`, `LAUNCH_UNTIL`, `SHUTDOWN_AT`, `SHUTDOWN_MARGIN_MIN` | `auto_relaunch_watcher.sh` | see `auto_relaunch_watcher.sh --help` |

The model reads two more variables, which the launcher sets for every job:
`GLOGEM_CONFIG` (absolute path of the config to load instead of `config.pro`) and
`GLOGEM_BATCH` (the batch number, read by the configs to set `catchment_selection`).
A single run without the launcher:

```bash
cd <repository>
echo '.r glogem' | GLOGEM_CONFIG=/abs/path/config.pro GLOGEM_LOGDIR=/abs/path/logs GLOGEM_BATCH=01 idl
```
