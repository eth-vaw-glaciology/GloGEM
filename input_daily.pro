; *****************************************
; *****************************************

; ** INPUT SECTION ** ;

; *****************************************
; *****************************************

dir = '/scratch-third/lvantrich/glogemd/data/'                                                  ; general data folder
dirres = '/scratch-third/lvantrich/glogemd/'                                                    ; output folder   - glacier-specific results
dir_data = '/scratch_net/iceberg_second/mhuss/global_thickness/rgi60/bands_consensus2019/'      ; thickness data
dir_data_alt = '/scratch_net/iceberg_second/mhuss/global_thickness/rgi60/bands_HF2012/'         ; alternative thickness data (for cross-checks)
dir_clim = '/scratch-third/lvantrich/isimip3b/climate_files/'                                   ; Climate data from isimip3b


glogem_daily = 'y'                                                                              ; Not yet implemented -> goal is to only have one input file to run GloGEM monthly or GloGEM daily (code, not the data)
monthly_clim = 'y'                                                                              ; Artificially compressing daily climate data to a monthly resolution
submonth_variability = 'y'                                                                      ; Artificially adding some daily variation for the monthly mean (if monthly mean < 0°C, pdd can occur)
or_temp = 'n'                                                                                   ; Keeping original temperatures for melting


if monthly_clim eq 'y'then add = '_MO' else add=''  ; Different name
if submonth_variability eq 'y' then add = add+'sub'                                             ; Different name
if or_temp eq 'y' then add = add+'2'
variability_bias_longterm = 'n' ; Include bias in GCM variability from month to month

region_id_loop = [14,14]                                                                        ; specify IDs of regions to be run according to region_batch.dat (C-EU = 14, C-AS = 16)
size_range = [0.000001,100000]                                                                     ; [km2] size_range to be calculated
size_range_overwrite = 'y'                                                                      ; Automatically overwriting size range of glaciers to be computed with value specied in regional_parameters_*
catchment_selection = 'Alps_g5km2' + add                                                        ; Specific catchment or region. Needs to be specified with a dat file containing all the RGI numbers
single_glacier=''                                                                               ; Calculate one single glacier only

tran = [1980,2100]                                                                              ; Time period of modelling
find_startyear = 'y'                                                                            ; Automatically determine first year of future modelling (based on date of inventory); 'n' ALSO to drive static output for GloGEMflow
version_past = ''                                                                               ; Versioning for output of PAST, including ERA-interim file


; ** CLIMATE DATA ** ;
CMIP6 = 'y'
long_GCM = ''                                                                                   ; For runs until 2300
short_gcmchoice = [1,1,1]   ; model, rcp, experiment
short_gcmchoice = 0        ;default
first_GCM = 0                                                                                     ; Number MINUS 1 (referring to list below)
rcp_batch = 0        ; default - manual choice
expe_batch = 0       ; default - manual choice
expe_batch = [1,1,1,1,1,1,1,1,1,1,1,1,1]    ; for all GCMs
GCM_model = ['mpi-esm1-2-hr']         ; Selection of GCMs to use for the model
GCM_rcp = ['ssp126', 'ssp370', 'ssp585']                                                                  ; Selection of SSPs to use for the model
GCM_experiment = ['r1i1p1f1']

; Re-analysis + GCMs + BIAS
reanalysis = 'chelsa-w5e5'                                                                      ; Reanalysis data
rea_eval = [1981,2010]                                                                          ; Not used for isimip but keep for now
GCMdata = 'CMIP6_daily'                                                                         ; Subfolder of the GCM data
clim_subregion = ''
bias_correction = 'y'                                                                           ; Bias correction (delta method or not)

; ** CALIBRATION ** ;
calibrate = 'n'                                                                                 ; Calibrate or not
valiglaciers_only = 'n'                                                                         ; Perform a calibration run for the WGMS validation glaciers only
calibrate_individual = 'y'                                                                      ; Parameter optimization for individual glaciers
calibrate_glacierspecific = 'y'                                                                 ; Glacier-specific calibration based mb_glspec* files
calibrate_glacierspecific_period = '2000_2010'                                                  ; Calibration using full period of Hugonnet (2000-2020) or half of it (2000-2010)

; read calibration periods etc based on file "calibration.dat"
sub_region=''               ; for subregion - a file defining extent CAN be provided
calperiod_ID=9                  ; ID for specifying different calibration periods for the same region
                                ; ID 1: regional calibration, Gardner2013
                                ; ID 3: regional calibration, Zemp2019
                                ; ID 4: regional calibration, SROCC2019
                                ; ID 5: regional calibration, Hugonnet2020
                                ; ID 6: regional calibration, Hugonnet2020,H&F2012thickness
                                ; ID 8: re-calibration for Caucasus debris-cover study
                                ; ID 9: glacier-specific calibration (Hugonnet2021)

