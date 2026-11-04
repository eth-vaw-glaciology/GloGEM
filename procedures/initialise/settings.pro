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
; always lowercase; time_resolution determines which parameter file is read
; (_daily or _monthly suffix, e.g. regional_parameters_era5_daily.dat)
; other daily options: 'era5land', 'chelsaw5e5', 'ch2018', 'gswp3w5e5'
reanalysis = 'era5'
rea_eval = [1991, 2020]
grid_step = 0.1
bias_correction = 'y'
bias_correction_method = 1 ; 1: delta method, 2: quantile mapping (daily T only)

; --- air temperature at the bands
air_temperature = 'era5_2m' ; 'era5_2m' = the 2 m temperature of the climate cell with the monthly lapse rate;
                            ; 'freeair' = ERA5 pressure-level temperature at each band's height (freeair_file) for
                            ; the mass balance, its calibration and, if on, the thermal model (monthly, gridded
                            ; climate files, the years of the table only)
freeair_file = ''           ; free-air temperature at fixed heights per grid cell and month (NetCDF from
                            ; glogemflow_icetemp scripts/icetemp_analysis/freeair/make_freeair_table.py)
freeair_blend_depth = 400d  ; [m] below the climate cell's ground the band air changes gradually from the free air
                            ; to the 2 m air with the lapse rate, all 2 m air this far below it (freeair_blend.pro)
freeair_mixed_calibration = 'n' ; 'y' = run on a calibration made with the other air (diagnostic); otherwise a
                            ; run stops when its air differs from the calibration's (calibration/air_temperature.txt)

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
netcdf_daily_aggregated_monthly = 'n' ; for daily runs: 'y' to aggregate the NetCDF sub-annual output to monthly (the .dat output stays daily)

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
firnice_implicit = 'y'      ; heat conduction scheme: 'y' = implicit backward Euler (Thomas),
                            ; unconditionally stable. 'n' = explicit, which needs the ×½ factor
                            ; below to stay stable at the current layer thickness and timestep.
firnice_write = ['y', 'y', 'n'] ; [overall time series, detailed profiles, full T(band,layer) field]
firnice_batch = 'n'
firnice_profile = [0.2, 0.65, 0.95] ; elevation ratios (or masl if >1) for profile output
firnice_glenglat_lookup = ''  ; path to per-glacier borehole elevation lookup; '' = disabled
firnice_thermal_spinup = 'n'          ; 'y' = run 1D thermal spinup before main loop
firnice_spinup_ref_period = [1961, 1990] ; climate reference period for equilibrium spinup
firnice_spinup_max_cycles = 500       ; max equilibrium cycles (convergence usually <200)
firnice_spinup_tol = 0.05d            ; °C convergence tolerance (max change in deep layers)
firnice_spinup_min_cycles = 200       ; minimum equilibrium cycles before convergence is checked
firnice_spinup_dT = 0d               ; K added to the thermal model's air temperature in the spin-up's reference
                                     ; forcing (diagnostic: a colder climate before the reference period); the
                                     ; mass balance, firn mask and burial keep the reference climate
firnice_spinup_solver = 'drift'       ; 'drift' = measure the drift and jump to equilibrium
                                      ; (spinup_firnicetemp_thermal.pro); 'cycle' = repeat the
                                      ; reference year until the deep layers stop changing
mb_book = 1b                          ; 0b only inside the thermal spin-up's reference forcing:
                                      ; the mass-balance files then skip the climate cursor and annual totals
fit_lacc_on = 0b                      ; set only by the drift spin-up: firnice_temperature_model
                                      ; then sums its conduction coefficients per band and layer
enable_advection = 'n'
enable_strain_heating   = 'n'   ; 'y' to add viscous dissipation heat source (SIA)
advection_write = 'n'
firn_permeability = 'y'
firnice_melt_surface = 'n'  ; 'y' = clamp the surface to the melting point in any month with
                            ; melt, instead of applying air temperature + insulation offset
