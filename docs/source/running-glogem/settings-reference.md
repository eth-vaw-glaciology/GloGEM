# Settings Reference

All settings have defaults in `procedures/initialise/settings.pro`. To override a setting, copy `config.pro.example` to `config.pro` and uncomment or add the relevant line. `config.pro` is git-ignored and loaded last, so any value set there takes precedence.

---

## Output directory (required)

| Setting | Description |
|---------|-------------|
| `dirres` | Absolute path to the output directory. **Must be set in `config.pro`** — there is no default. |

---

## RGI version

| Setting | Default | Description |
|---------|---------|-------------|
| `RGIversion` | `'6'` | RGI version to use (`'6'` or `'7'`) |

---

## Time resolution

| Setting | Default | Description |
|---------|---------|-------------|
| `time_resolution` | `'daily'` | `'daily'` or `'monthly'` |

---

## Run mode

| Setting | Default | Description |
|---------|---------|-------------|
| `tran` | `[1940, 2100]` | Simulation period (start year, end year) |
| `calibrate` | `'n'` | `'y'` to calibrate, `'n'` to run with existing parameters |
| `find_startyear` | `'y'` | Auto-detect glacier retreat start year from RGI survey date |
| `reanalysis_direct` | `'n'` | `'y'` to use reanalysis throughout without GCM |
| `hindcast_dynamic` | `'n'` | `'y'` to allow dynamic geometry in the historical period (set to `'y'` for GMIP4; reset to `'n'` when `tran[1]` is after 2025) |
| `write_file` | `'y'` | `'y'` to write output files to disk |

---

## Region and glacier selection

| Setting | Default | Description |
|---------|---------|-------------|
| `region_id_loop` | `[14, 14]` | Start and end region indices in `region_batch.dat` |
| `single_glacier` | `'01450'` | RGI ID for a single-glacier run; `''` to disable |
| `catchment_selection` | `''` | Named catchment to restrict the glacier loop; `''` for full region |
| `size_range` | `[0.002, 100000]` | Glacier area filter (km²) |

---

## Climate data

| Setting | Default | Description |
|---------|---------|-------------|
| `reanalysis` | `'era5'` | Reanalysis product (see [Climate Data](../input-data/climate-data.md)) |
| `rea_eval` | `[1991, 2020]` | Reference period for GCM bias computation |
| `bias_correction` | `'y'` | Apply GCM bias correction |
| `bias_correction_method` | `1` | `1` = delta method, `2` = quantile mapping |
| `submonth_variability` | `'y'` | Superimpose synthetic daily T variability (monthly model only) |

---

## GCM selection

| Setting | Default | Description |
|---------|---------|-------------|
| `short_gcmchoice` | `[1, 1, 1]` | `[GCM, SSP, experiment]` 1-based indices; `0` = full batch |
| `first_GCM` | `0` | Starting GCM offset for parallel batch runs |
| `long_GCM` | `''` | `'long_'` for 2300 ensemble; `''` for standard 2100 runs |
| `CMIP6` | `'y'` | Use CMIP6 GCMs |
| `GCM_data` | `'cmip6'` | GCM dataset subdirectory identifier |

---

## Mass balance model

| Setting | Default | Description |
|---------|---------|-------------|
| `meltmodel` | `'1'` | `'1'` = degree-day, `'3'` = simplified energy balance |
| `DDFsnow0` | `3` | Initial degree-day factor for snow (mm d⁻¹ °C⁻¹) |
| `DDFice0` | `6` | Initial degree-day factor for ice (mm d⁻¹ °C⁻¹) |
| `T_melt` | `0` | Melt threshold temperature (°C) |
| `c_prec` | — | Precipitation correction factor (set per region from file) |
| `dPdz` | `1.5` | Precipitation gradient (% per 100 m) |

---

## Model physics

| Setting | Default | Description |
|---------|---------|-------------|
| `glacier_retreat` | `'y'` | Activate annual glacier geometry update (Δh parameterisation) |
| `use_flow_model` | `'n'` | `'y'` to use the GloGEMflow flowline model instead of the Δh parameterisation where it can; sets `advance = 'y'` (see {ref}`settings-flowline-model`) |
| `advance` | `'y'` | Allow glacier advance |
| `frontal_ablation` | `'y'` | Activate calving for marine-terminating glaciers |
| `refreezing_parametrised` | `'y'` | Activate parametrised refreezing |
| `refreezing_full` | `'n'` | Activate full physics refreezing (slow) |
| `firnice_temperature` | `'n'` | Activate englacial firn/ice temperature model |
| `debris_supraglacial` | `'n'` | Activate supraglacial debris model |

