# Run Modes

Two independent choices control the overall character of a GloGEM run: the **time resolution** and the **run type**. Both are set in `config.pro`.

---

## Time resolution

| Setting | Description |
|---------|-------------|
| `time_resolution = 'daily'` | Daily climate forcing; reads one `.dat` file per reanalysis grid cell |
| `time_resolution = 'monthly'` | Monthly climate forcing; reads gridded `.mdi` binary files per region |

The daily model resolves sub-monthly temperature variability directly from the forcing data. The monthly model can optionally superimpose synthetic daily variability via `submonth_variability = 'y'`. The reanalysis dataset label is also automatically adjusted (`era5` → `ERA5`) when switching to monthly resolution.

---

## Calibration mode

Set `calibrate = 'y'` to optimize model parameters against observed glacier mass balances. The calibration runs entirely over the reanalysis period (no GCM required) and executes up to three sequential phases:

| Phase | Parameter optimized | Setting |
|-------|---------------------|---------|
| 1 | Precipitation correction factor (`c_prec`) | `calibration_phase = '1'` |
| 2 | Degree-day factors (`DDFsnow`, `DDFice`) | `calibration_phase = '2'` |
| 3 | Reanalysis temperature bias (`t_offset`) | `calibration_phase = '3'` |

The number of phases to run is controlled by `caliphase_loop` (1, 2, or 3). Calibration can be performed per glacier (`calibrate_individual = 'y'`, default) or over the full region simultaneously.

Several settings are automatically enforced during calibration: `reanalysis_direct = 'y'`, `debris_expansion = 'n'`, `firnice_temperature = 'n'`, and `glacier_retreat` is fixed to its default.

---

## Forward run (future projections)

Set `calibrate = 'n'` to run with previously calibrated parameters. The model loops over all configured GCMs, SSPs, and experiments (see [GCM configuration](gcm-configuration.md)) and writes annual output for each combination.

The simulation period is set by `tran = [start_year, end_year]`. For standard projections to 2100 the end year is enforced automatically; for runs to 2300 set `long_GCM = 'long_'`.

Glacier geometry changes (retreat and advance) are activated automatically once the simulation year passes the RGI inventory survey year of each glacier (`find_startyear = 'y'`).

---

## Historical / reanalysis-direct mode

When `tran[1]` is set to a year before 2021, or `reanalysis_direct = 'y'` is set explicitly, GloGEM uses the reanalysis data directly throughout the entire period without applying GCM bias correction. This mode is useful for:

- Evaluating model skill against independent observations
- Producing a consistent historical baseline

In this mode the GCM loop is skipped and `glacier_retreat` is disabled unless `hindcast_dynamic = 'y'`.

---

## Hindcast dynamic mode

Setting `hindcast_dynamic = 'y'` allows glacier geometry to evolve dynamically during the historical period (before the RGI survey date). This is used to produce internally consistent volume and area trajectories through the 20th century. It is incompatible with runs extending past 2020.

---

## Single-glacier mode

Set `single_glacier = '<RGI_ID>'` (e.g. `'01450'` for Grosser Aletschgletscher) to run the model for one glacier only. The grid loop is bypassed and all output is directed to the `SINGLE/` subdirectory. Useful for debugging, parameter sensitivity tests, or detailed inspection of a specific glacier.