firnice_perm_frac       = 1.0d  ; 0-1: scales effective percolation depth (1 = full H-L depth)
firnice_z0_firn         = 15.0d ; C&P e-folding depth [m]; Z0=κ/w_acc — 15m≈alpine, 60-100m≈polar
firnice_adv_scale       = 1.0d  ; advection velocity scaling factor (Tier-3 calib param); 1.0 = unscaled baseline
firnice_refreeze_frac   = 1.0d  ; 0-1: fraction of surface meltwater+rain that percolates and
                                ; refreezes rather than running off. Sets the latent heat entering
                                ; the temperature profile. ENERGY ONLY -- the mass balance keeps
                                ; taking its refreezing from refreezing_parametrised/_full, so
                                ; this does not change runoff or require MB recalibration.
firnice_insul_scale     = 1.0d  ; snow/firn insulation: multiplies the Calonne (2011) snow/firn
                                ; conductivity. Higher = snow conducts more, insulates LESS.
                                ; Ice is on a separate law and is not scaled, so this changes the
                                ; snow-to-ice contrast rather than the overall conduction rate.
                                ; 1.0 = Calonne as published; the other standard relations sit at
                                ; Sturm 1997 0.59 and Yen 1981 1.09, giving a defensible range.
firnice_forcing_toff    = 'y'   ; 'n' = the thermal model's energy inputs (surface temperature, the
                                ; melt and rain that refreeze, Herron-Langway temperature, initial
                                ; profile, spin-up forcing) without the mass-balance t_offset; its
                                ; mass inputs (snow, firn mask, accumulation) keep it
firnice_hl1980          = 'n'   ; 'y' = firn-ice transition depth from the closed form of Herron &
                                ; Langway (1980), stage 1 independent of the accumulation rate
firnice_lh_water        = 'n'   ; 'y' = latent heat per m of percolating water (1000 kg/m3)
firnice_perm_limit      = 'hl'  ; 'profile' = water stops where the thermal model's density
                                ; profile reaches 830 kg/m3 (diagnostic); 'hl' = Herron-Langway depth;
                                ; 'cold' = water passes firn at the melting point, but reaches at most
                                ; firnice_perm_cold_depth into cold firn; the rest runs off
firnice_perm_cold_depth = 4.d   ; m, meltwater penetration into cold firn (Mattea et al. 2021, z_lim;
                                ; Gilbert et al. 2014, 4-5 m at Col du Dome in 2012)
firnice_snow_refreeze   = 'n'   ; 'y' = on ice bands, meltwater and rain (x f_ref) refreeze in the seasonal
                                ; snow and at the ice surface beneath it before running off
firnice_orient          = 'n'   ; 'table' = the thermal model's melt is multiplied per band by an orientation
                                ; factor F (melt of the band's slope over melt of flat ground in the same
                                ; weather), read from firnice_orient_dir as a function of the month's air
                                ; temperature anomaly; the mass balance is unchanged
firnice_orient_dir      = ''    ; folder of orient_<glacier id>.dat, one for every glacier of the run
firnice_write_melth     = 'n'   ; 'y' = write, per band and month of the main run, the thermal model's degree-day
                                ; melt before the orientation factor (firnice_melth_<id>.dat, m w.e.) and its air
                                ; temperature (firnice_tairth_<id>.dat, C): the inputs the orientation tables match
firnice_thermal_lapse   = 'floor' ; lapse rate of the thermal surface above the climate cell:
                                ; 'floor' = at least 6.5 K/km; 'reanalysis' = ERA5's own (as the
                                ; mass balance; better at Jungfraujoch and Corvatsch 1981-2020);
                                ; 'stations' = firnice_lapse_stations, also for the refreezing melt
                                ; when firnice_forcing_toff = 'n'
; monthly lapse rate between the ERA5 grid point and Jungfraujoch / Corvatsch (mean of the two,
; MeteoSwiss monthly means 1981-2020), K/m, January to December: winter inversions above the grid
firnice_lapse_stations  = [-0.000833d, -0.002520d, -0.004709d, -0.005872d, -0.005987d, -0.006658d, $
                           -0.006854d, -0.006397d, -0.005681d, -0.004061d, -0.002689d, -0.001051d]
