# Geometric Data

GloGEM's geometric input consists of the glacier inventory, per-glacier hypsometry and ice thickness, and supraglacial debris observations. All geometric data are stored on the VAW shared storage under:

```
/itet-stor/<username>/glogem/geometricdata/rgiv<version>/
```

---

## Ice thickness datasets by RGI version

The ice thickness and hypsometry dataset used depends on the RGI version (`RGIversion` in `settings.pro`):

| RGI version | Primary thickness dataset | Fallback dataset |
|-------------|--------------------------|-----------------|
| RGI 6.0 | Farinotti et al. (2019) — consensus estimate ([doi:10.1038/s41561-019-0300-3](https://doi.org/10.1038/s41561-019-0300-3)) | Huss & Farinotti (2012) ([doi:10.1029/2012JF002523](https://doi.org/10.1029/2012JF002523)) |
| RGI 7.0 | Maffezzoli et al. (2025) — global thickness from RGI 7.0 outlines ([doi:10.5194/gmd-18-2545-2025](https://doi.org/10.5194/gmd-18-2545-2025)) | Huss & Farinotti (2012) ([doi:10.1029/2012JF002523](https://doi.org/10.1029/2012JF002523)) |

Both the primary and fallback files share the same format and are stored in separate subdirectories (see [Hypsometry files](#hypsometry-files) below).

---

## Glacier inventory batch file

For each RGI region, a batch file lists all glaciers with their key inventory attributes. This file drives the glacier loop and provides area, volume, and coordinate metadata.

### Storage path

```
geometricdata/rgiv<version>/files/thick_<region>.dat
```

For RGI 7.0 runs, a second batch file is also read to derive per-glacier area correction factors (see [RGI 7.0 area correction](#rgi-70-area-correction)):

```
geometricdata/rgiv7/files_HF/thick_<region>.dat
```

### Contents

One row per glacier (semicolon-delimited ID, then 19 space-separated values):

| Column (0-based) | Variable | Unit | Description |
|-----------------|----------|------|-------------|
| ID | — | (—) | RGI glacier ID |
| 0 | `lon_gl` | (°) | Glacier centroid longitude |
| 1 | `lat_gl` | (°) | Glacier centroid latitude |
| 2 | `a_gl` | (km²) | Glacier area |
| 3 | `volume_ini` | (km³) | Initial ice volume |
| 4 | THICK_mean | (m) | Mean ice thickness |
| 5 | THICK_max | (m) | Maximum ice thickness |
| 6 | `hmin` | (m a.s.l.) | Minimum surface elevation |
| 7 | ELEV_max | (m a.s.l.) | Maximum surface elevation |
| 8 | `hmed` | (m a.s.l.) | Median surface elevation |
| 9 | LENGTH | (km) | Glacier length |
| 10 | SLOPE_avg | (°) | Average surface slope |
| 11 | SLOPE_band | (°) | Average band slope |
| 12 | TAU_avg | (bar) | Average basal shear stress |
| 13 | TAU_min | (bar) | Minimum basal shear stress |
| 14 | TAU_max | (bar) | Maximum basal shear stress |
| 15 | SF_avg | (—) | Average shape factor |
| 16 | SF_min | (—) | Minimum shape factor |
| 17 | R_V | (—) | Volume ratio |
| 18 | `survey_year` | (—) | RGI inventory survey year |

---

## Hypsometry files

Each glacier is represented by an elevation-band file that combines the RGI outline geometry with the ice thickness distribution from the dataset for the configured RGI version.

### Storage paths

Primary dataset (Farinotti et al. 2019 for RGI 6.0; Maffezzoli et al. 2025 for RGI 7.0):

```
geometricdata/rgiv<version>/bands/<region>/<RGI_ID>.dat
```

Fallback dataset (Huss & Farinotti 2012, used when the primary file fails quality checks):

```
geometricdata/rgiv<version>/bands_HF/<region>/<RGI_ID>.dat
```

### Fallback logic

The fallback to the Huss & Farinotti (2012) dataset is triggered by different conditions depending on the RGI version:

**RGI 6.0** — fallback is applied if either of the following holds:
- The minimum band start elevation in the primary file is below −300 m a.s.l. (implausible data), or
- The total band area from the primary file disagrees with the inventory area by more than 50%.

**RGI 7.0** — fallback is applied only for very small glaciers (area < 0.25 km²), and only if a Huss & Farinotti file exists for that glacier.

### RGI 7.0 area correction

For RGI 7.0 runs, band areas in the primary (Maffezzoli) hypsometry file are corrected for a known area bias before the glacier is processed. The correction factor is derived per glacier as the ratio of the Huss & Farinotti (2012) area to the Maffezzoli area, read from `files_HF/thick_<region>.dat`. After applying this factor to all band areas, the initial ice volume (`volume_ini`) is recomputed to remain consistent.

### File format

Plain-text file with a 5-line header followed by one row per elevation band. Each row contains 12 columns:

| Column index | Variable | Unit | Description |
|-------------|----------|------|-------------|
| 0 | Band-ID | (—) | Sequential band index |
| 1 | Elev_start | (m a.s.l.) | Lower boundary of elevation band |
| 2 | Elev_end | (m a.s.l.) | Upper boundary of elevation band |
| 3 | Area | (km²) | Band area |
| 4 | Thickness | (m) | Mean ice thickness |
| 5 | Width | (m) | Mean glacier width |
| 6 | Length | (m) | Band length |
| 7 | Slope | (°) | Mean surface slope |
| 8 | Aspect | (—) | Dominant aspect class |
| 9 | b_app | (m a⁻¹) | Apparent mass balance |
| 10 | Basal_stress | (bar) | Basal shear stress |
| 11 | Shape_factor | (—) | Valley shape factor |

Elevation bands are 10 m wide (Elev_end − Elev_start = 10 m). Bands are ordered from the lowest (terminus) to the highest (headwall) elevation. Columns 9–11 use −99 as a no-data fill value where observations are unavailable.

---

## Debris observations

Per-glacier supraglacial debris properties are stored alongside the hypsometry data. They are read when `debris_supraglacial = 'y'`.

### Storage path

```
geometricdata/rgiv<version>/bands/debris/<region>/debris_<RGI_ID>.dat
geometricdata/rgiv<version>/bands/debris/<region>/factor_<RGI_ID>.dat
```

If no debris file exists for a glacier, all debris properties default to zero (no debris) and the melt reduction factor defaults to 1 (no reduction).

### `debris_<RGI_ID>.dat` — per-band debris properties

Plain-text file with a 5-line header, one row per elevation band, 8 columns:

| Column index | Variable | Description |
|-------------|----------|-------------|
| 4 | `debris_frac` | Debris coverage fraction per band (0–1) |
| 5 | `debris_thick` | Mean debris thickness per band (m) |
| 6 | `debris_mf` | Melt reduction factor (0–1; 1 = no debris) |
| 7 | `debris_ponddens` | Supraglacial pond and ice-cliff density per band (0–1) |

### `factor_<RGI_ID>.dat` — Östrem-curve lookup table

Provides the debris-thickness-dependent melt reduction factor (Östrem curve) for the glacier. Three columns:

| Column index | Variable | Description |
|-------------|----------|-------------|
| 1 | `debris_type_th` | Debris thickness levels (m) |
| 2 | `debris_type_red` | Corresponding melt reduction factors (0–1) |

This lookup table is used in `procedures/processing/calculatedebrismelt.pro` to scale sub-debris melt as a function of local debris thickness.
