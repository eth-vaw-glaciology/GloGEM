# Climate Data
```{note}
This section might be updated when new climate data becomes available.
```

GloGEM requires gridded near-surface air temperature and precipitation for both the historical (reanalysis) and future (GCM) periods. All climate files are stored on the VAW shared storage under:

```
/itet-stor/<username>/glogem/climatedata/
```

---

## Reanalysis data (historical forcing)

Reanalysis data provides the reference climate for the calibration period and is used as the basis for bias-correcting GCM output.

### Storage path

```
climatedata/reanalysis/<time_resolution>/<reanalysis>/<region>/
```

### Available reanalysis products

| Setting value | Product | Time resolution | Period|
|---------------|---------|----------------|--------|
| `era5` | ERA5 (ECMWF) | Daily | 1940-2025 |
| `ERA5` | ERA5 (ECMWF) | Monthly | 1950-2025 |
| `era5land` | ERA5-Land | Daily | 1950-2025 |
| `chelsaw5e5` | CHELSA-W5E5 | Daily | 1979-2016 |
| `ch2018` | CH2018 | Daily | |
| `gswp3w5e5` | GSWP3-W5E5 | Daily | 1901-2019 |

The active product is set with `reanalysis` in `config.pro` or `settings.pro`.

### Reanalysis for the daily model version

For the **daily** model version the reanalysis data is given in the following format:
| File | Contents |
|------|----------|
| `clim_<lon>_<lat>.dat` | Temperature and Precipitation for each reanalysis grid stored as .dat files. lon and lat refer to the center coordinates of each grid cell. |
| `longitudes.dat` | List of all longitudes of the reanalysis grid cells. |
| `latitudes.dat` | List of all latitudes of the reanalysis grid cells |

Each file is has a plain-text header followed by the data arrays. The header contains grid dimensions, time vector, and coordinate arrays.

Below an example of how the files look like:

```
Meteorological data for ERA5-land grid cell 6.70(lon)_45.30(lat)
Grid cell elevation (masl): 2404.8
Year  Month  DOY  decimal.time  temp(degC)  prec(mm)  dT/dz(deg/100m)
1950     1     1    1950.0000    -10.060      0.016   -0.58157
1950     1     2    1950.0026     -8.231      0.008   -0.58157

```
#### Variables

| Variable | Description |
|----------|-------------|
| `temp(degC)` | Air temperature per grid cell per time step (°C) |
| `prec(mm)` | Precipitation per grid cell per time step (mm d⁻¹) |
| `dtdz(deg/100m)` | Temperature gradient per grid cell|


### Reanalysis for the monthly model version
For the **monthly** model version the reanalysis data is given in the following format:
| File | Contents |
|------|----------|
| `clim_<region>.mdi` | Gridded monthly temperature and precipitation fields. |
| `variability_<region>.mdi` | List of all longitudes of the reanalysis grid cells. |
| `tgrad_<region>.mdi` | Monthly vertical temperature gradient fields |

Each file is a custom binary format with a plain-text header (.mdi) followed by the data arrays. The header contains grid dimensions, time vector, and coordinate arrays.

### Variables

| Variable | Description |
|----------|-------------|
| `rtemp` | Air temperature per grid cell per time step (°C) |
| `rprec` | Precipitation per grid cell per time step (mm month⁻¹) |
| `relev` | Grid cell reference elevation (m a.s.l.) |
| `rtg` | Monthly vertical temperature gradient (°C m⁻¹) |
| `rvariab` | Daily temperature anomaly patterns within each month |

---

## GCM data (future forcing)

GCM projections are bias-corrected against the reanalysis reference and used for future simulations.

### Storage path

#### Daily

```
climatedata/future/<time_resolution>/<GCM_data>/<region>/<GCM_model>/<SSP>/
```

#### Monthly
```
climatedata/future/<time_resolution>/<GCM_data>/<region>/<GCM_model>/
    <GCM_model>_<SSP>_<experiment>_<region>.mdi
```

For extended runs to 2300, `long_` is prepended to `<GCM_data>`:

```
climatedata/future/<time_resolution>/long_<GCM_data>/<region>/...
```