firnice_lapse_stations_dz = 1170.d ; m above the climate cell up to which the station rates hold (the two
                                ; stations' mean height above their grid points); above it ERA5's own rate
firnice_thermal_air     = 'era5_2m' ; air of the thermal model: 'era5_2m' = the 2 m temperature of the climate
                                ; cell with the lapse rate above; 'freeair' = ERA5 pressure-level temperature at
                                ; each band's height (firnice_freeair_file) for the surface, the melt and rain
                                ; that refreeze, Herron-Langway and the spin-up; the mass balance keeps
                                ; air_temperature (set to 'freeair' when air_temperature = 'freeair')
firnice_freeair_file    = ''    ; the table of firnice_thermal_air = 'freeair' (same as freeair_file)
firnice_daily_anomalies = ''    ; '' = the thermal melt adds the fixed sub-monthly list (variability_<region>.mdi);
                                ; a file = each month's real daily anomalies of the climate cell instead
                                ; (glogemflow_icetemp make_daily_anomalies.py), in the spin-up's reference year
                                ; averaged over the reference period's months; the mass balance keeps the list.
                                ; A run stops if it reaches months outside the file (e.g. before 1940 or
                                ; projections) or its climate cell has no series in the file
firnice_surface_cool    = 'n'   ; 'gilbert' = thermal surface min(0, 0.95 * air + firnice_surface_cool_dt)
                                ; instead of min(0, air): the snow surface colder than the air (Gilbert et al.
                                ; 2014, Col du Dome, daily means 2012-13)
firnice_surface_cool_dt = -3.4d ; K: -3.4 = the measured skin; -1.4 = with Gilbert's +2 K for sunlight
                                ; penetrating the snow (Trad of their firn model)
firnice_f_sur           = 0d    ; f_sur [K]: thermal surface min(0, air - f_sur), the snow surface colder than the air
                                ; by a calibrated amount; 0 = off
firnice_deepen_to_obs   = 'y'   ; 'y' = at borehole bands the column runs at least to the deepest
                                ; reading; 'n' = to the band's ice thickness, as elsewhere
firnice_adv_depthmap    = 'relative'   ; where the horizontal advection reads the band above: 'relative' = same
                                ; relative depth of the resolved column (stretches a shallow neighbour over a
                                ; deepened borehole column); 'inventory' = relative to the inventory thickness,
                                ; no source below the neighbour's column; 'absolute' = same depth in metres
firnice_temp_calib      = 'n'   ; 'y' = apply per-band transfer-model calibration
firnice_temp_calib_file = ''    ; path to per-glacier override file; '' = use transfer model or defaults
firnice_temp_calib_knn_file = '' ; path to per-glacier k-NN residual-correction file (band-aware);
                                  ; ADDS delta_pf/delta_ds/delta_z0 to the per-band transfer-model
                                  ; baseline computed per elevation band — requires firnice_temp_calib='y'
                                  ; (see read/apply_firnicetemp_calibration_knn.pro); '' = disabled
                                  ; DEPRECATED — undamped nearest-neighbour copy, diagnosed to
                                  ; produce negative real-world R² (correction applied at full
                                  ; strength up to 650+ km); superseded by
                                  ; firnice_temp_calib_bayes_file below. Kept only as a LOO
                                  ; comparison baseline (see icetemp.calibration.validation).
firnice_temp_calib_bayes_file = '' ; path to per-glacier Kennedy-O'Hagan Bayesian residual-
                                  ; correction file (band-aware); ADDS delta_pf/delta_ds/delta_z0
                                  ; to the per-band transfer-model baseline, same mechanism as
                                  ; the _knn file above — requires firnice_temp_calib='y' (see
                                  ; read/apply_firnicetemp_calibration_bayes.pro and Python
                                  ; icetemp.calibration.writeback.ResidualWriter); '' = disabled

; --- geometry evolution model
; two options: (1) Δh parameterisation (Huss et al., 2010) via glacier_retreat='y',
;              (2) coupled flowline model GloGEMflow (Zekollari et al., 2019) via use_flow_model='y'
use_flow_model = 'n' ; 'y' activates GloGEMflow and disables the Δh parameterisation below

; Spin-up quality gate (2026-09-09): after the spin-up (or a cache hit) the flow model is
; only used if its un-rescaled survey-year state reproduces the observed glacier:
; |volume error| <= spinup_gate_vol_tol AND modelled length >= spinup_gate_len_min x observed.
; Otherwise the glacier runs on the Δh parameterisation from the start (like a failed

; runtime growth limit (limit_glacier_growth.pro); same numbers as check_gmip4_output.py
growth_max_thick = 2000.0d0 ; m, mean thickness no glacier may exceed
growth_max_vol   = 50.0d0   ; km3, only bites together with growth_max_rel
growth_max_rel   = 20.0d0   ; x the inventory volume
; spin-up). Evaluated in glogemflow_coupled.pro; see the comment there for the evidence.
spinup_gate_vol_tol = 0.5d0   ; fraction of observed volume
spinup_gate_len_min = 0.5d0   ; fraction of observed length

; --- glacier retreat module (Δh parameterisation option)
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
band_extension = 'n' ; 'y': the elevation-band files (belev) continue down to band_ext_depth below each glacier, with the balance an ice surface would have there (forcing for ice-flow models)
band_ext_depth = 1500. ; [m] depth of the band extension below the lowest band of the glacier inventory (not below sea level)
band_blend_depth = 300. ; [m] below the front over which the extension bands blend from the glacier's own parameters into the regional medians (at least)
band_blend_dtdz = 0.003 ; [degC/m] largest change of the temperature offset per metre in that blend (about half a lapse rate)
band_blend_dlnp = 5e-4 ; [1/m] largest relative change of a degree-day factor or c_prec per metre in that blend

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

; snowline below the glacier front: ground bands down to snowline_ext_depth [m] below each glacier's inventory
; front (not below sea level) carry a snow pack, with the front's precipitation, and the snowline uses them when
; no glacier band is snow-free (procedures/processing/snowline_extension.pro). All other output is unchanged.
; 0 = off, e.g. 1500.
snowline_ext_depth = 0.
; folder with the valley floor below each glacier (valley_floor_rgi<RGIversion>_<region>.dat, written by
; scripts/valley_floor.py): the ground bands stop at the glacier's own valley floor, i.e. the valley's depth below
; the glacier on the file's terrain, never deeper than snowline_ext_depth; '' = no terrain, every glacier gets
; snowline_ext_depth
snowline_ext_valley = ''

; default output file list (reduced output); full_output='y' variants set in Zone 2
if full_output eq 'n' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
  'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', $
  'Discharge', 'Discharge_gl', '', '', '', '', '']
