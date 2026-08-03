# GCM Configuration

GloGEM loops over GCMs, SSPs, and ensemble experiments to produce an ensemble of future projections. The active model ensemble and scenario selection are configured in `config.pro`.

---

## Running a single GCM/SSP combination

For targeted runs or testing, set `short_gcmchoice` to select one specific combination:

```
short_gcmchoice = [1, 1, 1]   ; [GCM index, SSP index, experiment index] — all 1-based
```

With `short_gcmchoice = [1, 1, 1]` GloGEM runs the first GCM in `GCM_model`, the first SSP in `GCM_rcp`, and the first experiment in `GCM_experiment`. Setting any element to `0` runs the full batch for that dimension.

---

## Running a full ensemble batch

To run all GCMs and SSPs:

```
short_gcmchoice = [0, 0, 0]
```

The number of SSPs and experiments per GCM is controlled by `rcp_batch` and `expe_batch` — arrays with one entry per GCM specifying how many SSPs/experiments that GCM provides. For parallel batch jobs on a cluster, `first_GCM` sets the starting GCM index (0-based, minus 1 of the 1-based position in `GCM_model`).

---

## Available CMIP6 models (runs to 2100)

| Index | Model |
|-------|-------|
| 1 | BCC-CSM2-MR |
| 2 | CAMS-CSM1-0 |
| 3 | CESM2 |
| 4 | CESM2-WACCM |
| 5 | EC-Earth3 |
| 6 | EC-Earth3-Veg |
| 7 | FGOALS-f3-L |
| 8 | GFDL-ESM4 |
| 9 | INM-CM4-8 |
| 10 | INM-CM5-0 |
| 11 | MPI-ESM1-2-HR |
| 12 | MRI-ESM2-0 |
| 13 | NorESM2-MM |

## Available SSPs

| Index | Scenario |
|-------|----------|
| 1 | ssp126 |
| 2 | ssp245 |
| 3 | ssp370 |
| 4 | ssp585 |
| 5 | ssp119 |
| 6 | ssp534-over |

## Available experiments

| Index | Experiment |
|-------|-----------|
| 1 | r1i1p1f1 |
| 2 | r2i1p1f1 |
| 3 | r3i1p1f1 |
| … | … |
| 7 | r7i1p1f1 |

---

## Extended runs to 2300

Setting `long_GCM = 'long_'` switches to a separate ensemble designed for 2300 projections:

```
long_GCM = 'long_'
```

This activates a different set of 11 models (ACCESS-CM2, ACCESS-ESM1-5, CESM2-WACCM, CanESM5, GISS-E2-1-G, GISS-E2-1-H, GISS-E2-2-G, IPSL-CM6A-LR, MIROC-ES2L, MRI-ESM2-0, UKESM1-0-LL), reads data from the `long_cmip6` subdirectory, and reduces the output variable set (discharge is not available for 2300 runs).

---

## Settings summary

| Setting | Default | Description |
|---------|---------|-------------|
| `short_gcmchoice` | `[1, 1, 1]` | Indices for single-GCM run; `0` in any position runs full batch |
| `first_GCM` | `0` | Starting GCM index for batch parallelization (0-based minus 1) |
| `rcp_batch` | `[4,5,4,4,5,5,4,5,4,4,4,5,4]` | Number of SSPs per GCM |
| `expe_batch` | `[1,1,…,1]` | Number of experiments per GCM |
| `long_GCM` | `''` | `'long_'` to use 2300 model ensemble |
| `GCM_data` | `'cmip6'` | GCM dataset identifier |
| `CMIP6` | `'y'` | Use CMIP6 GCMs |