caliphase_loop=3             ; 1: default (NO loop); 2; calibration phases 1-2; 3; calibration phases 1-3
calibration_phase='1'        ; 1: calibrate c_prec ; 2: DDF_snow ; 3: adjust temperature bias in ERA-data
c1_tolerance=[.8,2.4]    ; c_prec tolerance
c2_tolerance=[1.75,4.5]  ; DDF_snow tolerance - M1
c2m3_tolerance=[7.,15.]     ; C1 tolerance - M3
t_offset=0.              ; default temperature correction of re-analysis data
repeat_calibration='y'       ; Repeat calibration iteratively for Toff_grid until all glaciers are calibrated 


; ** IMPORTANT OPTIONS ** ;

read_parameters='y'         ; read parameters for individual glaciers / regions from file
reanalysis_direct='n'       ; Run model directly with re-analysis data, without downscaling of alternative series
hindcast_dynamic='n'        ; change glacier area during hindcast period AFTER date of RGI
write_file='y'              ; write results files?


; ** PARAMETERS ** ;

; ----- Temperature gradient
tgrad = 0.65
tgrad_obs = 'n'

; ----- accumulation model
dPdz = 1.5         ; [% per 100 m]   precipitation gradient
c_prec = 1.5       ; [-]  multiplication factor   correction factor
snow_multiplier = 1.2   ; [-] higher correction for snow falls
T_thres = 1.5        ; [deg C]  temperature threshold solid-liquid
no_incprec = [0.75,1000,2,2]   ; fraction of elevation range, crit elevation range
                             ; parameters of reduction function (ax^b)
; ----- melt model
meltmodel='1'     ; '1': conventional DDF-model; '2': Hock, 1999; '3': Oerlemans,2001
DDFsnow0 = 3
DDFice0 = 6
T_melt=0      ; [deg C]
; meltmodel 2 - enhanced DDF model (Hock, 1999)
Fm=1
r_ice=1
r_snow=0.5
; meltmodel 3 - Simple energy balance model (Oerlemans, 2001)
C0=-45
C1=10
alb_ice=0.3
alb_firn=0.5
alb_snow=0.7

; ------- supraglacial debris model
debris_supraglacial='n'
debris_pond_enhancementfactor=2         ; enhancement of bare-ice melt over pond/ice cliff fraction of band (no influence: 0)
debris_expansion='y'        ; spatial expansion of debris over time
debris_exp_gradient=2.0    ; [% a-1 frac-1] gradient of debris extension
debris_seed_bands=10       ; factor to scale decadal ELA-change into a number bands per year with new debris seed
debris_initialband=0.01    ; [m] thickness of debris in newly generated formed bands with no initial observations
debris_pond_gradient=0.1     ; [% a-1 frac-1] gradient of pond/cliff extension [not used anymore - now automated??]
debris_ponddens_max=0.1    ; [-] maximum density of ponds within band [not used anymore - now automated??]
debris_thickening='y'       ; thickening of debris over time
debris_thick_gradient=1.0  ; [cm a-1 km-1]  thickening linearly increasing from ELA towards glacier terminus
; ------- refreezing / englacial temperature model
refreezing_full='y'      ; parameters see below - no need to be calibrated
firnice_temperature='n'  ; compute firn/ice temperatures transiently (not just for refreezing)
firnice_write=['y','y']   ; output of overall (time series, annual) and detailed (profiles, monthly) files
firnice_batch='n'      ; run batch (all sites contained in icetemperature_batch.dat)
; only relevant if defined manually (firnice_runbatch='n' )
firnice_profile=[0.2,0.65,0.95]      ; (max 3.) manually inserting elevations of profiles to be written (<1: ratio of elev. range, >1: masl)
firnice_profile=[3000,3500,4000]
; ----- glacier retreat module
glacier_retreat='y'  ; activate glacier dynamics module
expon=2.             ; Parameter for valley shape regulating band area loss depending on thickness loss
dh_size=[5,20]       ; km2 Boundary between different empirical dh-parameterizations used (according to Huss et al., 2010)
redistribute_vplus='y'      ; (y/n) Redistribution of very negative/positive elevation changes at tongue over glacier?
                   ; is actually necessary, but the results are yet not very good ...
advance='y'        ; glacier advance possible
adv_addband0=10     ; number of added elevation bands
adv_calving=-100.   ; [m] default=0 (no calving), terminal elevation of glacier bed
adv_fcrit=2.       ; [m/a] Elevation gains above will be distributed
adv_terminusfraction=0.2   ; Use this fraction of elevation range to determine potential area in front of glacier
adv_lookup='n'             ; if glacier volume during positive years is smaller than initial volume, draw glacier geometry from a look-up table
; ----- calving
frontal_ablation='y'     ; consider volume loss due to calving
front_melt=1000       ; m/a      default frontal ablation (horizontal)   ; ******* Huss-calving model
calv_amplification=0.005 ; -     (0.005-0.02??) Amplification of frontal melt for very deep glaciers (faster flow ...)
calv_sep=1.25    ; [m w.e.] as threshold: separate calving flux into gl geom. change AND direct break off at terminus
bed_elev_term=-50     ; m        set back bedrock elevation for glaciers known to be calving
; ---------
oerlemans='y'     ; tidewater glacier model after Oerlemans and Nick, 2005   ; ******* Oerlemans-calving model
alpha_f=0.7
c_calving=2.4
regparams_readfromfile='y'
length_corrfact=1.4
ccorr_expon=2.5
crit_ccorrdist=3000.
bedrock_parabolacorr=0.2