format_of = ['f10.3', 'f10.4', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'f8.3', 'i6', 'f7.1', 'f8.3', 'i6', 'f10.5', 'f8.3', 'f9.4', 'f9.4', 'f9.4', 'f9.4', 'f9.4', 'f10.5', 'i6']

write_mb_elevationbands = 'n'
eval_mbelevsensitivity = 'n'
count_mbelevsens_v0 = 5

past_out = 'y'

write_hypsometry_files = 'n'
write_geometry_output = 'n' ; 'y' to save per-glacier geometry and flowline grid history (.sav)

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
;
; The environment variable GLOGEM_CONFIG can point to an alternative config
; file (e.g. a test config kept outside the repo root), in which case the
; default base_dir/config.pro is not loaded.
env_cfg = getenv('GLOGEM_CONFIG')
if env_cfg ne '' then user_config = env_cfg $
else user_config = base_dir + '/config.pro'
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
    AMOC = 'n'
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
    AMOC = 'n'
  end
  'GMIP4': begin
    ; Glacier Model Intercomparison Project 4 — fixed model/scenario specifications.
    ; Not all model/SSP combinations are available (see GMIP4 protocol).
    ; ssp370 is used as the primary batch scenario.
    GCM_model = ['ACCESS-ESM1-5', 'BCC-CSM2-MR', 'CESM2-WACCM', 'IPSL-CM6A-LR', 'MRI-ESM2-0', 'MPI-ESM1-2-HR', 'MIROC6', 'NorESM2-MM']
    GCM_rcp = ['ssp126', 'ssp370', 'ssp585', 'ssp534-over']
    GCM_experiment = 'r1i1p1f1'
    ; Must stay an 8-element array (one entry per GCM_model), matching every
    ; other MIP case below — a bare scalar indexes fine at rcp_batch[0] (the
    ; first GCM) but throws "subscript out of range" as soon as the GCM loop
    ; advances to gcms=1, i.e. as soon as more than one model is requested
    ; in the same run (GCM_model_idx=[0], "all") rather than one model per
    ; invocation (GCM_model_idx=[N]).
    rcp_batch = intarr(8) + 3
    GCM_data = 'gmip4'
    CMIP6 = 'n'
    GMIP4 = 'y'
    AMOC = 'n'
    ; GMIP4 wants the ERA5 hindcast to evolve the geometry, not hold it fixed.
    ; Reset to 'n' further below whenever tran[1] > 2025, so projections are unaffected.
    hindcast_dynamic = 'y'
 end
  'AMOC': begin
    ; AMOC GCMs                                                                                                                                                                                                                                                                      
    GCM_model = ['CESM', 'GFDL_ESM2M'] 
    GCM_rcp = ['RCP26_045sv', 'RCP45_045sv', 'RCP85_045sv', 'RCP45_018sv', 'RCP85_018sv', 'ENS1_2degC_hos_Eref', 'ENS1_2degC_ref']                                                                                                                                                                    
    GCM_experiment = 'r1i1p1f1'
    rcp_batch = intarr(8) + 3 ;                                                                                                                                                                                                                                                          
    GCM_data = 'amoc'
    CMIP6 = 'n'
    GMIP4 = 'n'
    AMOC = 'y'
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
if full_output eq 'y' then begin
  if time_resolution eq 'monthly' then outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
    'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', 'Discharge', 'Discharge_gl' $
    , 'Balance_mon', 'Precipitation_mon', 'Accumulation_mon', 'Melt_mon', 'Refreezing_mon', 'Snowline_mon'] $
  else outf_names = ['Area', 'Volume', 'Annual_Balance_sfc', 'Winter_balance_sfc', 'Icemelt_sfc', $
    'Snowmelt_sfc', 'Accumulation_sfc', 'Rain_sfc', 'ELA', 'AAR', 'Refreezing_sfc', 'Hmin', 'Frontal_ablation', 'Discharge', 'Discharge_gl' $
    , 'Accumulation_day', 'Rain_day', 'Snowmelt_day', 'Icemelt_day', 'Refreezing_day', 'Snowline_day']
