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
| `hindcast_dynamic` | `'n'` | `'y'` to allow dynamic geometry in the historical period |
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
| `glacier_retreat` | `'y'` | Activate annual glacier geometry update |
| `advance` | `'y'` | Allow glacier advance |
| `frontal_ablation` | `'y'` | Activate calving for marine-terminating glaciers |
| `refreezing_parametrised` | `'y'` | Activate parametrised refreezing |
| `refreezing_full` | `'n'` | Activate full physics refreezing (slow) |
| `firnice_temperature` | `'n'` | Activate englacial firn/ice temperature model |
| `debris_supraglacial` | `'n'` | Activate supraglacial debris model |

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