### Available GCM products

| Setting value | Product | Time resolution | Period| number of GCMS|
|---------------|---------|----------------|--------|---------------|
| `cmip6` | CMIP6 | Monthly and Daily | until 2100 | 26|
| `cmip6isimip3b` | CMIP6-ISIMIP3B | Daily | until 2100 | 5|
| `gmip3` | GCMs provided for GlacierMIP3 | ? | until 2100 | 5|
| `gmip4` | GCMs provided for GlacierMIP4 | ? | until 2100 | ?|
| `long_cmip6` | CMIP6 | Monthly | until 2300 |11|


The active product is set with `GCM_data` in `config.pro` or `settings.pro`.

### Available SSPs
Depending on the GCM data and the region different ssps are available.

`ssp119`, `ssp126`, `ssp245`, `ssp370`, `ssp534-over`, `ssp585`

### Variables
#### Daily model
Each file is has a plain-text header followed by the data arrays. The header contains grid dimensions, time vector, and coordinate arrays.

Below an example of how the files look like:

```
Meteorological data for ERA5-land grid cell 6.70(lon)_45.30(lat)
Grid cell elevation (masl): 2404.8
Year  Month  DOY  decimal.time  temp(degC)  prec(mm)  dT/dz(deg/100m)
1950     1     1    1950.0000    -10.060      0.016   -0.58157
1950     1     2    1950.0026     -8.231      0.008   -0.58157

```

| Variable | Description |
|----------|-------------|
| `temp(degC)` | Air temperature per grid cell per time step (°C) |
| `prec(mm)` | Precipitation per grid cell per time step (mm d⁻¹) |
| `dtdz(deg/100m)` | Temperature gradient per grid cell|


#### Monthly model
| Variable | Description |
|----------|-------------|
| `gcm_temp` | GCM air temperature (°C) |
| `gcm_prec` | GCM precipitation (mm d⁻¹) |
| `gcm_elev` | GCM grid cell reference elevation (m a.s.l.) |

---

## Bias correction

Raw GCM output is systematically offset from the reanalysis reference. GloGEM corrects these biases before applying GCM data to the glacier model. Bias correction is implemented in `procedures/processing/bias_correction_delta.pro` and `bias_correction_qm.pro`, and is activated with `bias_correction = 'y'`.

The correction is computed over an overlap period shared by both the reanalysis and the GCM historical run, set by `rea_eval` (default: 1991–2020).

### Method 1 — Delta method (default)

Selected with `bias_correction_method = 1`. For each calendar month, additive temperature and multiplicative precipitation biases are computed from the overlap period:

$$
\Delta T_m = \overline{T_{\text{GCM},m}} - \overline{T_{\text{rea},m}}
$$

$$
f_{P,m} = \frac{\overline{P_{\text{GCM},m}}}{\overline{P_{\text{rea},m}}}
$$

These monthly offsets are then applied to the full GCM time series. A temperature variability scaling factor is also computed:

$$
\sigma_m = \frac{\sigma(T_{\text{rea},m})}{\sigma(T_{\text{GCM},m})}
$$

To prevent unrealistic corrections in high-latitude or data-sparse regions, extreme biases can be clamped via `min_tempbias` and `min_precbias`.

### Method 2 — Quantile mapping

```{note}
This downscaling method is currently being implemented and tested in GloGEM.
```
.
Selected with `bias_correction_method = 2`. Available for daily temperature only. Builds empirical cumulative distribution functions (CDFs) at 1001 quantile levels for:

- Reanalysis historical period
- GCM historical overlap period
- GCM future period

The transfer function maps each GCM future quantile to the corresponding reanalysis quantile, preserving the full distribution shape rather than only correcting the mean.

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `bias_correction` | `'y'` | Apply bias correction to GCM data |
| `bias_correction_method` | 1 | Bias correction method: 1 = delta, 2 = quantile mapping |
| `rea_eval` | `[1991, 2020]` | Reference period (years) for bias computation |
| `min_tempbias` | — | Minimum allowed temperature bias (°C); clamps extreme high-latitude corrections |
| `min_precbias` | — | Minimum allowed precipitation bias factor |
