; *****************************************
; *****************************************

; INPUT SECTION

; *****************************************
; *****************************************

; GloGEM.pro
; Input file for GloGEM, including all settings for running the model, calibration, and output specifications
; Settings are read in the main GloGEM.pro and then passed to the different subroutines
; Settings are structured in different sections, but some settings (e.g. calibration) also have sub-sections
; Settings are defined in the beginning of the file, but some settings are also dynamically adapted based on other settings (e.g. if calibrate='y' then some settings are automatically adapted to be consistent with calibration mode) 

; --- RGI-version selection
RGIversion='6'       ; version of the RGI to be used

; --- Time resolution selection 
time_resolution='daily'           ; 'daily'/'monthly' - SELECT TIME RESOLUTION OF MODELLING
;time_resolution='monthly'           ; 'daily'/'monthly' - SELECT TIME RESOLUTION OF MODELLING

; Dynamically detect the username and construct the directory path
username = GETENV('USER')  ; Get the current user's username from the environment

; Input folders where the geoemtric and climate data are stored (GloGEM shares)
main_dir     = '/itet-stor/' + username + '/glogem/'  ; Construct the main directory path
dir          = main_dir+'data/'                       ; Construct the general data folder path
dir_data     = main_dir+'/geometricdata/'+'rgiv'+RGIversion+'/bands/bands_consensus2019/' ; thickness data
dir_data_alt = main_dir+'/geometricdata/'+'rgiv'+RGIversion+'/bands/bands_HF2012/'        ; alternative thickness data (for cross-checks)
dir_clim     = main_dir+'climatedata/'                                  ; climate data

; Output (same machine as you run on)scratch via the network
; This is th only folder you need to change to store the results on your machine, 
; The rest of the paths are defined relative to this one
dirres=''  ; set this in ~/.glogem/config.pro (see config.pro.example)

; --- region selection
region_id_loop=[14,14]             ; Specify IDs of regions to be run according to region_batch.dat
;region_id_loop=[0,0]              ; Default, no loop

; -- size selection
size_range_overwrite='n'           ; Automatically overwriting size range of glaciers to be computed with value specied in regional_parameters_*
size_range=[0.002,100000]          ; [km2]     size_range to be calculated

; -- glacier / catchment selection
single_glacier='01450'             ; Calculate one single glacier only (specify RGI ID, e.g. 01450 for Aletschgletscher)
catchment_selection=''             ; Leave empty if running a single glacier or entire region; 
;catchment_selection='Alps_g5km2'  ; Calculate glaciers in a specific catchment (specify name of catchment, e.g. Alps_g5km2 for all glaciers in the Alps larger than 5 km2)

; --------------------------------------
; MAIN SETTINGS / MODES
; --------------------------------------

tran=[1940,2100]                   ; Time period of modelling. It uses reanalysis data as long as possible
find_startyear='y'                 ; Automatically determine first year of future modelling (based on date of inventory); 'n' ALSO to drive static output for GloGEMflow
calibrate = 'y'                    ; Calibrate model? 'y' to calibrate, 'n' to run model with given parameters
meltmodel='1'                      ; Select melt model to be used - 1: Classic degree-day model -  3: Simple energy-balance model (Oerlemans,2001)

; ---------------------------------------
; climate data
; --------------------------------------

; --- GCM data specifications
CMIP6='y'                          ; CMIP6 GCMs to be used?
long_GCM=''                        ; Runs until 2100
;long_GCM='long_'                  ; Runs until 2300
;GCM_data= 'cmip6'
;GCM_data= 'long_cmip6'            ; Runs until 2300
GCM_data= 'cmip6'

; Options for running one individual model
short_gcmchoice=[1,1,1]            ; GCM, SSP, experiment
;short_gcmchoice=0                 ; default - batch processing, all models

first_GCM=0                        ; First GCM to start with in batch processing; number MINUS 1 (referring to list below)

rcp_batch=[4,5,4,4,5,5,4,5,4,4,4,5,4]     ; number of SSPs per GCMs
expe_batch=[1,1,1,1,1,1,1,1,1,1,1,1,1]    ; number of experiments for GCMs