endif

; Backward compatibility: firnice_write gained a third element (full T field) after
; some config.pro files were written with only two. Indexing firnice_write[2] on such
; a config would abort the run, so pad any short array with 'n' (feature off) here.
if n_elements(firnice_write) lt 3 then $
  firnice_write = [firnice_write, replicate('n', 3 - n_elements(firnice_write))]

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

if calibrate eq 'n' and tran[1] lt 2026 then begin
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

if use_flow_model eq 'y' then advance = 'y' ; flow model requires advance bands
if glacier_retreat eq 'n' and hindcast_dynamic ne 'y' and use_flow_model eq 'n' then advance = 'n'

if read_parameters eq 'y' then calibrate = 'n'

if single_glacier ne '' then grid_run = 'n'

; dynamics only inside the reanalysis record; ERA5 currently ends 2025
if tran[1] gt 2025 then hindcast_dynamic = 'n'

; band_extension: only the parts it reproduces; the glacier itself is unchanged
if calibrate eq 'y' then band_extension = 'n'
if band_extension eq 'y' then begin
  if meltmodel ne '1' then message, 'band_extension needs meltmodel ''1'''
  if time_resolution ne 'monthly' then message, 'band_extension is only available for monthly runs'
  if read_parameters ne 'y' then message, 'band_extension needs read_parameters=''y'' (regional parameters from the calibration file)'
  if debris_supraglacial eq 'y' or firnice_temperature eq 'y' or refreezing_full eq 'y' then $
    message, 'band_extension does not support debris_supraglacial, firnice_temperature or refreezing_full'
  if band_ext_depth le 0 then message, 'band_ext_depth must be positive [m]'
  if band_blend_depth le 0 or band_blend_dtdz le 0 or band_blend_dlnp le 0 then $
    message, 'band_blend_depth, band_blend_dtdz and band_blend_dlnp must be positive'
  if write_mb_elevationbands ne 'y' then begin
    print, 'NOTE: band_extension set to ''n'': it only adds rows to the elevation-band files (write_mb_elevationbands=''y'')'
    band_extension = 'n'
  endif else print, 'Band extension: elevation-band files down to ' + strtrim(string(band_ext_depth, format='(f8.0)'), 2) + ' m below each glacier (band_ext_depth), not below sea level'
endif

if meltmodel eq '3' then c2_tolerance = c2m3_tolerance

if debris_supraglacial eq 'n' then eval_mbelevsensitivity = 'n'

if firnice_temperature eq 'n' then firnice_batch = 'n'

