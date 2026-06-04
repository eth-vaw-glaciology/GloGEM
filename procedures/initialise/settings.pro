; *************************************************************
; settings
;
; Define all default model parameters and configuration variables
; for a GloGEM run.
;
; Organised into two zones: Zone 1 sets raw scalar defaults (time
; resolution, GCM lists, calibration tolerances, mass-balance
; parameters, output options) without any conditional logic; Zone 2,
; which executes after the user's config.pro overrides have been
; applied, derives dependent settings such as day-of-month arrays,
; extended GCM lists for 2300 runs, and enforced consistency
; constraints that prevent erroneous model configurations.
; *************************************************************

compile_opt idl2

; --- RGI version
RGIversion = '6'

; --- time resolution
time_resolution = 'daily' ; 'daily' or 'monthly'

; --- input directories (constructed from system username automatically)
; dir_data / dir_data_alt depend on RGIversion and are therefore set in Zone 2
username = getenv('USER')
main_dir = '/itet-stor/' + username + '/glogem/'
dir = main_dir + 'data/'
dir_clim = main_dir + 'climatedata/'

; output directory — set in config.pro
dirres = ''

; --- region selection
region_id_loop = [14, 14] ; IDs from region_batch.dat

; --- size selection
size_range_overwrite = 'n'
size_range = [0.002, 100000] ; [km2]

; --- glacier / catchment selection
single_glacier = '' ; RGI ID (e.g. 01450 = Aletschgletscher); '' to disable
catchment_selection = '' ; catchment name; '' for single glacier or full region

; === main settings / modes

tran = [1940, 2100]
find_startyear = 'y' ; auto-detect first future year from inventory date
calibrate = 'n' ; 'y' to calibrate, 'n' to run with given parameters
meltmodel = '1' ; 1: degree-day model, 3: simple energy-balance (Oerlemans)

; === climate data

; --- GCM / MIP specifications
; Set MIP to choose the model intercomparison project (lookup table in config.pro).
; Use the *_idx variables to select a subset by 1-based index: [0] runs the full
; batch, [1,2] selects the first two, and indgen(n)+k selects n consecutive entries
; starting at index k (e.g. indgen(5)+1 for models 1-5).
MIP = 'CMIP6' ; 'CMIP6', 'CMIP5', or 'GMIP4' — see lookup table in config.pro
long_GCM = '' ; '' for runs to 2100, 'long_' for runs to 2300
GCM_model_idx = [0] ; model indices (1-based) — [0]: all; [1,2]: first two
GCM_rcp_idx = [0] ; SSP/RCP indices         — [0]: all
GCM_model_range = [0, 0] ; [first, last] range shorthand — [0,0]: not used
GCM_rcp_range = [0, 0] ; [first, last] range shorthand — [0,0]: not used
first_GCM = 0 ; first GCM in batch (0-based, minus 1)

; --- reanalysis
; default is 'era5' (daily model); 'ERA5' (all caps) is auto-selected for monthly in Zone 2
; other daily options: 'era5land', 'chelsaw5e5', 'ch2018', 'gswp3w5e5'
reanalysis = 'era5'
rea_eval = [1991, 2020]
grid_step = 0.1
bias_correction = 'y'
bias_correction_method = 1 ; 1: delta method, 2: quantile mapping (daily T only)

; === calibration

valiglaciers_only = 'n'
validation_dataset = 'seasonal/validate_final2017/validate_WGMS_'
calibrate_individual = 'y'
calibrate_glacierspecific = 'y'
calibrate_glacierspecific_period = '2000_2020'
rhodv_iteration = ''

sub_region = ''
calperiod_ID = 9 ; 1: open, 3: open, 4: open, 5: regional Hugonnet2021,
; 8: glacier-specific debris-model, 9: glacier-specific Hugonnet2021

caliphase_loop = 3 ; 1: default (no loop), 2: phases 1-2, 3: phases 1-3
calibration_phase = '1' ; 1: c_prec, 2: DDF_snow, 3: T-bias in ERA data
c1_tolerance = [.8, 2.4]
c2_tolerance = [1.75, 4.5]
c2m3_tolerance = [7., 15.]
t_offset = 0.

repeat_calibration = 'y'

; --- other options
read_parameters = 'y'
submonth_variability = 'y'
reanalysis_direct = 'n'
variability_bias = 'y'
hindcast_dynamic = 'n'
write_file = 'y'
write_netcdf = 'n' ; 'y' to write GlacierMIP4-compliant NetCDF output
netcdf_split = 'n' ; 'y' to also split projection runs into past/future NetCDF files
netcdf_split_year = 2025 ; first year of the projection period (split boundary)