GCM_model=['BCC-CSM2-MR','CAMS-CSM1-0','CESM2','CESM2-WACCM','EC-Earth3','EC-Earth3-Veg','FGOALS-f3-L','GFDL-ESM4','INM-CM4-8','INM-CM5-0','MPI-ESM1-2-HR','MRI-ESM2-0','NorESM2-MM'] 
GCM_rcp=['ssp126','ssp245','ssp370','ssp585','ssp119','ssp534-over']
GCM_experiment=['r1i1p1f1','r2i1p1f1','r3i1p1f1','r4i1p1f1','r5i1p1f1','r6i1p1f1','r7i1p1f1']

; For runs until 2300 (long_)
if long_GCM ne '' then begin
   GCM_model=['ACCESS-CM2','ACCESS-ESM1-5','CESM2-WACCM','CanESM5','GISS-E2-1-G','GISS-E2-1-H','GISS-E2-2-G','IPSL-CM6A-LR','MIROC-ES2L','MRI-ESM2-0','UKESM1-0-LL']
   rcp_batch=[6,6,6,6,6,6,6,6,6,6,6,6,6,6]
endif

; --------------------------------------
; Re-analysis
; --------------------------------------

if time_resolution eq 'daily' then begin
   ; For the daily model: 
   ;reanalysis='era5land'            
   ;reanalysis='chelsaw5e5'
   ;reanalysis='ch2018'
   ;reanalysis='gswp3w5e5'
   reanalysis='era5'
endif else begin
   ; For the monthly model
   reanalysis='ERA5'
endelse
rea_eval=[1991,2020]              ; Important setting -> Time period for evaluating the bias of GCMs
grid_step=0.1                     ; Grid stepping of reanalysis data set
bias_correction='y'               ; Bias correction of GCM data based on re-analysis data? 'y' to activate, 'n' to use GCM data as they are
bias_correction_method=1          ; 1: Bias correction based on delta method; 2: Bias correction based on quantile mapping, working only for daily model and temperature for now

; --------------------------------------
; calibration (main setting given in the beginning)
; --------------------------------------
valiglaciers_only='n'    ; perform a calibration run for the WGMS validation glaciers only 
validation_dataset='seasonal/validate_final2017/validate_WGMS_'  ; to be updated
calibrate_individual='y'     ; parameter optimization for individual glaciers
calibrate_glacierspecific='y'  ; glacier-specific calibration based mb_glspec* files
calibrate_glacierspecific_period='2000_2020'
rhodv_iteration=''          ; default 
;rhodv_iteration='_iteration2'     ; iterating for density of volume change (target directory, reference No -1)

; read calibration periods etc based on file "calibration.dat"
sub_region=''               ; for subregion - a file defining extent may be provided
calperiod_ID=9              ; ID for specifying different calibration periods for the same region
                            ; ID 1: open
                            ; ID 3: open
                            ; ID 4: open
                            ; ID 5: regional calibration, Hugonnet2021
                            ; ID 8: glacier-specific calibration - DEBRIS-model
                            ; ID 9: glacier-specific calibration (Hugonnet2021)

caliphase_loop=3            ; 1: default (NO loop); 2; calibration phases 1-2; 3; calibration phases 1-3
calibration_phase='1'       ; 1: calibrate c_prec ; 2: DDF_snow ; 3: adjust temperature bias in ERA-data
c1_tolerance=[.8,2.4]       ; c_prec tolerance (irrelevant, as ranges are given in file)
c2_tolerance=[1.75,4.5]     ; DDF_snow tolerance - M1  (irrelevant, as ranges are given in file)
c2m3_tolerance=[7.,15.]     ; C1 tolerance - M3  
t_offset=0.                 ; default temperature correction of re-analysis data

repeat_calibration='y'       ; Repeat calibration iteratively for Toff_grid until all glaciers are calibrated 

; ***********
; other options

read_parameters='y'         ; read parameters for individual glaciers / regions from file
submonth_variability='y'    ; scheme to bring climate data to a submonthly scale
reanalysis_direct='n'       ; Run model directly with re-analysis data, without downscaling of alternative series
variability_bias='y'                             ; include bias in GCM variability
hindcast_dynamic='n'        ; change glacier area during hindcast period AFTER date of RGI (not relevant in present version)
write_file='y'              ; write results files?