; latent heat released when percolating water refreezes in the thermal model [J m-3]: per m of ice
; (Lh_rf, as before) or per m of water
Lh_fit = Lh_rf
if firnice_lh_water eq 'y' then Lh_fit = lhf * 1000.d
if total(firnice_perm_limit eq ['hl', 'profile', 'cold']) eq 0 then $
    message, "firnice_perm_limit must be 'hl', 'profile' or 'cold'"
if total(firnice_thermal_lapse eq ['floor', 'reanalysis', 'stations']) eq 0 then $
    message, "firnice_thermal_lapse must be 'floor', 'reanalysis' or 'stations'"
if total(firnice_deepen_to_obs eq ['y', 'n']) eq 0 then message, "firnice_deepen_to_obs must be 'y' or 'n'"
if total(firnice_adv_depthmap eq ['relative', 'inventory', 'absolute']) eq 0 then $
    message, "firnice_adv_depthmap must be 'relative', 'inventory' or 'absolute'"
if total(firnice_snow_refreeze eq ['y', 'n']) eq 0 then message, "firnice_snow_refreeze must be 'y' or 'n'"
if firnice_spinup_dT ne 0 and firnice_forcing_toff ne 'n' then $
    message, "firnice_spinup_dT needs firnice_forcing_toff = 'n'"
if firnice_write_melth eq 'y' and firnice_forcing_toff ne 'n' then $
    message, "firnice_write_melth needs firnice_forcing_toff = 'n'"
if total(firnice_orient eq ['n', 'table']) eq 0 then message, "firnice_orient must be 'n' or 'table'"
if firnice_orient eq 'table' then $
  if firnice_temperature ne 'y' or firnice_forcing_toff ne 'n' or firnice_orient_dir eq '' then $
    message, "firnice_orient = 'table' needs firnice_temperature 'y', firnice_forcing_toff 'n' and firnice_orient_dir"
if firnice_orient eq 'table' then if not file_test(firnice_orient_dir, /directory) then $
    message, 'firnice_orient: no folder ' + firnice_orient_dir
if total(air_temperature eq ['era5_2m', 'freeair']) eq 0 then message, "air_temperature must be 'era5_2m' or 'freeair'"
if air_temperature eq 'freeair' then begin
  if time_resolution ne 'monthly' then message, "air_temperature = 'freeair' needs monthly steps"
  if not (freeair_blend_depth gt 0) then message, 'freeair_blend_depth must be > 0'
  if firnice_temperature eq 'y' then begin
    if firnice_forcing_toff ne 'n' or firnice_thermal_lapse ne 'reanalysis' then $
      message, "air_temperature = 'freeair' with the thermal model needs firnice_forcing_toff 'n' and " + $
               "firnice_thermal_lapse 'reanalysis'"
    firnice_thermal_air = 'freeair'
  endif
endif
; without the thermal model (e.g. calibrate = 'y') its air setting has no effect
if firnice_temperature eq 'n' then firnice_thermal_air = 'era5_2m'
if total(firnice_thermal_air eq ['era5_2m', 'freeair']) eq 0 then $
    message, "firnice_thermal_air must be 'era5_2m' or 'freeair'"
; one table for the mass balance and the thermal model
if freeair_file ne '' and firnice_freeair_file ne '' and freeair_file ne firnice_freeair_file then $
    message, 'freeair_file and firnice_freeair_file name different tables'
if freeair_file eq '' then freeair_file = firnice_freeair_file
use_freeair = (air_temperature eq 'freeair' or (firnice_temperature eq 'y' and firnice_thermal_air eq 'freeair')) $
    ? 'y' : 'n'
if use_freeair eq 'y' then if not file_test(freeair_file) then message, 'free air: no file ' + freeair_file
if firnice_thermal_air eq 'freeair' then $
  if firnice_temperature ne 'y' or firnice_forcing_toff ne 'n' or firnice_thermal_lapse ne 'reanalysis' then $
    message, "firnice_thermal_air = 'freeair' needs firnice_temperature 'y', firnice_forcing_toff 'n' and " + $
             "firnice_thermal_lapse 'reanalysis'"
