# Output Options

There are **two completely independent output systems** that can run at the same time, controlled by separate switches in `config.pro`:

1. **`.dat` files** — the classic GloGEM text output (written when `write_file='y'`)
2. **NetCDF files** — GlacierMIP4-compliant `.nc` output (only when `write_netcdf='y'`)

You can have one, the other, or both. They draw from the same internal model arrays but format and split them differently.

---
## Directory structure

```
<dirres>/
└── <time_resolution>/                  (daily or monthly)
    └── <dir_region>/                   (e.g. CentralEurope)
        ├── calibration/                (calibration run output)
        │
        ├── PAST<version_past><mtt>/     (historical / reanalysis-direct runs)
        │   │                             (mtt suffix: '' | _m3 [energy-balance] | _debris)
        │   ├── PAST_original/           (.dat output, reanalysis naming)
        │   │   └── dyn/                 (only for dynamic hindcast runs)
        │   └── PAST_netcdf/             (NetCDF output — only if write_netcdf='y')
        │                                  GloGEM_rgiXX[_<catchment>][indiv]_<FORCING>_annual.nc
        │                                  GloGEM_rgiXX[_<catchment>][indiv]_<FORCING>_<monthly|daily>.nc
        │
        └── files<mtt>/                  (projection runs)
            ├── files_original/          (.dat output)
            │   ├── <GCM_model>/
            │   │   └── <SSP>/           (per-variable .dat files,
            │   │                          e.g. <region>_Area_r1[_<catchment>].dat, plus
            │   │                          _bias.dat, _SLE_volbz.dat, _calving_flux.dat)
            │   └── SINGLE/              (single-glacier runs)
            └── files_netcdf/            (NetCDF output — only if write_netcdf='y')
                ├── full/                (full projection period; GCM/SSP naming)
                │                          GloGEM_rgiXX[_<catchment>][indiv]_<GCM>_<SSP>_annual.nc
                │                          GloGEM_rgiXX[_<catchment>][indiv]_<GCM>_<SSP>_<monthly|daily>.nc
                └── split/               (only if netcdf_split='y' — future portion, GCM/SSP naming;
                                           the past portion is written to PAST_netcdf/ with reanalysis naming)
```

> **NetCDF file naming:** `indiv` is inserted for the individual-glacier files; `_<catchment>` only
> appears for catchment runs; `<FORCING>` (reanalysis, e.g. `ERA5`) and `<GCM>` are **uppercase**,
> `<SSP>` is **lowercase** (e.g. `ssp126`); the region number is zero-padded (`rgi01`).
>
> **Aggregated daily runs:** when `netcdf_daily_aggregated_monthly='y'` (see §5), a *daily* run writes
> its NetCDF sub-annual files with the `_monthly.nc` label, but they still live under the `daily/`
> output tree (the top folder is `time_resolution`).

---

## 1. The `.dat` (text) output

The original GloGEM format. **One file per variable**, one row per glacier.

**Which variables** come from the `outf_names` list in `procedures/initialise/settings.pro`. The list depends on `full_output`:

- **`full_output='n'`** (reduced) → 15 variables:
  `Area, Volume, Annual_Balance_sfc, Winter_balance_sfc, Icemelt_sfc, Snowmelt_sfc, Accumulation_sfc, Rain_sfc, ELA, AAR, Refreezing_sfc, Hmin, Frontal_ablation, Discharge, Discharge_gl`
- **`full_output='y'`** → the same 15 **plus** 5 sub-annual (monthly or daily) series.

**Monthly/daily split for `.dat`:** the *extra* variables differ by `time_resolution`:

| | Monthly (`write_results_files_monthly.pro`) | Daily (`write_results_files_daily.pro`) |
|---|---|---|
| Sub-annual vars | `Balance_mon, Precipitation_mon, Accumulation_mon, Melt_mon, Refreezing_mon` | `Accumulation_day, Rain_day, Snowmelt_day, Icemelt_day, Refreezing_day, Snowline_day` |
| Row layout | 12 values per year, concatenated | 365 values per year, with year + area prepended per row |

**Units in `.dat`:**
- Surface mass-balance variables (`*_sfc`) → **m w.e.** (metres water equivalent).
- `Area` → **km²**, `Volume` → **km³**, `ELA`/`Hmin` → **m**, `AAR` → **percent** (one decimal).
- `Frontal_ablation`/`Discharge` → native model units (m w.e. / discharge units).
- **Daily** sub-annual values are converted to **mm/day** before writing and reordered to the **hydrological year** (day 274, 275 … 273).
- **Monthly** sub-annual values are **not** rescaled — they stay in native per-month m w.e.