; ***********
; parameters

; ----- accumulation model

dPdz=1.5                 ; [% per 100 m]   precipitation gradient (regionally specified in file!)
c_prec=1.5               ; [-]  multiplication factor   correction factor (regionally specified in file!)
snow_multiplier=1.2             ; [-] prescribing higher correction for snow falls
T_thres=1.5                     ; [deg C]  temperature threshold solid-liquid, including transition period +-1 deg
no_incprec=[0.75,1000,2,2]      ; precipitation reduction at very high elevation
                                ; 1: fraction of elevation range (-),
                                ; 2: crit elevation range for glacier (m)
                                ; 3/4: parameters of reduction function (ax^b) above critical elevation

; ----- melt model

; meltmodel 1 - conventional DDF
DDFsnow0=3        ; (mm d-1 C-1) degree-day factor snow (irrelevant, specified in file)
DDFice0=6         ; (mm d-1 C-1) degree-day factor snow (irrelevant, specified in file)
T_melt=0          ; critical temperature for melting [deg C]

; meltmodel 3 - Simple energy balance model (Oerlemans, 2001)
C0=-45           ; parameter 1 (irrelevant, specified in file)
C1=10            ; parameter 2 (irrelevant, specified in file)

alb_ice=0.3      ; Albedo for ice
alb_firn=0.5     ; Albedo for firn
alb_snow=0.7     ; Albedo for snow

; ------- supraglacial debris model

debris_supraglacial='n'              ; ACTIVATE MODEL FOR SUPRAGLACIAL DEBRIS
debris_pond_enhancementfactor=2         ; enhancement of bare-ice melt over pond/ice cliff fraction of band (no influence: 0)
debris_expansion='y'        ; spatial expansion of debris over time
debris_exp_gradient=2.0    ; [% a-1 frac-1] gradient of debris extension
debris_seed_bands=10       ; factor to scale decadal ELA-change into a number bands per year with new debris seed 
debris_initialband=0.01    ; [m] thickness of debris in newly generated formed bands with no initial observations
debris_pond_gradient=0.1     ; [% a-1 frac-1] gradient of pond/cliff extension [not used anymore - now automated??]
debris_ponddens_max=0.1    ; [-] maximum density of ponds within band [not used anymore - now automated??]
debris_thickening='y'       ; thickening of debris over time
debris_thick_gradient=1.0  ; [cm a-1 km-1]  thickening linearly increasing from ELA towards glacier terminus

; ------- Refreezing 

refreezing_full='n'              ; ACTIVATE FULL REFREEZING MODEL (takes very long)
refreezing_parametrised='y'      ; ACTIVATE REFREEZING MODEL (takes much shorter, but still some time)

; ------- Englacial temperature model

firnice_temperature='n'          ; ACTIVATE ICE TEMPERATURE MODEL - compute firn/ice temperatures transiently (not just for refreezing)
firnice_write=['y','y']          ; output of overall (time series, annual) and detailed (profiles, monthly) files
firnice_batch='y'                ; Run batch (all sites contained in icetemperature_batch.dat)
; only relevant if defined manually (firnice_runbatch='n' )
firnice_profile=[0.2,0.65,0.95]      ; (max 3.) manually inserting elevations of profiles to be written (<1: ratio of elev. range, >1: masl)
; firnice_profile=[3000,3500,4000]
enable_advection='n'             ; ACTIVATE ADVECTION OF TEMPERATURE IN FIRN/ICE
advection_write='n'              ; write out advection of temperature in firn/ice
; activate/deactivate permeability model
firn_permeability = 'y'          ; 'y' to activate firn permeability model
ice_permeability  = 'n'          ; 'y' to activate ice  permeability model

; ----- glacier retreat module