if total(firnice_surface_cool eq ['n', 'gilbert']) eq 0 then message, "firnice_surface_cool must be 'n' or 'gilbert'"
if firnice_f_sur lt 0d then message, 'firnice_f_sur must be >= 0'
if firnice_f_sur ne 0d and firnice_surface_cool ne 'n' then message, "firnice_f_sur needs firnice_surface_cool 'n'"
if firnice_temperature eq 'y' and firnice_forcing_toff eq 'n' then $
  if meltmodel ne '1' or time_resolution ne 'monthly' or debris_supraglacial ne 'n' then $
    message, "firnice_forcing_toff = 'n' needs meltmodel '1', monthly steps and no supraglacial debris"
; without the thermal model (e.g. calibrate = 'y') the daily anomalies have no effect
if firnice_temperature eq 'n' then firnice_daily_anomalies = ''
if firnice_daily_anomalies ne '' then begin
  if firnice_temperature ne 'y' or firnice_forcing_toff ne 'n' or submonth_variability ne 'y' then $
    message, "firnice_daily_anomalies needs firnice_temperature 'y', firnice_forcing_toff 'n' and " + $
             "submonth_variability 'y'"
  if not file_test(firnice_daily_anomalies) then message, 'firnice_daily_anomalies: no file ' + firnice_daily_anomalies
endif

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

; Daily->monthly NetCDF aggregation only applies to daily runs that write NetCDF.
if time_resolution ne 'daily' or write_netcdf ne 'y' then netcdf_daily_aggregated_monthly = 'n'

; snowline below the glacier front
if snowline_ext_depth lt 0 then message, 'snowline_ext_depth must be 0 (off) or positive [m]'
if snowline_ext_depth eq 0 and snowline_ext_valley ne '' then print, 'NOTE: snowline_ext_valley has no effect while snowline_ext_depth = 0'
if snowline_ext_depth gt 0 then begin
  if meltmodel ne '1' then message, 'snowline_ext_depth needs meltmodel ''1'''
  if eval_mbelevsensitivity eq 'y' then message, 'snowline_ext_depth does not work with eval_mbelevsensitivity'
  if outf_names[14] eq '' then begin
    print, 'NOTE: snowline_ext_depth set to 0: the snowline is not computed when outf_names[14] is empty'
    snowline_ext_depth = 0.
  endif else begin
    print, 'Snowline below the glacier front: ground bands down to ' + strtrim(string(snowline_ext_depth, format='(f8.0)'), 2) + ' m below the front (snowline_ext_depth)'
    if snowline_ext_valley ne '' then print, '  ... and not below each glacier''s valley floor from ' + snowline_ext_valley
    if full_output ne 'y' and write_netcdf ne 'y' then $
      print, 'NOTE: snowline_ext_depth: the snowline is written only with full_output=''y'' or write_netcdf=''y'''
  endelse
endif

; **********************************
; -----------------------------------
; initialize refreezing model
rf_layers = 8 ; number of layers in refreezing model
rf_melcrit = 0.02 ; critical amount of melt for initialising refreezing module (0.002 earlier, what is better?) [m.w.e.]
dens_rf = [300, 300, 400, 450, 500, 550, 600, 650] ; approx. density of layers
rf_dz = 1. ; layer thickness (m)
rf_dsc = 3. ; increase in temporal resolution (num. stability of heat conduction)
; rf_dt: 30 days / rf_dsc (monthly) or 1 day / rf_dsc; refreezing_full (rf_dtm) and the firn/ice temperature model
; (fit_dt) set their sub-steps from mon_len instead
if time_resolution eq 'daily' then begin
  rf_dt = 3600. * 24. / rf_dsc ; compute time step
endif else begin
  rf_dt = 3600. * 24. * 30. / rf_dsc ; compute time step
end

