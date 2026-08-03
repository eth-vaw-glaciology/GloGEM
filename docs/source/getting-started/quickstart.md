# Quickstart — test run

**Test run on Aletsch & Morteratsch**

This guide runs GloGEM on two well-measured Swiss Alpine glaciers using a
minimal dataset that is **bundled with the repository**. No access to
external data shares is required.

| Glacier | RGI ID | Area |
|---------|--------|------|
| Aletschgletscher | RGI70-11.02596 | 82 km² |
| Morteratschgletscher | RGI70-11.02216 | 16 km² |

Glacier geometry and ice thickness are based on **RGI7.0** (`RGIversion = '7'`)
with the Maffezzoli et al. (2025) ice thickness product — global thickness
from RGI 7.0 outlines ([doi:10.5194/gmd-18-2545-2025](https://doi.org/10.5194/gmd-18-2545-2025)).

The test covers:
- daily model calibration and hindcast (1991–2020)
- monthly model calibration and hindcast (1991–2020)
- daily and monthly GCM projection to 2100 (GlacierMIP4, MRI-ESM2-0, ssp126)

Calibration finds the glacier-specific parameters; the hindcast then runs
the full period with those parameters to produce time series that can be
compared against observations. The projection runs exercise the model's
GCM-driven forward-simulation path, including glacier retreat, using a
single bundled GCM/scenario combination.

Expected total runtime: **~90 seconds** on a modern workstation.

---

## Prerequisites

- IDL 9.0 or later
- The GloGEM repository cloned and the working directory set to its root:

```bash
git clone https://github.com/eth-vaw-glaciology/GloGEM.git
cd GloGEM
```

---

## Step 1 — Daily calibration

Copy the test config to the repository root, then start IDL and run the model:

```bash
cp test/configs/config_aletsch_daily_calib.pro config.pro
idl
```

```idl
.r glogem
```

The model adjusts three parameters per glacier — precipitation correction
factor (`c_prec`), degree-day factor for snow (`DDFsnow`), and for ice
(`DDFice`) — against the 2000–2020 geodetic mass balance from
Hugonnet et al. (2021).

**Expected output** (~58 s):

```
We are running GloGEM daily
Calibration started ...
Catchment selection: Aletsch_Morteratsch
...
FINISHED region !!! centraleurope !!!
```

Calibration results are written to:

```
test/outputs/daily/CentralEurope/calibration/
  calibrate_m1_cID9_centraleurope_final_era5_Aletsch_Morteratsch.dat
```

Typical calibrated values:

| Glacier | Ba (m w.e. a⁻¹) | ELA (m) | AAR (%) | DDFsnow | DDFice | c_prec |
|---------|-----------------|---------|---------|---------|--------|--------|
| Aletsch | −1.17 | 3100 | 54 | 3.6 | 7.2 | 0.80 |
| Morteratsch | −0.97 | 3060 | 48 | 3.0 | 6.0 | 1.34 |

---

```{note}
After each step, exit IDL (`exit`), copy the next config in your terminal,
and relaunch IDL with `.r glogem`.
Restarting avoids stale variables from the previous run carrying over.
```

## Step 2 — Daily hindcast

Using the calibrated parameters from Step 1, run the full 1991–2020 time series.
In your terminal:

```bash
cp test/configs/config_aletsch_daily_hindcast.pro config.pro
```

Then in IDL:

```idl
.r glogem
```

**Expected output** (~6 s):

```
We are running GloGEM daily
Running for the future ...
FINISHED region !!! centraleurope !!!
```

Annual time-series files are written to:

```
test/outputs/daily/CentralEurope/PAST/PAST_original/
  centraleurope_Annual_Balance_sfc_r1_Aletsch_Morteratsch.dat
  centraleurope_ELA_r1_Aletsch_Morteratsch.dat
  centraleurope_AAR_r1_Aletsch_Morteratsch.dat
  centraleurope_Area_r1_Aletsch_Morteratsch.dat
  centraleurope_Volume_r1_Aletsch_Morteratsch.dat
  ... (one file per output variable)
```

---

## Step 3 — Monthly calibration

In your terminal:

```bash
cp test/configs/config_aletsch_monthly_calib.pro config.pro
```

Then in IDL:

```idl
.r glogem
```

The monthly model reads gridded ERA5 climate fields and applies a
sub-monthly variability correction. Calibration is otherwise identical
to the daily model.

**Expected output** (~5 s):

```
We are running GloGEM monthly
Calibration started ...
FINISHED region !!! centraleurope !!!
```

Typical calibrated values:

| Glacier | Ba (m w.e. a⁻¹) | ELA (m) | DDFsnow | DDFice | c_prec |
|---------|-----------------|---------|---------|--------|--------|
| Aletsch | −1.17 | 3143 | 3.7 | 7.4 | 0.80 |
| Morteratsch | −0.98 | 3116 | 3.0 | 6.0 | 1.36 |

---

## Step 4 — Monthly hindcast

In your terminal:

```bash
cp test/configs/config_aletsch_monthly_hindcast.pro config.pro
```

Then in IDL:

```idl
.r glogem
```

**Expected output** (~1 s):

```
We are running GloGEM monthly
Running for the future ...
FINISHED region !!! centraleurope !!!
```

---

## Step 5 — Daily projection

Using the calibrated parameters from Step 1, run a GCM-driven projection
to 2100. In your terminal:

```bash
cp test/configs/config_aletsch_daily_projection.pro config.pro
```

Then in IDL:

```idl
.r glogem
```

This uses a single bundled GlacierMIP4 model/scenario combination
(**MRI-ESM2-0 / ssp126**) and enables `glacier_retreat = 'y'`, so glacier
area and volume evolve dynamically over the 21st century — the main
functionality the calibration and hindcast steps don't exercise.

**Expected output** (~20 s):

```
We are running GloGEM daily
Running for the future ...
Catchment selection: Aletsch_Morteratsch
MIP scenario selected: GMIP4
...
FINISHED region !!! centraleurope !!!
    calculated with GCM: MRI-ESM2-0 / ssp126
```

Annual time-series files are written to:

```
test/outputs/daily/CentralEurope/files/files_original/MRI-ESM2-0/ssp126/
  centraleurope_Annual_Balance_sfc_r1_Aletsch_Morteratsch.dat
  centraleurope_Area_r1_Aletsch_Morteratsch.dat
  centraleurope_Volume_r1_Aletsch_Morteratsch.dat
  ... (one file per output variable)
  hypsometry.zip   ; per-decade area/volume per elevation band (write_hypsometry_files='y')
```

Typical projected area change (1991 → 2099):

| Glacier | Area 1991 (km²) | Area 2099 (km²) | Loss |
|---------|------------------|------------------|------|
| Aletsch | 81.8 | 42.4 | 48% |
| Morteratsch | 15.8 | 6.6 | 58% |

---

## Step 6 — Monthly projection

In your terminal:

```bash
cp test/configs/config_aletsch_monthly_projection.pro config.pro
```

Then in IDL:

```idl
.r glogem
```

Same GCM/scenario and settings as Step 5, at monthly resolution.

**Expected output** (~2 s):

```
We are running GloGEM monthly
Running for the future ...
MIP scenario selected: GMIP4
FINISHED region !!! centraleurope !!!
    calculated with GCM: MRI-ESM2-0 / ssp126
```

```{note}
The bundled projection test data covers only MRI-ESM2-0 / ssp126 for the
CentralEurope grid cells nearest Aletsch and Morteratsch. Changing
`GCM_model_idx` or `GCM_rcp_idx` in these configs will fail with a file-not-found
error unless you also provide the corresponding climate data under
`test/climatedata/future/`. For other models/scenarios, point `dir_clim` at a
full climate data share instead — see [GCM configuration](../running-glogem/gcm-configuration.md).
```

---

## Visualising results

After completing all six runs, open the visualisation notebook in Jupyter
(or VS Code / any Jupyter-compatible editor). It only needs `numpy` and
`matplotlib` — no IDL required:

```bash
cd test
jupyter notebook visualise_test_results.ipynb
```

The notebook auto-detects the test directory from the current working
directory — run it from `test/` (or open it there in your editor).
It reads the outputs from `test/outputs/` and produces six plots:

**Plot 1 — Annual mass balance (1991–2020)**

![Annual mass balance time series for Aletsch and Morteratsch](../images/quickstart/plot1_annual_mb.png)

**Plot 2 — Equilibrium line altitude and accumulation area ratio (daily)**

![ELA and AAR for Aletschgletscher](../images/quickstart/plot2_ela_aar.png)

**Plot 3 — Daily vs monthly model comparison**

![Daily vs monthly mass balance for both glaciers](../images/quickstart/plot3_daily_vs_monthly.png)

**Plot 4 — Calibrated parameters**

![Bar chart of DDFsnow, DDFice and c_prec for both glaciers and both time resolutions](../images/quickstart/plot4_calibrated_params.png)

**Plot 5 — Projected glacier area and volume to 2100**

2x2 mosaic: Aletsch (left) / Morteratsch (right) x Area (top) / Volume (bottom), daily and monthly overlaid.

![Projected glacier area and volume 1991-2100 for both glaciers and both time resolutions](../images/quickstart/plot5_projected_area_volume.png)

**Plot 6 — Glacier elevation profile**

Bedrock and glacier surface elevation from the terminus to the highest elevation
band, for the daily model. Shows the ~2003 inventory extent, a faint line every
10 years, and a highlighted final line, illustrating how far the terminus
retreats up-valley over the century.

![Bedrock and glacier surface elevation profile through time for Aletsch and Morteratsch](../images/quickstart/plot6_glacier_profile.png)

It also runs 13 automated sanity checks. All should pass if the model is
set up correctly.

---

## Expected sanity check results

```
PASS  Aletsch   daily  Ba:  -1.153  [expected -1.50 to -0.80]
PASS  Morteratsch daily  Ba:  -1.038  [expected -1.40 to -0.50]
PASS  Aletsch   monthly Ba:  -1.145  [expected -1.50 to -0.80]
PASS  Morteratsch monthly Ba:  -0.976  [expected -1.40 to -0.50]
PASS  Aletsch daily DDFsnow:   4.500  [expected  1.50 to  7.50]
PASS  Aletsch daily DDFice:    9.000  [expected  3.00 to 15.00]
PASS  Aletsch   daily  mean Ba 2000-2020:  -1.146  [expected -1.50 to -0.80]
...
PASS  Aletsch     2100 area loss (%, daily):  48.140  [expected 15 to 90]
PASS  Morteratsch 2100 area loss (%, daily):  58.265  [expected 15 to 90]

13 / 13 checks passed — the model is working correctly!
```

```{note}
Exact values vary slightly between runs and IDL/library versions — the
sanity checks use tolerance ranges rather than exact matches, so small
differences from the numbers above are expected and not a cause for concern.
```

---

## What the test configs change

Each config file follows the same format as `config.pro.example` with only the
test-specific lines uncommented. Compared to default settings, the tests change:

| Setting | Value | Reason |
|---------|-------|--------|
| `dirres` | `base_dir + '/test/outputs/'` | write to repo-local folder |
| `main_dir`, `dir`, `dir_clim` | `base_dir + '/test/...'` | use bundled minimal dataset |
| `RGIversion` | `'7'` | required for bundled band files |
| `catchment_selection` | `'Aletsch_Morteratsch'` | two-glacier subset |
| `tran` | `[1991, 2020]` (calib/hindcast) or `[1991, 2100]` (projection) | matches bundled climate data / full projection horizon |
| `glacier_retreat` | `'n'` (calib/hindcast), `'y'` (projection) | retreat isn't relevant over the short historical window, and is the main thing the projection steps demonstrate |
| `frontal_ablation` | `'n'` | disabled — no calving for these land-terminating glaciers |
| `MIP`, `GCM_model_idx`, `GCM_rcp_idx` | `'GMIP4'`, `[5]`, `[1]` (projection only) | selects the single bundled GCM/scenario combination (MRI-ESM2-0 / ssp126) |
| `write_hypsometry_files` | `'y'` (daily projection only) | per-decade area/volume per elevation band, used for the notebook's profile plot |

All paths use `base_dir` (set automatically by `glogem.pro` from the
current working directory), so the configs work regardless of where the
repository is cloned.

---

## Troubleshooting

**"Parameter-File for centraleurope is not available"**
: Run Step 1 (daily calibration) before Step 2 (daily hindcast) or Step 5
  (daily projection), and Step 3 (monthly calibration) before Step 4
  (monthly hindcast) or Step 6 (monthly projection). The hindcast and
  projection steps both read calibration parameters produced by the
  preceding calibration step.

**"Error opening file" for a `clim_<lon>_<lat>.dat` path under `future/`**
: The projection configs (Steps 5–6) only bundle climate data for a single
  GCM/scenario (MRI-ESM2-0 / ssp126) and only for the grid cells nearest
  Aletsch and Morteratsch. Don't change `GCM_model_idx`/`GCM_rcp_idx` in
  these test configs without also adding the matching data under
  `test/climatedata/future/`.

**Model finishes but output files are missing**
: Check the log file in `logs/` for errors. Common causes are incorrect
  `dirres` or missing data files in `test/data/`.

**Sanity check fails for Ba**
: The geodetic calibration target is the 2000–2020 mean from Hugonnet
  et al. (2021). A Ba outside the expected range by more than 0.3 m w.e. a⁻¹
  usually indicates that the calibration run (Step 1 or 3) did not complete
  correctly or that `read_parameters` was set to `'y'` before calibration.