glacier_retreat='y'  ; ACTIVATE GLACIER GEOMETRY CHANGE MODEL
expon=2.             ; Parameter for valley shape regulating band area loss depending on thickness loss
dh_size=[5,20]       ; km2 Boundary between different empirical dh-parameterizations used (according to Huss et al., 2010)
redistribute_vplus='y'      ; (y/n) Redistribution of very negative/positive elevation changes at tongue over glacier?
advance='y'        ; Glacier advance model (might results in model instabilities...)
adv_addband0=10            ; number of added elevation bands in front of glacier
adv_calving=-100.          ; [m] default=0 (no calving), terminal elevation of glacier bed
adv_fcrit=2.               ; [m/a] Elevation gains above will be distributed
adv_terminusfraction=0.2   ; Use this fraction of elevation range to determine potential area in front of glacier
adv_lookup='n'             ; if glacier volume during positive years is smaller than initial volume, draw glacier geometry from a look-up table
                               ; (well, the idea was good but I believe it is not working, better do not activate)

; ----- calving
frontal_ablation='y'     ; ACTIVATE FRONTAL ABLATION MODEL (only marine-terminating, no lakes at the moment)
                         ; according to Oerlemans&Nick, 2005

alpha_f=0.7      ; parameters of calving model (irrelevant, read from file)
calv_sep=1.25    ; [m w.e.] as threshold: separate calving flux into gl geom. change AND direct break off at terminus
c_calving=2.4
regparams_readfromfile='y'    ; reading parameters from regional file or use above ones?
length_corrfact=1.4     ; correction factor for length (according to Oerlemans)
ccorr_expon=2.5               ; bedrock profile corrected for parabola-shape
crit_ccorrdist=3000.          ; bedrock profile corrected for parabola-shape
bedrock_parabolacorr=0.2      ; bedrock profile corrected for parabola-shape

; --------------------------------------------
; OUTPUT

; fixing some variables
clim_subregion=''
full_output='n'

; define which files are written out
if time_resolution eq 'monthly' then $
   if full_output eq 'y' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation','Discharge','Discharge_gl'$
 ,'Balance_mon','Precipitation_mon','Accumulation_mon','Melt_mon','Refreezing_mon'] $
else if full_output eq 'y' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation','Discharge','Discharge_gl'$
 ,'Accumulation_day','Rain_day','Snowmelt_day','Icemelt_day','Refreezing_day','Snowline_day']

; output file-names equivalent for daily and monthly in case the
; reduced output option is used
if full_output eq 'n' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation',$
 'Discharge','Discharge_gl','','','','','']   ; reduced output - less monthly data
format_of=['f10.3','f10.4','f8.3','f8.3','f8.3','f8.3','f8.3','f8.3','i6','f7.1','f8.3','i6','f10.5','f8.3','f9.4','f9.4','f9.4','f9.4','f9.4','f10.5']
; format_of=['f10.3','f10.4','f8.3','f8.3','f8.3','f8.3','f8.3','f8.3','i6','f7.1','f8.3','i6','f10.5','f8.2','f8.2','f8.2','f8.2','f8.2','f8.2','f9.4','i7'] ; added by Alex to generate output

write_mb_elevationbands='n'     ; write out seasonal mass balance in elevation bands for every glacier
    eval_mbelevsensitivity='n'      ; evaluating mass balance sensitivity in each band to changing surface elevation
    count_mbelevsens_v0=5              ; number of elevations computed 

past_out='y'                 ; if files for PAST (runs only with observed climate) should be written to external folder (not files/)

write_hypsometry_files='n'   ; write out annual hypsometry for all glaciers

; --------------------------------------
; options for region to be calculated

lat0=[-9999,-9999]      ; or specify a sub region to be run with lat/lon degrees (not tested for a long time...)
lon0=[0,0]

lat0=[9999,9999]        ; run for entire region (perimeter determined automatically based on glaciers)

grid_run='y'     ; default, perform runs aggregated to a spatial grid (aligned with re-analysis?)

; ------------------
; plot

plot='n'           ; plot single glacier profiles  (currently taken out, might be included again if needed)
   elev_range_p=500   ; only for glaciers above this elevation range
   outst=10           ; [a] Interval of results output for compilation files (probably not relevant anymore)
areaplot='n'       ; not implemented anymore

; ------------------
; output settings

version_past=''       ; versioning for output of PAST, including ERA-file

dircali=''  ; set after user config is loaded below

; ------------------
; secondary settings

mon_len=[31,28,31,30,31,30,31,31,30,31,30,31]    ; days on month

