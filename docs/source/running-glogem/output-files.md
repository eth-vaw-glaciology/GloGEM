# Output Files

All output is written to the directory specified by `dirres` in `config.pro`. Within that directory, GloGEM creates a folder hierarchy based on time resolution, region, GCM, and SSP.

---

## Directory structure

```
<dirres>/
└── <time_resolution>/              (daily or monthly)
    └── <dir_region>/               (e.g. CentralEurope)
        ├── calibration/            (calibration run output)
        ├── PAST/                   (historical / reanalysis-direct runs)
        ├── files/                  (future projection runs)
        │   └── <GCM_model>/
        │       └── <SSP>/
        │           └── <glacier_ID>.dat
        └── SINGLE/                 (single-glacier runs)
```

Historical runs (where `tran[1]` is before the current year, or `reanalysis_direct = 'y'`) write output to `PAST/`. Future projection runs write to `files/<GCM>/<SSP>/`. A copy of `settings.pro` is also written into the output folder at the end of each future run for reproducibility.

---

## Standard annual output files

Each glacier produces one output file containing an annual time series. The default variable set (`full_output = 'n'`) is:

| Variable | Unit | Description |
|----------|------|-------------|
| `Area` | (km²) | Glacier total area |
| `Volume` | (km³) | Glacier total ice volume |
| `Annual_Balance_sfc` | (m w.e.) | Glacier-wide annual surface mass balance |
| `Winter_balance_sfc` | (m w.e.) | Glacier-wide winter surface mass balance |
| `Icemelt_sfc` | (m/yr) | Glacier-wide annual ice and firn melt |
| `Snowmelt_sfc` | (m/yr) | Glacier-wide annual snowmelt|
| `Accumulation_sfc` | (m w.e.) | Glacier-wide annual snow accumulation |
| `Rain_sfc` | (m/yr) | Glacier-wide annual liquid precipitation |
| `ELA` | (m a.s.l.) | Equilibrium line altitude |
| `AAR` | (%) | Accumulation area ratio |
| `Refreezing_sfc` | (m w.e.) | Glacier-wide annual refreezing |
| `Hmin` | (m a.s.l.) | Minimum glacier surface elevation (terminus) |
| `Frontal_ablation` | (m w.e.) | Specific frontal ablation (marine-terminating glaciers) |
| `Discharge` | (m/yr) | Total catchment discharge |
| `Discharge_gl` | (m/yr) | Glacier contribution to discharge |

---

## Extended output (`full_output = 'y'`)

Setting `full_output = 'y'` adds daily resolved variables to the output:

**Monthly model — additional variables:**

| Variable | Unit | Description |
|----------|------|-------------|
| `Discharge_gl` | (m/month) | Monthly Discharge evolving glacier area |
| `Discharge` | (m/month) | Monthly Discharge  intial glacier area |


**Daily model — additional variables:**

| Variable | Unit | Description |
|----------|------|-------------|
| `Accumulation_day` | (m w.e.) | Daily accumulation |
| `Rain_day` | (mm/day) | Daily liquid precipitation |
| `Snowmelt_day` | (mm/day) | Daily snowmelt |
| `Icemelt_day` | (mm/day) | Daily ice and firn melt |
| `Refreezing_day` | (mm/day) | Daily refreezing |
| `Discharge_gl` | (mm/day) | Daily Discharge evolving glacier area |
| `Discharge` | (mm/day) | Daily Discharge  intial glacier area |
| `Snowline_day` | (m a.s.l.) | Daily transient snowline altitude |

```{note}
Discharge variables are not available for 2300 runs (`long_GCM = 'long_'`).
```

---

## Elevation band output

Activated with `write_mb_elevationbands = 'y'`. Writes seasonal (winter and summer) mass balance per elevation band for each glacier, in addition to the standard glacier-wide files.

---

## Hypsometry evolution output

Activated with `write_hypsometry_files = 'y'`. Writes the full elevation-band hypsometry (area, thickness, surface elevation per band) at each time step for every glacier. Files are compressed (zipped) at the end of the run. This output can be large for full regional runs.

---

## Firn and ice temperature output

Activated with `firnice_temperature = 'y'`. Controlled by `firnice_write = ['y', 'y']`:

| `firnice_write` element | Description |
|------------------------|-------------|
| First element `'y'` | Write annual mean firn/ice temperature time series |
| Second element `'y'` | Write detailed vertical temperature profiles at selected elevation ratios |

Profile output elevations are set by `firnice_profile` (default: 0.2, 0.65, and 0.95 of the glacier elevation range).

---

## Log files

A timestamped log file capturing all console output is written to `logs/` in the repository root:

```
logs/glogem_<YYYY>_<Mon><DD>_<HH>h<MM>m.log
```

The log records settings, regional progress messages, and the total runtime.
