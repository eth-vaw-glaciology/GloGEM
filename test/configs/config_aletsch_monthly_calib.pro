; GloGEM test configuration — Aletsch / Morteratsch
; Step 3 of 6: monthly model, calibration
;
;   cp test/configs/config_aletsch_monthly_calib.pro config.pro
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
time_resolution = 'monthly'

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
tran      = [1991, 2020]
calibrate = 'y'
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
;MIP = 'CMIP6'
;GCM_model_idx = [0]
;GCM_rcp_idx   = [0]

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
glacier_retreat  = 'n'
frontal_ablation = 'n'

; -----------------------------------------------------------------------
; OUTPUT OPTIONS
; -----------------------------------------------------------------------
;version_past = ''
;full_output = 'n'
;write_file = 'y'
;write_mb_elevationbands = 'n'
;write_hypsometry_files = 'n'