---

(settings-flowline-model)=
## Flowline model (GloGEMflow)

Used only with `use_flow_model = 'y'`; see [Flowline Model (GloGEMflow)](../model-description/glacier-dynamics/flow-model.md).

| Setting | Default | Description |
|---------|---------|-------------|
| `spinup_gate_vol_tol` | `0.5d0` | Spin-up quality gate: largest volume error of the survey-year state (fraction of the observed volume) |
| `spinup_gate_len_min` | `0.5d0` | Spin-up quality gate: smallest length of the survey-year state (fraction of the observed length) |
| `spinup_max_substeps` | `2500000l` | Work limit of one glacier's spin-up: flow time steps over all attempts |
| `spinup_max_wallclock_sec` | `900d0` | Wall-clock safety cap of one glacier's spin-up (s); should never bind |
| `flow_gridend_outflow` | `'frontal'` | Ice leaving the end of the flowline grid: `'frontal'` books it as frontal ablation, `'melt_if_land'` as ice melt where the bed there is above 0 m |

Glaciers that fail the gate or the spin-up, and glaciers shorter than 1 km, run on the Δh parameterisation. Spin-ups are cached in `<dirres>/spinup_cache/`; delete that folder after any change of climate, calibration or flow code.

---

## Growth limit

`limit_glacier_growth.pro` bounds every glacier once a year, with the flow model and with the Δh parameterisation.

| Setting | Default | Description |
|---------|---------|-------------|
| `growth_max_thick` | `2000.0d0` | Largest mean thickness of a glacier (m) |
| `growth_max_vol` | `50.0d0` | Volume (km³) above which a glacier is limited, when it is also more than `growth_max_rel` times its inventory volume |
| `growth_max_rel` | `20.0d0` | See `growth_max_vol` |

---

## Calibration

| Setting | Default | Description |
|---------|---------|-------------|
| `caliphase_loop` | `3` | Number of calibration phases to run (1, 2, or 3) |
| `calibration_phase` | `'1'` | Starting calibration phase |
| `calibrate_individual` | `'y'` | Calibrate per glacier (vs. regional mean) |
| `calibrate_glacierspecific` | `'y'` | Use glacier-specific geodetic mass balance targets |
| `calperiod_ID` | `9` | Calibration period identifier (9 = glacier-specific Hugonnet 2021) |
| `read_parameters` | `'y'` | Read previously calibrated parameters from file |

---

## Output options

| Setting | Default | Description |
|---------|---------|-------------|
| `full_output` | `'n'` | `'y'` for extended output variable set |
| `write_mb_elevationbands` | `'n'` | Write seasonal mass balance per elevation band |
| `write_hypsometry_files` | `'n'` | Write annual hypsometry evolution for all glaciers |
| `firnice_write` | `['y', 'y']` | Write firn-ice temperature: [time series, detailed profiles] |
| `version_past` | `''` | Version tag appended to historical output folder name |
| `write_geometry_output` | `'n'` | `'y'` saves each glacier's band (and, with the flow model, flowline) geometry history as `.sav` files; about 0.5–1 MB per glacier and scenario |

---

## Environment variables

Read when GloGEM starts (`.r glogem`), so different runs can share one copy of the code.

| Variable | Read by | Description |
|----------|---------|-------------|
| `GLOGEM_CONFIG` | `settings.pro` | Absolute path of the user config to load instead of `<repository>/config.pro` |
| `GLOGEM_LOGDIR` | `glogem.pro` | Folder for the run journal (`glogem_<time>.log`); default `<repository>/logs` |
| `GLOGEM_BATCH` | the user config | Not read by the model itself: batch configs read it with `getenv('GLOGEM_BATCH')` to set `catchment_selection` (see `config.pro.example` and `scripts/gmip4/README.md`) |

```bash
cd <repository>
echo '.r glogem' | GLOGEM_CONFIG=/abs/path/my_config.pro GLOGEM_LOGDIR=/abs/path/logs idl
```
