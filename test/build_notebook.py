#!/usr/bin/env python3
"""
build_notebook.py

Generates test_aletsch.ipynb from the cell definitions below.
Run: python3 build_notebook.py
"""
import json, os

# -----------------------------------------------------------------------
# Notebook cells — each entry is (cell_type, source_lines)
# -----------------------------------------------------------------------

MD = "markdown"
CD = "code"

CELLS = [

# ======================================================================
# 0. Title
# ======================================================================
(MD, """\
# GloGEM test run: Aletsch & Morteratsch
## Daily and monthly calibration walk-through

This notebook walks you through a minimal GloGEM run on two well-known
Swiss glaciers — **Aletschgletscher** (RGI70-11.02596, 82 km²) and
**Morteratschgletscher** (RGI70-11.02216, 16 km²).

You will:
1. Run the **daily** model in calibration mode, then hindcast mode.
2. Run the **monthly** model in calibration mode, then hindcast mode.
3. Visualise and sanity-check the outputs.

### Prerequisites
- IDL 8.6 or later
- The `idl_kernel` for Jupyter
  (`pip install idl_kernel && python -m idl_kernel install`)
- The test dataset bundled in `test/` (already in the repository)
- `idl` in your `PATH` (checked in the setup cell)

### How the notebook runs the model
The model is launched via `SPAWN` so the IDL kernel keeps its variables
between cells.  Each model run writes its output to `test/outputs/` and
all subsequent cells read from there.

### Estimated run time
~3–5 minutes for all four model runs (2 glaciers × 2 resolutions ×
2 modes) on a modern workstation.
"""),

# ======================================================================
# 1. Configuration
# ======================================================================
(MD, """\
## 1. Configuration

Set `GLOGEM_DIR` to the absolute path of your local GloGEM checkout
(the directory that contains `glogem.pro`).
All other paths are derived automatically.
"""),

(CD, """\
; ---- USER: set this to your GloGEM root directory ----
GLOGEM_DIR = '/home/jabeer/projects/hackathon-sion-2026/GloGEM'
; -------------------------------------------------------

TEST_DIR    = GLOGEM_DIR + '/test'
DATA_DIR    = TEST_DIR   + '/data'
CLIM_DIR    = TEST_DIR   + '/climatedata'
GEOM_DIR    = TEST_DIR   + '/geometricdata'
OUT_DIR     = TEST_DIR   + '/outputs'

; Verify key paths exist
ok = 1
files_to_check = [ $
  GLOGEM_DIR + '/glogem.pro', $
  DATA_DIR   + '/region_batch.dat', $
  GEOM_DIR   + '/rgiv7/bands/centraleurope/bands_02596.dat', $
  CLIM_DIR   + '/reanalysis/daily/era5/CentralEurope/clim_8.00_46.50.dat', $
  CLIM_DIR   + '/reanalysis/monthly/era5/CentralEurope/clim_CentralEurope.mdi' $
]
foreach f, files_to_check do begin
  if ~file_test(f) then begin
    print, 'MISSING: ' + f
    ok = 0
  endif
endforeach
if ok then print, 'All paths verified OK.' $
else print, 'ERROR: one or more required files are missing.'
"""),

# ======================================================================
# 2. Daily model — calibration
# ======================================================================
(MD, """\
## 2. Daily model — calibration

The daily model uses ERA5 daily temperature and precipitation grids
(0.25° resolution) downscaled to each elevation band.
Calibration adjusts three parameters per glacier
(`DDFsnow`, `DDFice`, `c_prec`) against geodetic mass balance
(Hugonnet et al., 2021) for 2000–2020.

### Config
- `time_resolution = 'daily'`
- `calibrate = 'y'`
- `tran = [1991, 2020]` (calibration loop uses 2000–2020 subset)
"""),

(CD, """\
; ---- Set up daily calibration run ----
; Config is written to test/ and pointed to via GLOGEM_CONFIG.
; The root config.pro is never read or modified.
SPAWN, 'mkdir -p ' + OUT_DIR

cfg_file = TEST_DIR + '/config_active.pro'
openw, lun, cfg_file, /get_lun
printf, lun, 'compile_opt idl2'
printf, lun, "dirres   = '" + OUT_DIR  + "/'"
printf, lun, "main_dir = '" + TEST_DIR + "/'"
printf, lun, "dir      = '" + DATA_DIR + "/'"
printf, lun, "dir_clim = '" + CLIM_DIR + "/'"
printf, lun, "RGIversion           = '7'"
printf, lun, "time_resolution      = 'daily'"
printf, lun, "region_id_loop       = [14, 14]"
printf, lun, "catchment_selection  = 'Aletsch_Morteratsch'"
printf, lun, "tran                 = [1991, 2020]"
printf, lun, "calibrate            = 'y'"
printf, lun, "refreezing_full      = 'n'"
printf, lun, "refreezing_parametrised = 'y'"
printf, lun, "glacier_retreat      = 'n'"
printf, lun, "frontal_ablation     = 'n'"
free_lun, lun
SETENV, 'GLOGEM_CONFIG=' + cfg_file
print, 'GLOGEM_CONFIG -> ' + cfg_file
"""),

(CD, """\
; ---- Run daily calibration (~1 min) ----
; Variables defined above (GLOGEM_DIR etc.) persist across cells in the IDL extension.
CD, GLOGEM_DIR
.run glogem.pro
"""),

# ======================================================================
# 3. Read daily calibration output
# ======================================================================
(MD, """\
### Calibration results
Read the per-glacier calibration file and display the fitted parameters.
"""),

(CD, """\
; ---- Read daily calibration output ----
cal_file = OUT_DIR + '/daily/CentralEurope/calibration/' + $
           'calibrate_m1_cID9_centraleurope_final_era5_Aletsch_Morteratsch.dat'

if ~file_test(cal_file) then begin
  print, 'Calibration output not found: ' + cal_file
  print, 'Check that the daily calibration run completed without errors.'
  stop
endif

n = file_lines(cal_file) - 1
hdr = strarr(1) & dat = strarr(n)
openr, 1, cal_file & readf, 1, hdr & readf, 1, dat & close, 1
print, hdr[0]
print, ''
for i = 0, n-1 do print, dat[i]

; Parse for further use
cal_id = strarr(n) & cal_ba = dblarr(n) & cal_ela = dblarr(n)
cal_aar = dblarr(n) & cal_ddfs = dblarr(n) & cal_ddfi = dblarr(n)
cal_cprec = dblarr(n) & cal_toff = dblarr(n)
for i = 0, n-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  cal_id[i] = p[0]
  cal_ba[i]    = double(p[1])
  cal_ela[i]   = double(p[4])
  cal_aar[i]   = double(p[5])
  cal_ddfs[i]  = double(p[8])
  cal_ddfi[i]  = double(p[9])
  cal_cprec[i] = double(p[10])
  cal_toff[i]  = double(p[11])
endfor
print, ''
print, 'Summary:'
print, string('Glacier', 'Ba (m w.e./yr)', 'ELA (m)', 'AAR (%)', fo='(a10,3a16)')
for i = 0, n-1 do $
  print, string(cal_id[i], cal_ba[i], cal_ela[i], cal_aar[i], $
                fo='(a10,2f16.3,f16.1)')
"""),

# ======================================================================
# 4. Daily model — hindcast
# ======================================================================
(MD, """\
## 3. Daily model — hindcast

Now run without calibration, using the parameters just estimated,
to generate annual time-series output over the full 1991–2020 period.
"""),

(CD, """\
; ---- Set up daily hindcast ----
cfg_file = TEST_DIR + '/config_active.pro'
openw, lun, cfg_file, /get_lun
printf, lun, 'compile_opt idl2'
printf, lun, "dirres   = '" + OUT_DIR  + "/'"
printf, lun, "main_dir = '" + TEST_DIR + "/'"
printf, lun, "dir      = '" + DATA_DIR + "/'"
printf, lun, "dir_clim = '" + CLIM_DIR + "/'"
printf, lun, "RGIversion           = '7'"
printf, lun, "time_resolution      = 'daily'"
printf, lun, "region_id_loop       = [14, 14]"
printf, lun, "catchment_selection  = 'Aletsch_Morteratsch'"
printf, lun, "tran                 = [1991, 2020]"
printf, lun, "calibrate            = 'n'"
printf, lun, "read_parameters      = 'y'"
printf, lun, "refreezing_full      = 'n'"
printf, lun, "refreezing_parametrised = 'y'"
printf, lun, "glacier_retreat      = 'n'"
printf, lun, "frontal_ablation     = 'n'"
free_lun, lun
SETENV, 'GLOGEM_CONFIG=' + cfg_file
print, 'GLOGEM_CONFIG -> ' + cfg_file
"""),

(CD, """\
; ---- Run daily hindcast (~6 s) ----
CD, GLOGEM_DIR
.run glogem.pro
"""),

# ======================================================================
# 5. Plot daily outputs
# ======================================================================
(MD, """\
### Plot daily hindcast outputs
"""),

(CD, """\
; ---- Read annual mass balance ----
; Note: catchment_selection adds a suffix to all output filenames.
CC = '_Aletsch_Morteratsch'   ; catchment suffix used in filenames
mb_file_daily = OUT_DIR + '/daily/CentralEurope/PAST/PAST_original/centraleurope_Annual_Balance_sfc_r1' + CC + '.dat'
if ~file_test(mb_file_daily) then begin
  print, 'Output not found: ' + mb_file_daily & stop
endif

n_gl_d = file_lines(mb_file_daily) - 1
hdr = strarr(1) & dat = strarr(n_gl_d)
openr, 1, mb_file_daily & readf, 1, hdr & readf, 1, dat & close, 1

parts = strsplit(hdr[0], ' ', /extract)
yrs_d = double(parts[1:*])

gl_ids_d = strarr(n_gl_d) & mb_d = dblarr(n_gl_d, n_elements(yrs_d))
for i = 0, n_gl_d-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  gl_ids_d[i] = p[0]
  mb_d[i, *]  = double(p[1:*])
endfor

; Identify glaciers
idx_al = (where(gl_ids_d eq '02596'))[0]  ; Aletsch
idx_mo = (where(gl_ids_d eq '02216'))[0]  ; Morteratsch

print, 'Daily — mean annual MB 1991-2020:'
print, '  Aletsch:     ' + string(mean(mb_d[idx_al,*]), fo='(f7.3)') + ' m w.e./yr'
print, '  Morteratsch: ' + string(mean(mb_d[idx_mo,*]), fo='(f7.3)') + ' m w.e./yr'
"""),

(CD, """\
; ---- Plot 1: Annual mass balance time series (daily) ----
w1 = WINDOW(DIMENSIONS=[900, 420], $
            TITLE='Daily model — Annual mass balance (1991-2020)')
p_al = PLOT(yrs_d, mb_d[idx_al,*], 'b-2', $
            TITLE='Annual specific mass balance', $
            XTITLE='Year', YTITLE='Mass balance (m w.e.)', $
            NAME='Aletsch (daily)', YRANGE=[-5, 3], $
            LAYOUT=[1,1,1], /CURRENT)
p_mo = PLOT(yrs_d, mb_d[idx_mo,*], 'r--2', $
            NAME='Morteratsch (daily)', /OVERPLOT)
ref_al = PLOT([1991, 2020], [-1.216, -1.216], 'b:', THICK=1.5, $
              NAME='Aletsch geodetic mean', /OVERPLOT)
ref_mo = PLOT([1991, 2020], [-1.022, -1.022], 'r:', THICK=1.5, $
              NAME='Morteratsch geodetic mean', /OVERPLOT)
leg1 = LEGEND(TARGET=[p_al, p_mo, ref_al, ref_mo], $
              POSITION=[0.88, 0.92], /NORMAL)
"""),

(CD, """\
; ---- Read ELA and AAR ----
ela_file_d = OUT_DIR + '/daily/CentralEurope/PAST/PAST_original/centraleurope_ELA_r1' + CC + '.dat'
aar_file_d = OUT_DIR + '/daily/CentralEurope/PAST/PAST_original/centraleurope_AAR_r1' + CC + '.dat'

n_gl_d = file_lines(ela_file_d) - 1
hdr = strarr(1) & dat = strarr(n_gl_d)
openr, 1, ela_file_d & readf, 1, hdr & readf, 1, dat & close, 1
ela_d = dblarr(n_gl_d, n_elements(yrs_d))
for i = 0, n_gl_d-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  ela_d[i, *] = double(p[1:*])
endfor

hdr = strarr(1) & dat = strarr(n_gl_d)
openr, 1, aar_file_d & readf, 1, hdr & readf, 1, dat & close, 1
aar_d = dblarr(n_gl_d, n_elements(yrs_d))
for i = 0, n_gl_d-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  aar_d[i, *] = double(p[1:*])
endfor

print, 'Daily — mean ELA 1991-2020:'
print, '  Aletsch:     ' + string(mean(ela_d[idx_al,*]), fo='(f7.0)') + ' m'
print, '  Morteratsch: ' + string(mean(ela_d[idx_mo,*]), fo='(f7.0)') + ' m'

w2 = WINDOW(DIMENSIONS=[900, 420], TITLE='Daily model — ELA and AAR')
p_ela = PLOT(yrs_d, ela_d[idx_al,*], 'b-2', $
             TITLE='Aletsch — equilibrium line altitude', $
             XTITLE='Year', YTITLE='ELA (m a.s.l.)', $
             LAYOUT=[2,1,1], /CURRENT)
p_aar = PLOT(yrs_d, aar_d[idx_al,*]*100., 'g-2', $
             TITLE='Aletsch — accumulation area ratio', $
             XTITLE='Year', YTITLE='AAR (%)', $
             LAYOUT=[2,1,2], /CURRENT)
"""),

# ======================================================================
# 6. Monthly model — calibration
# ======================================================================
(MD, """\
## 4. Monthly model — calibration

The monthly model uses gridded ERA5 monthly climate fields stored in
regional `.mdi` binary archives. Sub-monthly temperature variability is
derived from stored within-month anomaly patterns.
"""),

(CD, """\
; ---- Set up monthly calibration ----
cfg_file = TEST_DIR + '/config_active.pro'
openw, lun, cfg_file, /get_lun
printf, lun, 'compile_opt idl2'
printf, lun, "dirres   = '" + OUT_DIR  + "/'"
printf, lun, "main_dir = '" + TEST_DIR + "/'"
printf, lun, "dir      = '" + DATA_DIR + "/'"
printf, lun, "dir_clim = '" + CLIM_DIR + "/'"
printf, lun, "RGIversion           = '7'"
printf, lun, "time_resolution      = 'monthly'"
printf, lun, "region_id_loop       = [14, 14]"
printf, lun, "catchment_selection  = 'Aletsch_Morteratsch'"
printf, lun, "tran                 = [1991, 2020]"
printf, lun, "calibrate            = 'y'"
printf, lun, "refreezing_full      = 'n'"
printf, lun, "refreezing_parametrised = 'y'"
printf, lun, "glacier_retreat      = 'n'"
printf, lun, "frontal_ablation     = 'n'"
free_lun, lun
SETENV, 'GLOGEM_CONFIG=' + cfg_file
print, 'GLOGEM_CONFIG -> ' + cfg_file
"""),

(CD, """\
; ---- Run monthly calibration (~5 s) ----
CD, GLOGEM_DIR
.run glogem.pro
"""),

(CD, """\
; ---- Read monthly calibration output ----
cal_file_m = OUT_DIR + '/monthly/CentralEurope/calibration/' + $
             'calibrate_m1_cID9_centraleurope_final_ERA5_Aletsch_Morteratsch.dat'

if ~file_test(cal_file_m) then begin
  print, 'Monthly calibration output not found: ' + cal_file_m & stop
endif

n = file_lines(cal_file_m) - 1
hdr = strarr(1) & dat = strarr(n)
openr, 1, cal_file_m & readf, 1, hdr & readf, 1, dat & close, 1
print, 'Monthly calibration results:'
print, hdr[0]
for i = 0, n-1 do print, dat[i]

cal_m_id = strarr(n) & cal_m_ba = dblarr(n)
cal_m_ddfs = dblarr(n) & cal_m_ddfi = dblarr(n) & cal_m_cprec = dblarr(n)
for i = 0, n-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  cal_m_id[i]    = p[0]
  cal_m_ba[i]    = double(p[1])
  cal_m_ddfs[i]  = double(p[8])
  cal_m_ddfi[i]  = double(p[9])
  cal_m_cprec[i] = double(p[10])
endfor
"""),

# ======================================================================
# 7. Monthly hindcast
# ======================================================================
(MD, """\
## 5. Monthly model — hindcast
"""),

(CD, """\
; ---- Set up monthly hindcast ----
cfg_file = TEST_DIR + '/config_active.pro'
openw, lun, cfg_file, /get_lun
printf, lun, 'compile_opt idl2'
printf, lun, "dirres   = '" + OUT_DIR  + "/'"
printf, lun, "main_dir = '" + TEST_DIR + "/'"
printf, lun, "dir      = '" + DATA_DIR + "/'"
printf, lun, "dir_clim = '" + CLIM_DIR + "/'"
printf, lun, "RGIversion           = '7'"
printf, lun, "time_resolution      = 'monthly'"
printf, lun, "region_id_loop       = [14, 14]"
printf, lun, "catchment_selection  = 'Aletsch_Morteratsch'"
printf, lun, "tran                 = [1991, 2020]"
printf, lun, "calibrate            = 'n'"
printf, lun, "read_parameters      = 'y'"
printf, lun, "refreezing_full      = 'n'"
printf, lun, "refreezing_parametrised = 'y'"
printf, lun, "glacier_retreat      = 'n'"
printf, lun, "frontal_ablation     = 'n'"
free_lun, lun
SETENV, 'GLOGEM_CONFIG=' + cfg_file
print, 'GLOGEM_CONFIG -> ' + cfg_file
"""),

(CD, """\
; ---- Run monthly hindcast (~1 s) ----
CD, GLOGEM_DIR
.run glogem.pro
"""),

# ======================================================================
# 8. Comparison plots
# ======================================================================
(MD, """\
## 6. Comparison: daily vs monthly

Compare annual mass balance time series from both model resolutions.
"""),

(CD, """\
; ---- Read monthly hindcast output ----
CC = '_Aletsch_Morteratsch'   ; catchment suffix (re-defined in case this cell runs first)
mb_file_monthly = OUT_DIR + '/monthly/CentralEurope/PAST/PAST_original/centraleurope_Annual_Balance_sfc_r1' + CC + '.dat'
if ~file_test(mb_file_monthly) then begin
  print, 'Monthly output not found: ' + mb_file_monthly & stop
endif

n_gl_m = file_lines(mb_file_monthly) - 1
hdr = strarr(1) & dat = strarr(n_gl_m)
openr, 1, mb_file_monthly & readf, 1, hdr & readf, 1, dat & close, 1

parts = strsplit(hdr[0], ' ', /extract)
yrs_m = double(parts[1:*])

gl_ids_m = strarr(n_gl_m) & mb_m = dblarr(n_gl_m, n_elements(yrs_m))
for i = 0, n_gl_m-1 do begin
  p = strsplit(dat[i], ' ', /extract)
  gl_ids_m[i] = p[0]
  mb_m[i, *]  = double(p[1:*])
endfor
idx_al_m = (where(gl_ids_m eq '02596'))[0]
idx_mo_m = (where(gl_ids_m eq '02216'))[0]
"""),

(CD, """\
; ---- Plot: daily vs monthly annual mass balance ----
w3 = WINDOW(DIMENSIONS=[1000, 480], $
            TITLE='Mass balance: daily vs monthly model (1991-2020)')

; Aletsch
p1 = PLOT(yrs_d, mb_d[idx_al,*], 'b-2', $
          TITLE='Aletschgletscher', $
          XTITLE='Year', YTITLE='MB (m w.e.)', $
          NAME='Daily', YRANGE=[-5, 3], $
          LAYOUT=[2,1,1], /CURRENT)
p2 = PLOT(yrs_m, mb_m[idx_al_m,*], 'r--2', $
          NAME='Monthly', /OVERPLOT)
ref = PLOT([1991, 2020], [-1.216, -1.216], 'k:', $
           NAME='Geodetic (2000-2020)', /OVERPLOT)
leg3 = LEGEND(TARGET=[p1, p2, ref], POSITION=[0.45, 0.92], /NORMAL)

; Morteratsch
p3 = PLOT(yrs_d, mb_d[idx_mo,*], 'b-2', $
          TITLE='Morteratschgletscher', $
          XTITLE='Year', YTITLE='MB (m w.e.)', $
          NAME='Daily', YRANGE=[-5, 3], $
          LAYOUT=[2,1,2], /CURRENT)
p4 = PLOT(yrs_m, mb_m[idx_mo_m,*], 'r--2', $
          NAME='Monthly', /OVERPLOT)
ref2 = PLOT([1991, 2020], [-1.022, -1.022], 'k:', $
            NAME='Geodetic (2000-2020)', /OVERPLOT)
leg4 = LEGEND(TARGET=[p3, p4, ref2], POSITION=[0.92, 0.92], /NORMAL)
"""),

(CD, """\
; ---- Plot: calibration parameter comparison (daily vs monthly) ----
; Bar chart of DDFsnow, DDFice, Cprec for each glacier and each resolution
names = ['Aletsch (d)', 'Aletsch (m)', 'Morteratsch (d)', 'Morteratsch (m)']

idx_al_c  = (where(cal_id    eq '02596'))[0]
idx_mo_c  = (where(cal_id    eq '02216'))[0]
idx_al_cm = (where(cal_m_id  eq '02596'))[0]
idx_mo_cm = (where(cal_m_id  eq '02216'))[0]

ddfs  = [cal_ddfs[idx_al_c],  cal_m_ddfs[idx_al_cm], $
         cal_ddfs[idx_mo_c],  cal_m_ddfs[idx_mo_cm]]
ddfi  = [cal_ddfi[idx_al_c],  cal_m_ddfi[idx_al_cm], $
         cal_ddfi[idx_mo_c],  cal_m_ddfi[idx_mo_cm]]
cprec = [cal_cprec[idx_al_c], cal_m_cprec[idx_al_cm], $
         cal_cprec[idx_mo_c], cal_m_cprec[idx_mo_cm]]

x = indgen(4) + 1
w4 = WINDOW(DIMENSIONS=[960, 400], $
            TITLE='Calibrated parameters: daily vs monthly')
b1 = BARPLOT(x, ddfs, FILL_COLOR='SteelBlue', TITLE='DDFsnow (mm/d/°C)', $
             XTICKNAME=names, XTICKV=x, $
             XTICKLEN=0, LAYOUT=[3,1,1], /CURRENT)
b2 = BARPLOT(x, ddfi, FILL_COLOR='OrangeRed', TITLE='DDFice (mm/d/°C)', $
             XTICKNAME=names, XTICKV=x, $
             XTICKLEN=0, LAYOUT=[3,1,2], /CURRENT)
b3 = BARPLOT(x, cprec, FILL_COLOR='SeaGreen', TITLE='c_prec (-)', $
             XTICKNAME=names, XTICKV=x, $
             XTICKLEN=0, LAYOUT=[3,1,3], /CURRENT)
"""),

# ======================================================================
# 9. Sanity checks
# ======================================================================
(MD, """\
## 7. Sanity checks

Verify that key model outputs fall within expected ranges for these glaciers.
"""),

(CD, """\
; ---- Automated sanity checks ----
; Each check prints PASS or FAIL with the value and expected range.

print, ''
print, '====== Sanity checks ======'
n_pass = 0 & n_total = 0

; Each check block repeats the same pattern:

; 1. Calibrated Ba close to geodetic target
chk_labels = ['Aletsch daily Ba',      'Morteratsch daily Ba', $
              'Aletsch monthly Ba',    'Morteratsch monthly Ba']
chk_vals   = [cal_ba[idx_al_c],       cal_ba[idx_mo_c], $
              cal_m_ba[idx_al_cm],    cal_m_ba[idx_mo_cm]]
chk_lo     = [-1.5, -1.4, -1.5, -1.4]
chk_hi     = [-0.8, -0.5, -0.8, -0.5]

for k = 0, n_elements(chk_labels)-1 do begin
  n_total++
  if chk_vals[k] ge chk_lo[k] and chk_vals[k] le chk_hi[k] then begin
    print, '  PASS  ' + chk_labels[k] + ': ' + string(chk_vals[k], fo='(f8.3)')
    n_pass++
  endif else $
    print, '  FAIL  ' + chk_labels[k] + ': ' + string(chk_vals[k], fo='(f8.3)') + $
           '  [expected ' + string(chk_lo[k], fo='(f6.2)') + ' to ' + $
           string(chk_hi[k], fo='(f6.2)') + ']'
endfor

; 2. DDFsnow and DDFice in realistic ranges (mm/d/°C)
ddf_labels = ['Aletsch daily DDFsnow (mm/d/C)', 'Aletsch daily DDFice (mm/d/C)']
ddf_vals   = [cal_ddfs[idx_al_c], cal_ddfi[idx_al_c]]
ddf_lo     = [1.5, 3.0]
ddf_hi     = [7.5, 15.0]
for k = 0, 1 do begin
  n_total++
  if ddf_vals[k] ge ddf_lo[k] and ddf_vals[k] le ddf_hi[k] then begin
    print, '  PASS  ' + ddf_labels[k] + ': ' + string(ddf_vals[k], fo='(f8.3)')
    n_pass++
  endif else $
    print, '  FAIL  ' + ddf_labels[k] + ': ' + string(ddf_vals[k], fo='(f8.3)') + $
           '  [expected ' + string(ddf_lo[k], fo='(f6.2)') + ' to ' + $
           string(ddf_hi[k], fo='(f6.2)') + ']'
endfor

; 3. Hindcast mean MB over 2000-2020 close to geodetic
ii_d = where(yrs_d ge 2000 and yrs_d le 2020)
ii_m = where(yrs_m ge 2000 and yrs_m le 2020)
hind_labels = ['Aletsch daily mean MB 2000-2020', $
               'Morteratsch daily mean MB 2000-2020', $
               'Aletsch monthly mean MB 2000-2020', $
               'Morteratsch monthly mean MB 2000-2020']
hind_vals = [mean(mb_d[idx_al, ii_d]),  mean(mb_d[idx_mo, ii_d]), $
             mean(mb_m[idx_al_m, ii_m]), mean(mb_m[idx_mo_m, ii_m])]
hind_lo   = [-1.5, -1.4, -1.5, -1.4]
hind_hi   = [-0.8, -0.5, -0.8, -0.5]
for k = 0, n_elements(hind_labels)-1 do begin
  n_total++
  if hind_vals[k] ge hind_lo[k] and hind_vals[k] le hind_hi[k] then begin
    print, '  PASS  ' + hind_labels[k] + ': ' + string(hind_vals[k], fo='(f8.3)')
    n_pass++
  endif else $
    print, '  FAIL  ' + hind_labels[k] + ': ' + string(hind_vals[k], fo='(f8.3)') + $
           '  [expected ' + string(hind_lo[k], fo='(f6.2)') + ' to ' + $
           string(hind_hi[k], fo='(f6.2)') + ']'
endfor

; 4. ELA in plausible range for Swiss Alps
n_total++
ela_mean = mean(ela_d[idx_al,*])
if ela_mean ge 2600 and ela_mean le 3300 then begin
  print, '  PASS  Aletsch daily mean ELA 1991-2020: ' + string(ela_mean, fo='(f8.0)') + ' m'
  n_pass++
endif else $
  print, '  FAIL  Aletsch daily mean ELA 1991-2020: ' + string(ela_mean, fo='(f8.0)') + $
         ' m  [expected 2600 to 3300 m]'

print, ''
print, string(n_pass, fo='(i0)') + ' / ' + string(n_total, fo='(i0)') + ' checks passed'
if n_pass eq n_total then $
  print, 'All checks passed — the model is working correctly!' $
else $
  print, 'Some checks failed — inspect the output files for details.'
"""),

# ======================================================================
# 10. Cleanup note
# ======================================================================
(MD, """\
## 8. Next steps

- The calibration parameters written to `test/outputs/*/CentralEurope/calibration/`
  can be inspected or copied to your working calibration directory.
- To run on the full Central Europe region, change `catchment_selection = ''`
  and point `dirres`, `dir`, `dir_clim`, and `dir_data` back to the production
  data paths in `config.pro`.
- To run future projections, set `calibrate = 'n'`, `read_parameters = 'y'`,
  and extend `tran` to include future years (e.g., `tran = [1991, 2100]`).
  This requires GCM climate data under `dir_clim/future/`.
"""),

# ======================================================================
# 11. Cleanup
# ======================================================================
(CD, """\
; ---- Clear GLOGEM_CONFIG and remove the temporary active config ----
SETENV, 'GLOGEM_CONFIG='
tmp = TEST_DIR + '/config_active.pro'
if file_test(tmp) then file_delete, tmp
print, 'GLOGEM_CONFIG cleared. Your root config.pro was not modified.'
"""),

]  # end CELLS


# -----------------------------------------------------------------------
# Build .idlnb  (IDL VS Code extension native format)
#
# Schema (from idl.idl-for-vscode example notebooks):
#   { "version": "2.0.0",
#     "cells": [
#       { "type": "markdown"|"code",
#         "content": ["line1", "line2", ...],   ← array, no \n
#         "metadata": {},
#         "outputs": [] }
#     ] }
# -----------------------------------------------------------------------

def make_cell(cell_type, source):
    """Return one cell in the .idlnb JSON schema."""
    t = "markdown" if cell_type == "markdown" else "code"
    # content is an array of lines, no trailing newlines
    lines = source.splitlines()
    return {
        "type": t,
        "content": lines,
        "metadata": {},
        "outputs": [],
    }


nb = {
    "version": "2.0.0",
    "cells": [make_cell(ct, src) for ct, src in CELLS],
}

out_path = os.path.join(os.path.dirname(__file__), "test_aletsch.idlnb")
with open(out_path, "w") as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)
print(f"Written: {out_path}")