; === parameters

; --- accumulation model
dPdz = 1.5 ; [% per 100 m] precipitation gradient (regionally specified in file)
c_prec = 1.5 ; [-] correction factor (regionally specified in file)
snow_multiplier = 1.2 ; [-] higher correction for snowfall
T_thres = 1.5 ; [deg C] temperature threshold solid-liquid (transition +-1 deg)
no_incprec = [0.75, 1000, 2, 2] ; precipitation reduction at very high elevation:
; 1: fraction of elevation range, 2: crit elevation range [m], 3/4: parameters ax^b

; --- melt model

; meltmodel 1 — degree-day
DDFsnow0 = 3 ; [mm d-1 C-1] degree-day factor snow (regionally specified in file)
DDFice0 = 6 ; [mm d-1 C-1] degree-day factor ice  (regionally specified in file)
T_melt = 0 ; [deg C] critical temperature for melting

; meltmodel 3 — simple energy balance (Oerlemans, 2001)
C0 = -45 ; parameter 1 (regionally specified in file)
C1 = 10 ; parameter 2 (regionally specified in file)

alb_ice = 0.3
alb_firn = 0.5
alb_snow = 0.7

; --- supraglacial debris model
debris_supraglacial = 'n'
debris_pond_enhancementfactor = 2 ; enhancement of bare-ice melt over pond/ice cliff fraction
debris_expansion = 'y'
debris_exp_gradient = 2.0 ; [% a-1 frac-1] gradient of debris extension
debris_seed_bands = 10 ; factor to scale decadal ELA-change into bands with new debris seed
debris_initialband = 0.01 ; [m] debris thickness in newly formed bands with no observations
debris_pond_gradient = 0.1 ; [% a-1 frac-1] gradient of pond/cliff extension
debris_ponddens_max = 0.1 ; [-] maximum pond density within band
debris_thickening = 'y'
debris_thick_gradient = 1.0 ; [cm a-1 km-1] thickening from ELA towards terminus

; --- refreezing
refreezing_full = 'n'
refreezing_parametrised = 'y'

; --- englacial temperature model
firnice_temperature = 'n'
firnice_write = ['y', 'y'] ; [overall time series, detailed profiles]
firnice_batch = 'y'
firnice_profile = [0.2, 0.65, 0.95] ; elevation ratios (or masl if >1) for profile output
enable_advection = 'n'
advection_write = 'n'
firn_permeability = 'y'
ice_permeability = 'n'

; --- glacier retreat module
glacier_retreat = 'y'
expon = 2. ; valley shape parameter: band area loss vs. thickness loss
dh_size = [5, 20] ; [km2] boundaries between dh-parameterisations (Huss et al., 2010)
redistribute_vplus = 'y'
advance = 'y'
adv_addband0 = 10
adv_calving = -100. ; [m] terminal bed elevation (0 = no calving)
adv_fcrit = 2. ; [m/a] elevation gains above this are redistributed
adv_terminusfraction = 0.2
adv_lookup = 'n'

; --- calving (Oerlemans & Nick, 2005; marine-terminating only)
frontal_ablation = 'y'
alpha_f = 0.7
calv_sep = 1.25 ; [m w.e.] threshold: split calving into geometry change vs. direct break-off
c_calving = 2.4
regparams_readfromfile = 'y'
length_corrfact = 1.4 ; length correction factor (Oerlemans)
ccorr_expon = 2.5
crit_ccorrdist = 3000.
bedrock_parabolacorr = 0.2

; === output

clim_subregion = ''
full_output = 'n'

; default output file list (reduced output); full_output='y' variants set in Zone 2
if full_output eq 'n' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
  'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', $
  'Discharge', 'Discharge_gl', '', '', '', '', '']
format_of = ['f10.3', 'f10.4', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'i6', 'f7.1', 'f8.3', 'i6', 'f10.5', 'f8.3', 'f9.4', 'f9.4', 'f9.4', 'f9.4', 'f9.4', 'f10.5']

write_mb_elevationbands = 'n'
eval_mbelevsensitivity = 'n'
count_mbelevsens_v0 = 5

past_out = 'y'

write_hypsometry_files = 'n'