min_tempbias=-8   ; default: -9999  - restrict extreme temperature biases 
min_precbias=0.05 ; default: -9999  - restrict extreme precipitation biases 

; nodata-valeus
noval=-9999
snoval=-99

rho=917.             ; density of ice
Lh_rf=334000.*rho    ; [J m-3] latent heat of fusion
lhf=334000.          ; [J kg-1] latent heat of fusion


; ----------------------------------
; some more definitions
if lat0[0] eq -9999 then grid_run='n'
if grid_run eq 'n' then areaplot='n'

; declination of sun for all months (mid-month)
; (relevant only for meltmodel 1 and 2)
decl_sun=[-21.26,-13.50,-2.11,9.85,19.16,23.31,21.18,13.34,1.91,-10.03,-19.27,-23.32]
asp_class=[0,45,90,135,180]

rddf_si=ddfice0/ddfsnow0
years=tran[1]-tran[0]+1

; days of month
if time_resolution eq 'monthly' then mon_len=[31,28,31,30,31,30,31,31,30,31,30,31] else mon_len=dblarr(365)+1   

; only partially implemented for daily version and unsure whether it would actually work out...
variability_bias_longterm='n'        ; include bias in GCM variability from month to month

; ----------------------
; User-specific overrides
; Copy config.pro.example to config.pro and set your values there.
; config.pro is git-ignored so it will never be accidentally committed.
user_config = base_dir + '/config.pro'
if file_test(user_config) then begin
  n = file_lines(user_config)
  lines = strarr(n)
  openr, lun, user_config, /get_lun
  readf, lun, lines
  free_lun, lun
  stmt = ''
  for i = 0, n-1 do begin
    line = strtrim(lines[i], 2)
    if line eq '' or strmid(line, 0, 1) eq ';' then continue
    if strmid(line, strlen(line)-1, 1) eq '$' then begin
      stmt += strmid(line, 0, strlen(line)-1) + ' '
    endif else begin
      stmt += line
      void = execute(stmt)
      stmt = ''
    endelse
  endfor
  print, 'Loaded user config: ' + user_config
endif
if dirres eq '' then message, 'dirres is not set. Copy config.pro.example to config.pro and set dirres there.'
dircali=dirres

; ----------------------
; IF - THEN for options (automatic exclusion - to avoid erroneous runs)

if calibrate eq 'y' then begin
   reanalysis_direct='y'
   read_parameters='n'
   write_mb_elevationbands='n'
   rcp_batch[0]=0 & expe_batch[0]=0 & first_GCM=0
   find_startyear='n'
   debris_expansion='n' & debris_thickening='n'
   firnice_temperature='n'
   if calibrate_glacierspecific eq 'y' and calperiod_ID ne 8 then calperiod_ID=9  ; setting cal-ID to 9 for glspec calibration
   short_gcmchoice=[1,1,1]   ; make sure that only one run is performed!
endif

if calibrate eq 'n' and tran[1] lt 2021 then begin   ; end year currently set by extent of available ERA5-dataset (2020)
   reanalysis_direct='y' 
   short_gcmchoice=[1,1,1]   ; make sure that only one run is performed!
   glacier_retreat='n'
   if hindcast_dynamic eq 'n' then find_startyear='n' 
endif

if calibrate eq 'n' then begin
   calibrate_individual='n'
   caliphase_loop=1
   calibration_phase='1'
endif

if glacier_retreat eq 'n' and hindcast_dynamic ne 'y' then advance='n'

if read_parameters eq 'y' then calibrate='n'     ; read parameter-mode - no calibration at the same time

if single_glacier ne '' then grid_run='n'

if tran[1] gt 2020 then hindcast_dynamic='n'

if meltmodel eq '3' then c2_tolerance=c2m3_tolerance

if debris_supraglacial eq 'n' then eval_mbelevsensitivity='n'

if firnice_temperature eq 'n' then firnice_batch='n'


; only reduced output for runs until 2300 (no Discharge)
if long_GCM ne '' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation',$
 '','','','','','','']