> The `.dat` output is unaffected by the NetCDF-only changes (RGIId formatting, AAR-as-fraction,
> daily→monthly aggregation). It always stays in its native units and resolution.

**Past vs. future for `.dat`:** done by **folder**, not by file content
(`initialise_results_files.pro`, `setup_output_folders.pro`):
- A **hindcast/reanalysis** run (`reanalysis_direct='y'`, period ends in the past) → `PAST.../PAST_original/`
- A **projection** run (starting in the past and continuing into the future) → `files/files_original/<GCM>/<SSP>/`.

A `.dat` run is *either* past *or* projection depending on the run; it does not split a single projection into two. The whole modelled period goes into one set of files in the folder matching the run type.

---

## 2. The NetCDF output (`write_netcdf='y'`)

Follows **GlacierMIP4 conventions** (CF-1.8, `days since 1850-01-01` time axis). For every run it writes **4 files** — a *regional* pair and an *individual-glacier* pair:

- `GloGEM_rgiXX_<FORCING>_annual.nc` — regional annual
- `GloGEM_rgiXX_<FORCING>_monthly.nc` (or `_daily.nc`) — regional sub-annual
- `GloGEM_rgiXXindiv_<FORCING>_annual.nc` — per-glacier annual
- `GloGEM_rgiXXindiv_<FORCING>_monthly.nc` / `_daily.nc` — per-glacier sub-annual

(Projection runs use `<GCM>_<SSP>` in place of `<FORCING>`.)

**Variables differ between the regional and individual files.** The regional files carry the
GlacierMIP4 *mandatory* variables (Tables 3 & 4); the individual files additionally carry the
*optional* per-glacier variables (Table 5):

| | Annual file | Sub-annual file |
|---|---|---|
| **Regional** | `area, mass, mass_bsl, frontal_abl` | `acc, melt, refreeze, runoff_glac, precip, temp` |
| **Individual** (`indiv`) | + `ELA, AAR` | + `runoff_basin` |

So an individual annual file has `area, mass, mass_bsl, frontal_abl, ELA, AAR`, and an individual
sub-annual file has `acc, melt, refreeze, runoff_glac, precip, temp, runoff_basin`.

**Glacier identifier (`indiv` files):** the `RGIId` variable holds the full RGI 7 ID string,
built as `RGI<version>0-<region>.<id>` — e.g. **`RGI70-11.02596`** (not the bare `02596`).

**Monthly vs. daily in NetCDF** (`init_netcdf_hindcast.pro` / `init_netcdf_projections.pro`): the
sub-annual time dimension is `years×12` (monthly) or `years×365` (daily — **fixed 365-day year**,
no leap days), and the filename label switches between `monthly`/`daily`. Same variables either way.

**Units** — everything is converted to **SI** units, unlike `.dat`:

Annual file:
- `area` → **m²** (km² × 1e6)
- `mass` → **kg** (volume km³ × 900e9, ice density 900 kg/m³)
- `mass_bsl` (mass below sea level) → **kg**
- `frontal_abl` → **kg**
- `ELA` → **m** (individual files; `cell_methods = maximum`)
- `AAR` → **fraction 0–1** (individual files, `units='1'`; `cell_methods = maximum`) — note this is a
  fraction, while the `.dat` `AAR` is in percent

Sub-annual file:
- `acc`, `melt`, `refreeze`, `runoff_glac`, `precip` (and `runoff_basin` in `indiv`) → all **kg** (`time: sum`)
- `temp` (near-surface air temperature) → **K** (`time: mean`, area-weighted)

Unit conversions are applied in `write_netcdf_glacier.pro`. Missing/non-glacier values are set to NaN `_FillValue`.

### `cell_methods` (the `time: …` attribute)

CF metadata describing how each value relates to its time interval:
- **`time: sum`** → total accumulated over the time step (a flux). Aggregate across time by **adding**.
- **`time: mean`** → average over the time step (a state). Aggregate by **averaging**.
- **`time: point`** → instantaneous snapshot at that time (used for annual `area`, `mass`, `mass_bsl`, `frontal_abl`).
- **`time: maximum`** → used for `ELA` and `AAR` (annual, individual files).

### Where NetCDF goes
- Hindcast run → `PAST/PAST_netcdf/` (reanalysis naming, e.g. `ERA5`)
- Projection run → `files/files_netcdf/full/` (GCM + SSP naming)

---

## 3. The past/future *split* — NetCDF only