; --- spatial extent
lat0 = [-9999, -9999] ; specify sub-region [degrees]; or use [9999,9999] for full region
lon0 = [0, 0]
lat0 = [9999, 9999] ; run for entire region (perimeter from glacier inventory)
grid_run = 'y'

; --- plot / output interval
plot = 'n'
elev_range_p = 500 ; only plot glaciers above this elevation range [m]
outst = 10 ; [a] results output interval for compilation files
areaplot = 'n'

; --- versioning
version_past = ''
dircali = '' ; set after config.pro is loaded below

; --- secondary settings
mon_len = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] ; initial value; overwritten in Zone 2

min_tempbias = -8 ; restrict extreme temperature biases (default -9999: no restriction)
min_precbias = 0.05 ; restrict extreme precipitation biases

noval = -9999
snoval = -99

rho = 917.
Lh_rf = 334000. * rho ; [J m-3] latent heat of fusion
lhf = 334000. ; [J kg-1] latent heat of fusion

if lat0[0] eq -9999 then grid_run = 'n'
if grid_run eq 'n' then areaplot = 'n'

; declination of sun for mid-month (relevant for melt models 1 and 3)
decl_sun = [-21.26, -13.50, -2.11, 9.85, 19.16, 23.31, 21.18, 13.34, 1.91, -10.03, -19.27, -23.32]
asp_class = [0, 45, 90, 135, 180]

rddf_si = DDFice0 / DDFsnow0

variability_bias_longterm = 'n' ; bias in month-to-month GCM variability (only partially implemented)

; =============================================================================
; === END OF ZONE 1 — raw defaults only above this line
;
; Do NOT add if-statements above this marker that depend on any variable the
; user can set in config.pro (e.g. time_resolution, tran, long_GCM, full_output,
; meltmodel, ...). Such logic runs before config.pro is loaded and will silently
; ignore the user's override. All conditional assignments belong in Zone 2.
; =============================================================================

; --- user-specific overrides
; copy config.pro.example to config.pro and set your values there
; config.pro is git-ignored and will never be accidentally committed
user_config = base_dir + '/config.pro'
if file_test(user_config) then begin
  n = file_lines(user_config)
  lines = strarr(n)
  openr, lun, user_config, /get_lun
  readf, lun, lines
  free_lun, lun
  stmt = ''
  for i = 0, n - 1 do begin
    line = strtrim(lines[i], 2)
    if line eq '' or strmid(line, 0, 1) eq ';' then continue
    if strmid(line, strlen(line) - 1, 1) eq '$' then begin
      stmt += strmid(line, 0, strlen(line) - 1) + ' '
    endif else begin
      stmt += line
      void = execute(stmt)
      stmt = ''
    endelse
  endfor
  print, 'Loaded user config: ' + user_config
endif
if dirres eq '' then message, 'dirres is not set. Copy config.pro.example to config.pro and set dirres there.'
dircali = dirres

; =============================================================================
; === ZONE 2 — derived and enforced settings
;
; Everything below runs after config.pro overrides have been applied.
; Any if-statement that derives one setting from another must live here so
; that config.pro values are correctly respected.
; Never move conditional logic back above the Zone 1 / Zone 2 boundary.
; =============================================================================