; === ice temperature model initialisation
; Vertical grid of the englacial temperature model, as blocks of equal-thickness layers.
; The third block was extended from 10 to 23 layers, taking the column from 259 m to 519 m
; while keeping the 20 m spacing. Indices 0-29 are unchanged, so 2/10/18 still mean 2/14/54 m.
;
; The spacing matters as much as the reach. A first attempt appended 5 x 50 m below 259 m:
; that moved the geothermal bed node to the right depth, but the model only solves interior
; layers to tt-2, so for a 316 m band the deepest SOLVED value stayed at 259 m and 57 m of
; ice above the bed had no temperature. Continuing at 20 m instead caps that gap at 19 m.
; Only 17 of the 4079
; RGI7 CentralEurope glaciers are thicker than 259 m -- but they hold 35 % of the region's
; ice volume, and the deepest is 421 m, so 509 m covers the Alps with margin. Before this,
; the geothermal flux for those glaciers was injected at 259 m rather than at the bed and
; their basal thermal regime could not be diagnosed at all.
;
; Extending the grid is close to free: tt = min([ind+1, total(fit_layers)]) in
; firnice_temperature_model.pro is set from each band's own thickness and every conduction
; and advection loop runs to tt-2, so thin bands solve exactly as many layers as before.
; Only memory and the genuinely deep bands pay. For a global run, lengthen the last block
; (Alaska and the Karakoram reach ~1000 m); nothing else needs to change.
fit_layers = [10, 10, 23]
fit_dzstep = [1., 5., 20.]
; fit_dens is defined below, after fit_dz, because it is resampled onto the layer grid.

; --- physical constants
cice = 1890000. ; [J m-3 K-1] heat capacity of ice
cair = 1297. ; [J m-3 K-1] heat capacity of air
kice = 2.33 ; [J s-1 K-1 m-1] conductivity of ice
k_ca = [0.024d, -1.23d-4, 2.5d-6] ; Calonne et al. (2011) snow/firn conductivity polynomial,
                                  ; k = poly(rho) [W m-1 K-1], rho in kg m-3
k_ice_a = 9.828d   ; Yen (1981) ice conductivity, k = k_ice_a*exp(k_ice_b*T), T in K
k_ice_b = -5.7d-3  ; gives 2.07 at 0 degC, 2.32 at -20 degC
rho_ice_k = 900.0d ; [kg m-3] firn-ice transition: at or above this, use the ice law
kair = 0.001 ; [J s-1 K-1 m-1] conductivity of air

cap = (1 - dens_rf / 1000.) * cair + dens_rf / 1000. * cice
cond = (1 - dens_rf / 1000.) * kair + dens_rf / 1000. * kice

min_f = 0.0001
max_f = 0.5

fit_dz = dblarr(2, total(fit_layers))

; Layer thicknesses, block by block. Generalised from three hardcoded blocks so that
; fit_layers / fit_dzstep can be any matching length.
_l0 = 0L
for _blk = 0, n_elements(fit_layers) - 1 do begin
  for i = _l0, _l0 + fit_layers[_blk] - 1 do fit_dz[0, i] = fit_dzstep[_blk]
  _l0 = _l0 + fit_layers[_blk]
endfor

for i = 1, total(fit_layers) - 1 do begin
  fit_dz[1, i] = fit_dz[1, i - 1] + fit_dz[0, i]
endfor

; Firn density as a curve in DEPTH, resampled onto whatever layer grid is in use. It used to be
; an 18-element list indexed by LAYER, so its meaning changed silently with the grid. The
; reference points are the original values at their original depths, so this is a no-op on the
; [10x1, 10x5, 23x20] grid. Below the deepest reference point the column is solid ice.
fit_dens_z   = [0.d, 1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 19, 24, 29, 34, 39, 44, 49]
fit_dens_ref = [250.d, 300, 360, 420, 480, 550, 580, 610, 640, 670, 700, 730, 760, 790, 820, 850, 880, 900]
fit_dens     = (interpol(fit_dens_ref, fit_dens_z, reform(fit_dz[1,*])) > fit_dens_ref[0]) < 900.d

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

; Cap rcp_batch to the actual number of available RCPs to prevent out-of-range
; access in the rcps loop when GCM_rcp has been reduced by GCM_rcp_idx.
n_rcp_avail = n_elements(GCM_rcp)
ii_over = where(rcp_batch gt n_rcp_avail, ci_over)
if ci_over gt 0 then rcp_batch[ii_over] = n_rcp_avail

; Default firnice profile IDs (used as filename labels in prepare_output_firnicetemp.pro).
; setup_firnice_batch.pro overrides this for batch runs; here we fall back to '1','2','3',...
; so the profile files are named temp_ID1_<glacier>.dat etc. when firnice_batch='n'.
if n_elements(firnice_profile_ID) ne n_elements(firnice_profile) then $
  firnice_profile_ID = string(indgen(n_elements(firnice_profile)) + 1, fo='(i0)')
