# Calibration on Snowlines and Geodetic Mass Balance

The method of von der Esch et al. (in review), ported from Alexandra von der Esch's one-script
daily GloGEM (branch `Snowline-calibration`, folder `snowline_calibration/`) into the modular
calibration. The geodetic balance still sets the overall melt; the observed transient snow lines
decide how much of the mass turnover comes from snowfall.

```{note}
Daily runs only (`time_resolution = 'daily'`), melt model 1, glacier-specific targets.
```

## How it works

```
for each precipitation factor c_prec = 0.8, 1.0, ... 3.0        (one pass each)
    phase 2: DDF fitted to the geodetic balance (tolerance snowline_cal_crit = 0.05 m w.e.)
    phase 3: T_off fitted, starting from 0 (moves only if DDF hit its bounds)
    daily snow line of the glacier vs every observed snow line on its day
        -> weighted RMSE, weights 1 / observation uncertainty
    stop at the first rise of the RMSE (or at the last value):
        cubic spline through the RMSE of all values so far -> c_prec at its minimum
    one more pass at that c_prec gives the glacier's DDF and T_off
```

- Every pass runs phases 2 and 3 for the glaciers still scanning; finished glaciers are written
  again from their last run, so each phase file lists all calibrated glaciers.
- Phase 1 is not run. Phase 2 of the first value starts from `DDFsnow0`; each later value starts
  from the DDF of the previous one. There is no second pass with gridded T-offsets.
- A glacier without observations in the modelled period (or without hypsometry) is not
  calibrated by this run and is not written. Give it the standard calibration, e.g. by merging
  with `calibrate_cprec_file` (below).
- One region per run: glacier numbers in the observation file have five digits, without the
  region.

## Differences from her script

- The scan runs over the scanned values only, with one more pass for the final run; her loop
  bound (`N_ELEMENTS` of the glaciers × values array) could index past the scan.
- The range is 0.8–3.0 as in the paper (her `max_cprec/steps_cprec` gave 0.8–3.6).
- Standard calibration file names, and GloGEM's meaning of the `Flag` column; the scan's own
  record is the `_snowline.dat` log.
- Parameters are matched by glacier ID. In her script `cali_id = transpose(id)` (after the
  catchment selection) replaced the IDs read from the phase file, so the DDF of phase 3, and the
  warm start of the next value, were taken from the row with the glacier's inventory position. The
  file is written in grid-cell order, so in a catchment spanning several grid cells this was
  another glacier's DDF.
- A glacier without observations is left out. In her script `where` returned -1 and the RMSE
  used the last observation of the file.
- Observations outside the modelled days are not used (IDL clipped them to the last day); the
  day index starts at `bal_month`, not at a fixed 274.
- The glacier number is the last five characters of the id, so RGI6 and RGI7 ids both work.
- No round with gridded T-offsets (she set `toff_grid = 'n'`).

## Settings

| setting | default | meaning |
|---|---|---|
| `calibrate_snowline` | `'n'` | `'y'` switches the calibration on (needs `calibrate`, `calibrate_individual`, `calibrate_glacierspecific`, `caliphase_loop = 3`) |
| `snowline_cprec_range`, `snowline_cprec_step` | `[0.8, 3.0]`, `0.2` | scanned c_prec values |
| `snowline_cal_crit` | `0.05` | tolerance of the DDF / T_off fit at every value [m w.e.] |
| `snowline_dataset` | `''` | observation file; `''` reads `data/snowline/snowline_<calibrate_glacierspecific_period>/<RGI region>_snowline_median.dat` |
| `snowline_definition` | `'highest_free'` | modelled snow line, see below; also used for the `Snowline_day` / `Snowline_mon` output |
| `calibrate_cprec_file` | `''` | standard calibration in which c_prec is kept fixed, from this file, for the glaciers it lists |

## Observation file

One header line, then one observation per line:

```
RGI70-11.02216   2984.0  105.6 2013 213
<RGI id>  <snow line, m a.s.l.>  <uncertainty, m>  <year>  <day of year>
```

- The glacier number is the last five characters of the id (RGI6 or RGI7 ids).
- The day of year is on GloGEM's daily calendar: 365 days, no 29 February (from 1 March in a leap
  year, the calendar day of year minus one).
- Observations outside the modelled days are not used.

## Which modelled snow line

- `'highest_free'` (her definition): the highest snow-free band; the lowest band if the whole
  glacier is snow-covered. It suits snow lines traced as the snow-ice boundary (Loibl et al., 2025).
- `'p10'`: the 10th percentile of the elevation of the snow-covered area, the statistic of the
  Alpine product of Sommer et al. (ESSD, essd-2026-35). A fully snow-covered glacier then gives its
  own 10th-percentile elevation, as the product does. With `'highest_free'`, those days compare
  the glacier's lowest point with that percentile (about 400 m higher on Morteratsch), and the
  RMSE hardly depends on c_prec.

## Output

Beside the calibration files (standard names; give the run its own `dirres`):
`calibrate_m1_cID<id>_<sub_region><catchment>_snowline.dat`, rewritten after every pass. One line
per glacier: observations used, status (2 done, 1 final run pending, 0 scanning, -1 not
calibrated here), values scanned, c_prec at the minimum, bound flag (-1 / +1: minimum at the
lowest / highest scanned value), RMSE of the final run, and the RMSE at every scanned value
(-99: not run).

## Fixed c_prec in a standard calibration

`calibrate_cprec_file` points to a calibration file (one header line, glacier ID first, Cprec in
column 11). In phase 1 the listed glaciers are run once with that c_prec, which is neither fitted
nor bounded, and they do not pass it on as the starting value of the next glacier; phases 2 and 3
fit DDF and T_off as usual. This is how a daily snowline calibration is carried into monthly runs.

The other glaciers are calibrated as without the option, with two exceptions:
- With gridded T-offsets (`t_offgrid = y` in the regional table, `repeat_calibration = 'y'`), the
  second round starts every glacier from the mean first-round T_off of its grid cell, listed
  glaciers included, so a listed glacier can shift its neighbours. Run with
  `repeat_calibration = 'n'` for a strict comparison.
- In forward runs, glaciers with flag 0 take the mean DDF and c_prec of the flag-1 glaciers,
  listed ones included (`read_calibration_params.pro`).

The phase-1 statistics count a listed glacier as "at the lower bound" when its c_prec lies at or
below `c1_tolerance[0]`; that is only a label.