; ** REGIONAL OPTIONS ** ;

lat0 = [-9999,-9999]
lat0 = [9999,9999]        ; run for entire region
lon0 = [0,0]        ; or specify sub-regions

grid_run = 'y'    ; search in a grid
grid_step = 0.08333333333333333333333333333333333333333    ; deg

outst = 10      ; [a] Interval of results output for compilation files

; ** OUTPUT ** ;

;plusdir=''
dircali=dirres
; reading calibration file for reference folder (specific) for regional run (hack, to be removed)
if calperiod_ID eq 5 then dircali='/scratch-second/mhuss/r6spec_global_results/'

; ** PLOTTING ** ;

plot='n'           ; plot single glacier profiles
elev_range_p=500   ; only for glaciers above this elevation range
areaplot='n'

; ** SECONDARY SETTINGS ** ;

mon_len=[31,28,31,30,31,30,31,31,30,31,30,31]
min_tempbias=-8   ; default: -9999  - restrict extreme temperature biases 
min_precbias=0.05 ; default: -9999  - restrict extreme precipitation biases
;loadct,4 & tek_color
noval=-9999
snoval=-99
rho=917.
Lh_rf=334000.*rho   ; [J m-3] latent heat of fusion
lhf=334000.          ; [J kg-1] latent heat of fusion
; declination of sun for all months (mid-month)
decl_sun=[-21.26,-13.50,-2.11,9.85,19.16,23.31,21.18,13.34,1.91,-10.03,-19.27,-23.32]
asp_class=[0,45,90,135,180]
; result file output
full_output='y'
if full_output eq 'y' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation','Discharge','Discharge_gl'$
 ,'Accumulation_day','Rain_day','Snowmelt_day','Icemelt_day','Refreezing_day','Snowline_day']
if full_output eq 'n' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation',$
 'Discharge','Discharge_gl','','','','','','']   ; reduced output - no monthly data
format_of=['f10.3','f10.4','f8.3','f8.3','f8.3','f8.3','f8.3','f8.3','i6','f7.1','f8.3','i6','f10.5','f8.2','f8.2','f8.2','f8.2','f8.2','f8.2','f9.4','i7']
write_mb_elevationbands = 'y'     ; write out seasonal mass balance in elevation bands for every glacier
eval_mbelevsensitivity = 'n'      ; evaluating mass balance sensitivity in each band to changing surface elevation
count_mbelevsens_v0 = 5              ; number of elevations computed
past_out = 'y'                 ; if files for PAST should be written to external folder (not files/)
write_hypsometry_files='n'   ; write out annual hypsometry for all glaciers


; only partially implemented for daily version and unsure whether it would
; actually work out...
variability_bias_longterm='n'                             ; include bias in GCM variability from month to month

if long_GCM ne '' then outf_names=['Area','Volume','Annual_Balance_sfc','Winter_balance_sfc','Icemelt_sfc',$
 'Snowmelt_sfc','Accumulation_sfc','Rain_sfc','ELA','AAR','Refreezing_sfc','Hmin','Frontal_ablation',$
 '','','','','','','']

; ** REFREEZING MODEL ** ;

rf_layers=8
rf_melcrit=0.02             ; [m w.e.] critical amount of melt for initialising refreezing module (0.002 earlier, what is better?)
dens_rf=[300,300,400,450,500,550,600,650]     ; approx. density of layers
rf_dz=1.                       ; layer thickness (m)
rf_dsc=3.                      ; increase in temporal resolution (num. stability of heat conduction)
rf_dt=3600.*24./rf_dsc         ; time step (1 day)

fit_layers=[10,10,10]          ; number of layers with given thickness (max. 260m in this setting) 
fit_dzstep=[1.,5.,20.]         ; layer thickness (m)
;fit_dzstep=[1.,1.,1.]         ; layer thickness (m)
fit_dens=[250,300,360,420,480,550,580,610,640,670,700,730,760,790,820,850,880,900]          ; reference density profile, shifted depending on snow/firn situation 
fact_permeability=[0.001,0.005]   ; scaling parameters for estimating glacier ice permeability (slope, thickness)
;fact_permeability=[0.0000,0.000]   ; scaling parameters for estimating glacier ice permeability (slope, thickness)

cice=1890000.    ; heat capacity of ice [J m-3]
cair=1297.       ; heat capacity of air
kice=2.33        ; conductivity ice [J s-1 K-1 m-1]
kair=0.001       ; conductivity air [J s-1 K-1 m-1]


end
