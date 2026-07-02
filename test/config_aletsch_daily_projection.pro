; GloGEM test configuration — Aletsch / Morteratsch
; Step 5 of 6: daily model, GCM projection to 2100
;
; Run AFTER config_aletsch_daily_calib.pro has completed.
;
;   cp test/config_aletsch_daily_projection.pro config.pro
;   .r glogem

; -----------------------------------------------------------------------
; OUTPUT DIRECTORY
; -----------------------------------------------------------------------
dirres = base_dir + '/test/outputs/'

; -----------------------------------------------------------------------
; TEST DATA PATHS
; -----------------------------------------------------------------------
main_dir = base_dir + '/test/'
dir      = base_dir + '/test/data/'
dir_clim = base_dir + '/test/climatedata/'

; -----------------------------------------------------------------------
; RGI VERSION
; -----------------------------------------------------------------------
RGIversion = '7'

; -----------------------------------------------------------------------
; TIME RESOLUTION
; -----------------------------------------------------------------------
time_resolution = 'daily'

; -----------------------------------------------------------------------
; RUN SELECTION
; -----------------------------------------------------------------------
region_id_loop      = [14, 14]
catchment_selection = 'Aletsch_Morteratsch'
;single_glacier = ''
;size_range = [0.002, 100000]

; -----------------------------------------------------------------------
; RUN MODE
; -----------------------------------------------------------------------
tran            = [1991, 2100]
calibrate       = 'n'
read_parameters = 'y'
;find_startyear = 'y'

; -----------------------------------------------------------------------
; CALIBRATION SETTINGS
; -----------------------------------------------------------------------
;calperiod_ID = 9
;caliphase_loop = 3
;calibration_phase = '1'

; -----------------------------------------------------------------------
; CLIMATE DATA — MODEL INTERCOMPARISON PROJECT
; -----------------------------------------------------------------------
; GlacierMIP4 fixed protocol, one model / one SSP (bundled test data only
; covers this single combination — do not change without adding the
; corresponding clim_<lon>_<lat>.dat files under test/climatedata/future/).
MIP = 'GMIP4'
GCM_model_idx = [5]   ; MRI-ESM2-0
GCM_rcp_idx   = [1]   ; ssp126

; -----------------------------------------------------------------------
; REANALYSIS / BIAS CORRECTION
; -----------------------------------------------------------------------
;reanalysis = 'era5'
;bias_correction = 'y'
;bias_correction_method = 1

; -----------------------------------------------------------------------
; MELT MODEL
; -----------------------------------------------------------------------
;meltmodel = '1'

; -----------------------------------------------------------------------
; MODEL PHYSICS (enable / disable modules)
; -----------------------------------------------------------------------
;debris_supraglacial    = 'n'
;refreezing_full        = 'n'
;refreezing_parametrised = 'y'
;firnice_temperature    = 'n'
glacier_retreat  = 'y'   ; enabled — bundled hypsometry already has thickness/width/length per band
frontal_ablation = 'n'   ; land-terminating glaciers — calving does not apply

; -----------------------------------------------------------------------
; OUTPUT OPTIONS
; -----------------------------------------------------------------------
;version_past = ''
;full_output = 'n'
;write_file = 'y'
;write_mb_elevationbands = 'n'
write_hypsometry_files = 'y'   ; per-decade area/volume per elevation band, for the profile plot