; --- MIP full-batch lookup tables (derived from MIP set in Zone 1 / config.pro)
; These arrays define the complete set for the chosen project; index selection in
; the final Zone 2 block below narrows them to the user's GCM_*_idx choices.
case MIP of
  'CMIP6': begin
    GCM_model = ['BCC-CSM2-MR', 'CAMS-CSM1-0', 'CESM2', 'CESM2-WACCM', 'EC-Earth3', $
      'EC-Earth3-Veg', 'FGOALS-f3-L', 'GFDL-ESM4', 'INM-CM4-8', 'INM-CM5-0', $
      'MPI-ESM1-2-HR', 'MRI-ESM2-0', 'NorESM2-MM', 'CanESM5']
    GCM_rcp = ['ssp126', 'ssp245', 'ssp370', 'ssp585', 'ssp119', 'ssp534-over']
    GCM_experiment = 'r1i1p1f1'
    ; rcp_batch: number of leading SSPs (from GCM_rcp) to run for each model in batch.
    ; EC-Earth3 ssp119 lacks r1i1p1f1 → 4. MRI-ESM2-0 ssp534-over has r1i1p1f1 → 6.
    ; CESM2-WACCM has ssp534-over but not ssp119; use GCM_rcp_idx=[1,2,3,4,6] to run it.
    rcp_batch = [4, 5, 4, 4, 4, 5, 4, 5, 4, 4, 4, 6, 4, 4]
    GCM_data = 'cmip6'
    CMIP6 = 'y'
    GMIP4 = 'n'
  end
  'CMIP5': begin
    GCM_model = ['BCC-CSM1-1', 'CanESM2', 'CCSM4', 'CNRM-CM5', 'CSIRO-Mk3-6-0', 'GFDL-CM3', $
      'GISS-E2-R', 'HadGEM2-ES', 'INMCM4', 'IPSL-CM5A-LR', 'MIROC-ESM', $
      'MPI-ESM-LR', 'MRI-CGCM3', 'NorESM1-M']
    GCM_rcp = ['rcp26', 'rcp45', 'rcp85']
    GCM_experiment = 'r1i1p1'
    rcp_batch = intarr(14) + 2 ; rcp45 as default batch scenario
    GCM_data = 'cmip5'
    CMIP6 = 'n'
    GMIP4 = 'n'
  end
  'GMIP4': begin
    ; Glacier Model Intercomparison Project 4 — fixed model/scenario specifications.
    ; Not all model/SSP combinations are available (see GMIP4 protocol).
    ; ssp370 is used as the primary batch scenario.
    GCM_model = ['BCC-CSM2-MR'] ; , 'ACCESS-ESM1-5', 'CESM2-WACCM', 'IPSL-CM6A-LR', 'MRI-ESM2-0', 'MPI-ESM1-2-HR', 'MIROC6', 'NorESM2-MM']
    GCM_rcp = ['ssp126'] ; , 'ssp370', 'ssp585', 'ssp534-over']
    GCM_experiment = 'r1i1p1f1'
    rcp_batch = intarr(8) + 1 ; ssp370 as default batch scenario
    GCM_data = 'gmip4'
    CMIP6 = 'n'
    GMIP4 = 'y'
  end
  else: message, 'Unknown MIP: "' + MIP + '". Valid options: CMIP6, CMIP5, GMIP4'
endcase

; input data directories (depend on RGIversion, which config.pro may override)
dir_data = main_dir + '/geometricdata/' + 'rgiv' + RGIversion + '/bands/'
dir_data_alt = main_dir + '/geometricdata/' + 'rgiv' + RGIversion + '/bands_HF/'

; run length
years = tran[1] - tran[0] + 1

; days of month (depends on time_resolution)
if time_resolution eq 'monthly' then mon_len = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] $
else mon_len = dblarr(365) + 1

; GCM list for 2300 runs
if long_GCM ne '' then begin
  GCM_model = ['ACCESS-CM2', 'ACCESS-ESM1-5', 'CESM2-WACCM', 'CanESM5', 'GISS-E2-1-G', 'GISS-E2-1-H', 'GISS-E2-2-G', 'IPSL-CM6A-LR', 'MIROC-ES2L', 'MRI-ESM2-0', 'UKESM1-0-LL']
  rcp_batch = [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]
endif

; output file list for full_output='y' (depends on both time_resolution and full_output)
if time_resolution eq 'monthly' then $
  if full_output eq 'y' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
    'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', 'Discharge', 'Discharge_gl' $
    , 'Balance_mon', 'Precipitation_mon', 'Accumulation_mon', 'Melt_mon', 'Refreezing_mon'] $
  else if full_output eq 'y' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
    'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', 'Discharge', 'Discharge_gl' $
    , 'Accumulation_day', 'Rain_day', 'Snowmelt_day', 'Icemelt_day', 'Refreezing_day', 'Snowline_day']

; --- consistency enforcement (automatic exclusion to avoid erroneous runs)

if calibrate eq 'y' then begin
  reanalysis_direct = 'y'
  read_parameters = 'n'
  write_mb_elevationbands = 'n'
  rcp_batch[0] = 0
  first_GCM = 0
  find_startyear = 'n'
  debris_expansion = 'n'
  debris_thickening = 'n'
  firnice_temperature = 'n'
  if calibrate_glacierspecific eq 'y' and calperiod_ID ne 8 then calperiod_ID = 9
  GCM_model_idx = [1]
  GCM_rcp_idx = [1]
endif

if calibrate eq 'n' and tran[1] lt 2021 then begin
  reanalysis_direct = 'y'
  GCM_model_idx = [1]
  GCM_rcp_idx = [1]
  glacier_retreat = 'n'
  if hindcast_dynamic eq 'n' then find_startyear = 'n'