Controlled by `netcdf_split` / `netcdf_split_year`. There is **no `.dat` equivalent**.
(`init_netcdf_projections.pro`)

- A projection run normally produces one **full-period** set of files (`files_netcdf/full/`).
- If **`netcdf_split='y'`**, the projection is *additionally* cut at **`netcdf_split_year`** into two extra sets:
  - **Past portion** (`tran[0]` … `split_year−1`) → `PAST/PAST_netcdf/` with **reanalysis naming**
  - **Future portion** (`split_year` … `tran[1]`) → `files/files_netcdf/split/` with **GCM/SSP naming**

The split is a pure index cut on the already-computed arrays (`nc_split_idx = netcdf_split_year - tran[0]`), applied to both annual and sub-annual data. You get the full file *plus* a cleanly separated past file (reanalysis-style naming) and a future-only file — without rerunning anything.

> ⚠️ The split *past* file is still the **GCM-forced** historical slice (bias-corrected), not a true
> ERA5-forced hindcast. For a GlacierMIP4 hindcast submission, run a separate reanalysis-direct run.

---

## 4. Which area is each NetCDF variable referenced to?

GloGEM tracks two area concepts per glacier (per elevation band):
- **`area_ini`** — the **constant** initial glacier footprint, held fixed for the whole run (`area_iniconst` is the immutable copy; `area_ini` only changes under the advance scheme).
- **`ar_gl`** — the **evolving** glacierized area, i.e. the sum over bands still classified as glacier in that year. It **shrinks as the glacier retreats**.

The choice of area matters because a per-area-normalised flux is multiplied back by an area to produce the kg values in the NetCDF files.

| NetCDF variable | File(s) | Unit | `cell_methods` | Area basis (monthly) | Area basis (daily) |
|---|---|---|---|---|---|
| `area` | both, annual | m² | point | evolving (`areas[ye]`) | evolving (`areas[ye]`) |
| `mass` | both, annual | kg | point | from evolving volume | from evolving volume |
| `mass_bsl` | both, annual | kg | point | from evolving volume | from evolving volume |
| `frontal_abl` | both, annual | kg | sum | evolving (`areas[ye]`) | evolving (`areas[ye]`) |
| `ELA` | indiv, annual | m | maximum | n/a (elevation) | n/a (elevation) |
| `AAR` | indiv, annual | 1 (fraction) | maximum | n/a (ratio) | n/a (ratio) |
| `acc` (accumulation) | both, sub-annual | kg | sum | **evolving** (`ar_gl`) | **constant** (`area_ini`) |
| `melt` | both, sub-annual | kg | sum | **evolving** (`ar_gl`) | **constant** (`area_ini`) |
| `refreeze` | both, sub-annual | kg | sum | **evolving** (`ar_gl`) | **constant** (`area_ini`) |
| `runoff_glac` | both, sub-annual | kg | sum | **evolving** (`ar_gl`) | **evolving** (`ar_gl`) |
| `runoff_basin` | indiv, sub-annual | kg | sum | **constant** (`area_cat`) | **constant** (`area_cat`) |
| `precip` | both, sub-annual | kg | sum | **constant** (`area_ini`) | **constant** (`area_ini`) |
| `temp` | both, sub-annual | K | mean | **constant** (`area_ini`) | **constant** (`area_ini`) |

**Key takeaways / caveats:**
- `runoff_glac` is "moving-gauge" runoff from the **evolving** glacierized area: as the ice disappears, the contributing area disappears with it. It does *not* include runoff from deglaciated terrain.
- `runoff_basin` (individual files) is the "fixed-gauge" runoff over the **initial** glacierized footprint, including the deglaciated-terrain correction.
- `temp` and `precip` are always tied to the **constant initial footprint**, so they don't shrink with retreat.
- The **daily** sub-annual file is internally consistent on area for the mass-balance fluxes: `acc/melt/refreeze` and `precip`/`temp` are all on the constant initial area; only `runoff_glac` is on the evolving area.
- The **monthly** sub-annual file is *mixed*: `acc/melt/refreeze` and `runoff_glac` are on the evolving area, while `precip`/`temp` are on the constant initial area.
- A **daily run aggregated to monthly** (§5) keeps the daily area basis — `acc/melt/refreeze` stay on the **constant initial** area (this is an open item under review).
- Because of this, do **not** expect `runoff_glac ≈ melt + precip − refreeze` to close exactly — the terms are normalised to different areas (and differently between the monthly and daily files).

### Where `temp` and `precip` originate in the code

Both come from a single per-glacier climate series (read at reference elevation `hclim`) that is downscaled to every elevation band **and corrected with the glacier's calibration parameters**, then aggregated:

1. **Raw input** — `temp` [°C] and `prec` [mm] at a reference point, plus lapse rate `dtdz`:
   - hindcast: `read_climatepast_{daily,monthly}.pro`
   - projection: `downscale_gcmdata_{daily,monthly}.pro` (bias-corrected GCM data)

2. **Extrapolation to bands + calibration corrections:**
   - Temperature (`glogem.pro`): `tg = temp[...] + (elev − hclim)*dtdz + t_offset`
   - Precipitation (`accumulation.pro`): `pc = prec*c_prec/1000`; extrapolated with `dpdz`; split by `T_thres` into snow `psg` and rain `plg`; snow scaled by `snow_multiplier`.

3. **Aggregation to NetCDF (`initialise_netcdf_vars.pro`):**
   - `temp = total((tg+273.15)*area_ini)/total(area_ini)` → area-weighted mean [K]
   - `precip = total((psg+plg)*area_ini)` → sum of snow+rain [m w.e.·km²] → ×1e9 → kg

So `temp` and `precip` are derived from exactly the same downscaled band-level meteorology that drives the mass balance, aggregated over the constant initial area.
The forcing written to NetCDF already includes GloGEM's glacier-specific calibration corrections — it is **not** the raw reanalysis/GCM input:

- **`temp`** includes the calibrated **temperature bias `t_offset`** (calibration phase 3, "T-bias"), read per glacier via `apply_calibration_params.pro` (`t_offset = cali_toff[ind]`). The written temperature is therefore the lapse-rate-extrapolated, bias-corrected temperature that actually drives the melt model.
- **`precip`** includes the calibrated **precipitation correction factor `c_prec`** (calibration phase 1) and the **`snow_multiplier`** applied to the solid fraction. The written precipitation is therefore the corrected precipitation that actually drives accumulation.
- Because `t_offset` and `c_prec` are **glacier-specific**, the corrections differ per glacier, so the regional area-weighted `temp` and summed `precip` reflect a mix of each glacier's individually calibrated forcing rather than a single regional correction.

---

## 5. Daily → monthly NetCDF aggregation (`netcdf_daily_aggregated_monthly`)

When running the model **daily**, you can optionally report the **NetCDF** output at monthly
resolution while keeping the `.dat` output daily. This is for GlacierMIP4-style submissions where the
model is *forced* daily (better climate variability) but the results are reported monthly.

- `netcdf_daily_aggregated_monthly = 'n'` (default) → NetCDF sub-annual output is daily (`_daily.nc`).
- `netcdf_daily_aggregated_monthly = 'y'` → NetCDF sub-annual output is aggregated to monthly
  (`_monthly.nc`, `years×12`); the `.dat` output stays daily.

The switch is **only active** when `time_resolution='daily'` **and** `write_netcdf='y'`; it is forced
to `'n'` otherwise.

**How the aggregation works** (`write_netcdf_glacier.pro`): the daily sub-annual arrays are binned
into 12 calendar months using fixed month lengths `[31,28,…]` (summing to 365). Fluxes
(`acc, melt, refreeze, runoff_glac, runoff_basin, precip`) are **summed** within each month; `temp` is
**averaged**. The kg conversions then follow the same rules as a daily run, so `acc/melt/refreeze`
remain on the **constant initial area** (see §4 caveat).

Annual variables are unaffected by this switch.

---

## Quick overview

| Aspect | `.dat` | NetCDF |
|---|---|---|
| Switch | `write_file='y'` | `write_netcdf='y'` |
| Granularity | one file per variable, per-glacier rows | regional + per-glacier, all vars in 2 files each |
| Monthly/daily | extra var list differs; daily → mm/day, hydro-year reordered | time dim 12 vs 365; daily can be aggregated to monthly (`netcdf_daily_aggregated_monthly`) |
| Units | mixed (m w.e., km², km³, mm/day, AAR percent) | all mass in **kg**, area in **m²**, temp in **K**, AAR fraction |
| Identifier | glacier ID (e.g. `02596`) | full RGI 7 string (e.g. `RGI70-11.02596`) |
| Past/future | by **folder** (run is past *or* projection) | full period always; **`netcdf_split`** also writes separate past + future files |

**Example config** (`time_resolution='daily'`, `full_output='y'`, `write_netcdf='y'`, `netcdf_split='y'`, `netcdf_split_year=2025`, `netcdf_daily_aggregated_monthly='y'`) produces the daily `.dat` set **and** the full + split (past/future) NetCDF set with sub-annual files aggregated to monthly.
