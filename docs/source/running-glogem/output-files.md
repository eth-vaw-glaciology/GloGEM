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

The monthly model writes the same snowline as `Snowline_mon` (one value per month).

```{note}
Discharge variables are not available for 2300 runs (`long_GCM = 'long_'`).
```

### Snowline

The snowline is the middle of the highest glacier band without snow. If the whole glacier is snow-covered, it is the
glacier's lowest band (its front), so by default it can never go below the front.

With `snowline_ext_depth > 0` (m, e.g. 1500; off by default; set it in your config file) the snowline can drop below
the front:

- **Ground bands.**
  - New 10 m bands continue below the glacier, down to that depth below the inventory front and never below sea level.
  - The glacier's own bands without ice below its lowest ice band count too: advance bands, and bands that have melted
    out, at their bed elevation.
  - Bands below sea level are ignored.
- **Following the terrain (`snowline_ext_valley`).** Set this to a folder with valley-floor files, and each glacier's
  ground bands stop at its own valley floor (never deeper than `snowline_ext_depth`). Bands of the glacier itself below
  that floor are ignored too.
  - **The files** are written once per region by `scripts/valley_floor.py`:
    - It starts at the lowest point of each glacier's outline and follows the valley downhill over the Copernicus
      GLO-90 terrain, in the same way as OGGM's downstream lines.
    - It stops after a set distance (`--distance`, default 10 km), and the lowest terrain on that path is the valley
      floor.
    - It needs Python with geopandas, rasterio, scipy and scikit-image, internet access for the DEM tiles, and the RGI
      outlines of the region.
  - **Glaciers missing from the file** keep `snowline_ext_depth`.
  - **The distance matters.** Large Karakoram valleys are flat below the glaciers. 10 km below the fronts of Biafo,
    Baltoro and Siachen the valley is only 8–165 m lower; 30 km below, 270–470 m; 50 km below, 370–700 m.
- **Their snow pack.** Each band carries a snow pack computed as on glacier bands without ice. Snowfall uses the
  glacier's own temperature offset and precipitation factor; snow melts with its own degree-day factor.
  - **Precipitation on the new bands is that of the inventory front.** It does not keep decreasing with elevation. With
    the linear gradient (`dPdz`) it would reach zero 10000/`dPdz` m below the climate grid point (2000 m in
    SouthAsiaWest), and no snow could ever lie lower.
  - **Snow left over from the year before is removed once a year:** on 1 January in the northern hemisphere; in the
    southern hemisphere in July in monthly runs and on day 181 in daily runs.
  - **Melt starts one time step late on fresh snow on bare ground.** This is main's behaviour on bands without ice.
    The same holds for snow lying at the start of each mass-balance year, which does not melt in that year's first
    step. That is one day in daily runs but a whole month in monthly runs.
  - **Any amount of snow counts as snow cover.**
- **When they are used.**
  - When no glacier band is free of snow, the snowline is the highest snow-free ground band.
  - If all ground bands are snow-covered too, it is the lowest ground band: the snowline is at or below that level.
- **A glacier that has melted away.** By default its snowline is written as −9999. With the option it is the highest
  snow-free band of its former area. Note that daily `.dat` rows carry the initial glacier area.
- **What it does not change.** Every other output is unchanged: mass balance, refreezing, debris melt, geometry and the
  belev files. The snowline is also unchanged whenever a glacier band is snow-free.
- **Requirements.**
  - It needs `meltmodel = '1'`.
  - It does not work with `eval_mbelevsensitivity`.
  - It works daily and monthly, with debris, and in calibration runs. Calibration runs compute the snowline but do not
    write it.
  - The snowline is written with `full_output = 'y'` (`Snowline_day` / `Snowline_mon`) or with `write_netcdf = 'y'`.

```{note}
The ground bands are a simple continuation of the glacier, not real terrain.
- **Without `snowline_ext_valley`, their floor can lie below the real valley floor.** For Aletsch, 1500 m below the
  front is 75 m a.s.l. Either give the valley floors, or compare modelled and observed snowlines only above the local
  valley floor.
- **The glacier's parameters are used off the glacier.** The calibrated temperature offset, precipitation factor and
  degree-day factor apply below the front, so a snowline calibration partly tunes them there.
- **Temperature follows the lapse rate down**, so winter valley inversions are missing.
- **The late melt of fresh snow** gives one-day dips on snowfall days. Comparing multi-day values avoids them.
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