endif

if calibrate eq 'n' then begin
  calibrate_individual = 'n'
  caliphase_loop = 1
  calibration_phase = '1'
endif

if glacier_retreat eq 'n' and hindcast_dynamic ne 'y' then advance = 'n'

if read_parameters eq 'y' then calibrate = 'n'

if single_glacier ne '' then grid_run = 'n'

if tran[1] gt 2020 then hindcast_dynamic = 'n'

if meltmodel eq '3' then c2_tolerance = c2m3_tolerance

if debris_supraglacial eq 'n' then eval_mbelevsensitivity = 'n'

if firnice_temperature eq 'n' then firnice_batch = 'n'

; reduced output for 2300 runs (Discharge not available)
if long_GCM ne '' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
  'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', $
  '', '', '', '', '', '', '']

; NetCDF output safety net: write_netcdf_glacier.pro uses the sub-annual arrays
; (accmo, melmo, refrmo, discharge_gl for monthly; accday, snowmeltday, icemeltday,
; refrday for daily). These are only initialised and filled when outf_names[14] ne ''.
; If a user has cleared outf_names[14] (e.g. via a custom outf_names override or the
; long_GCM reduction above), re-enable it so the NetCDF writer does not crash.
if write_netcdf eq 'y' and outf_names[14] eq '' then outf_names[14] = 'Discharge_gl'

; **********************************
; -----------------------------------
; initialize refreezing model
rf_layers = 8 ; number of layers in refreezing model
rf_melcrit = 0.02 ; critical amount of melt for initialising refreezing module (0.002 earlier, what is better?) [m.w.e.]
dens_rf = [300, 300, 400, 450, 500, 550, 600, 650] ; approx. density of layers
rf_dz = 1. ; layer thickness (m)
rf_dsc = 3. ; increase in temporal resolution (num. stability of heat conduction)
if time_resolution eq 'daily' then begin
  rf_dt = 3600. * 24. / rf_dsc ; compute time step
endif else begin
  rf_dt = 3600. * 24. * 30. / rf_dsc ; compute time step
end

; === ice temperature model initialisation
fit_layers = [10, 10, 10]
fit_dzstep = [1., 5., 20.]
fit_dens = [250, 300, 360, 420, 480, 550, 580, 610, 640, 670, 700, 730, 760, 790, 820, 850, 880, 900]

; --- physical constants
cice = 1890000. ; [J m-3 K-1] heat capacity of ice
cair = 1297. ; [J m-3 K-1] heat capacity of air
kice = 2.33 ; [J s-1 K-1 m-1] conductivity of ice
kair = 0.001 ; [J s-1 K-1 m-1] conductivity of air

cap = (1 - dens_rf / 1000.) * cair + dens_rf / 1000. * cice
cond = (1 - dens_rf / 1000.) * kair + dens_rf / 1000. * kice

min_f = 0.0001
max_f = 0.5

fit_dz = dblarr(2, total(fit_layers))

for i = 0, fit_layers[0] - 1 do begin
  fit_dz[0, i] = fit_dzstep[0]
endfor

for i = fit_layers[0], total(fit_layers[0 : 1]) - 1 do begin
  fit_dz[0, i] = fit_dzstep[1]
endfor

for i = total(fit_layers[0 : 1]), total(fit_layers[0 : 2]) - 1 do begin
  fit_dz[0, i] = fit_dzstep[2]
endfor

for i = 1, total(fit_layers) - 1 do begin
  fit_dz[1, i] = fit_dz[1, i - 1] + fit_dz[0, i]
endfor

; Expand range shorthand into index arrays ([0,0] means not used; range takes precedence)
if GCM_model_range[0] ne 0 then $
  GCM_model_idx = indgen(GCM_model_range[1] - GCM_model_range[0] + 1) + GCM_model_range[0]
if GCM_rcp_range[0] ne 0 then $
  GCM_rcp_idx = indgen(GCM_rcp_range[1] - GCM_rcp_range[0] + 1) + GCM_rcp_range[0]

; --- Apply GCM selection indices (1-based; [0] leaves the full-batch array unchanged)
if GCM_model_idx[0] ne 0 then begin
  GCM_model = GCM_model[GCM_model_idx - 1]
  rcp_batch = rcp_batch[GCM_model_idx - 1]
  first_GCM = 0
endif
if GCM_rcp_idx[0] ne 0 then $
  GCM_rcp = GCM_rcp[GCM_rcp_idx - 1]