; **********************************   
; -----------------------------------
; initialize refreezing model
rf_layers  = 8                                 ; number of layers in refreezing model
rf_melcrit = 0.02                              ; critical amount of melt for initialising refreezing module (0.002 earlier, what is better?) [m.w.e.]
dens_rf    = [300,300,400,450,500,550,600,650] ; approx. density of layers
rf_dz      = 1.                                ; layer thickness (m)
rf_dsc     = 3.                                ; increase in temporal resolution (num. stability of heat conduction)
rf_dt      = 3600.*24.*30./rf_dsc              ; compute time step

; initialize ice temperature model
fit_layers = [10,10,10]  ; number of layers with given thickness (max. 260m in this setup) 
fit_dzstep = [1.,5.,20.] ; layer thickness [m]

; reference density profile, shifted depending on snow/firn situation 
fit_dens = [250,300,360,420,480,550,580,610,640,670,700,730,760,790,820,850,880,900] ; kg m-3

; physical constants
cice = 1890000. ; heat capacity of ice [J m-3]
cair = 1297.    ; heat capacity of air
kice = 2.33     ; conductivity ice [J s-1 K-1 m-1]
kair = 0.001    ; conductivity air [J s-1 K-1 m-1]

; compute heat capacity and conductivity of layers
cap  = (1-dens_rf/1000.)*cair+dens_rf/1000.*cice ; compute heat capacity of layers
cond = (1-dens_rf/1000.)*kair+dens_rf/1000.*kice ; compute conductivity of layers

; set min and max values for permeability reduction factor f
min_f = 0.0001
max_f = 0.5

; Initialize fit_dz with appropriate dimensions -> fit_dz is a 2D array that stores the thickness of each layer
fit_dz = dblarr(2, total(fit_layers))

; Set thickness of first layers
for i = 0, fit_layers[0] - 1 do begin
    fit_dz[0, i] = fit_dzstep[0]
endfor

; Set thickness of second set of layers
for i = fit_layers[0], total(fit_layers[0:1]) - 1 do begin
    fit_dz[0, i] = fit_dzstep[1]
endfor

; Set thickness of third set of layers
for i = total(fit_layers[0:1]), total(fit_layers[0:2]) - 1 do begin
    fit_dz[0, i] = fit_dzstep[2]
endfor

; Accumulate thicknesses
for i = 1, total(fit_layers) - 1 do begin
    fit_dz[1, i] = fit_dz[1, i - 1] + fit_dz[0, i]
endfor

; -------------------------------------
; short_gcmchoice - get individual GCMs
;   (does only need adapting when short_gcmchoice option is used)

if short_gcmchoice[0] ne 0 then begin

if CMIP6 eq 'n' then begin

tt=['BCC-CSM1-1','CanESM2','CCSM4','CNRM-CM5','CSIRO-Mk3-6-0','GFDL-CM3','GISS-E2-R','HadGEM2-ES','INMCM4','IPSL-CM5A-LR','MIROC-ESM','MPI-ESM-LR','MRI-CGCM3','NorESM1-M']
GCM_model=[tt[short_gcmchoice[0]-1]]
tt=['rcp45','rcp85','rcp26']
GCM_rcp=[tt[short_gcmchoice[1]-1]]
tt=['r1i1p1','r2i1p1','r3i1p1','r4i1p1','r5i1p1']
GCM_experiment=[tt[short_gcmchoice[2]-1]]

rcp_batch[0]=0 & expe_batch[0]=0 & first_GCM=0

endif else begin

tt=['BCC-CSM2-MR','CAMS-CSM1-0','CESM2','CESM2-WACCM','EC-Earth3','EC-Earth3-Veg','FGOALS-f3-L','GFDL-ESM4','INM-CM4-8','INM-CM5-0','MPI-ESM1-2-HR','MRI-ESM2-0','NorESM2-MM','CanESM5']
GCM_model=[tt[short_gcmchoice[0]-1]]
tt=['ssp126','ssp245','ssp370','ssp585','ssp119']
GCM_rcp=[tt[short_gcmchoice[1]-1]]
tt=['r1i1p1f1','r2i1p1f1','r3i1p1f1','r4i1p1f1','r5i1p1f1','r6i1p1f1','r7i1p1f1']
GCM_experiment=[tt[short_gcmchoice[2]-1]]

rcp_batch[0]=0 & expe_batch[0]=0 & first_GCM=0

endelse

endif
