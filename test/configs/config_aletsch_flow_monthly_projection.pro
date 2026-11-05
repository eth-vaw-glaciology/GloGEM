; GloGEM test configuration — Aletsch / Morteratsch
; Optional step 7: monthly model, GCM projection to 2100 with the GloGEMflow
; flowline model instead of the Δh parameterisation.
;
; Run AFTER config_aletsch_monthly_calib.pro has completed (it reads that
; calibration from test/outputs/). It writes into the same folders as step 6
; and overwrites its .dat files; the netCDF files are named GloGEMflow_*.
;
;   cp test/configs/config_aletsch_flow_monthly_projection.pro config.pro
;   .r glogem
;
; The bundled ERA5 test data start in 1979, so the flow spin-up uses the
; years from tran[0] to the survey year as its reference climate instead of
; 1961-1990 (the run log says so).

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

; -----------------------------------------------------------------------
; RUN MODE
; -----------------------------------------------------------------------
tran            = [1991, 2100]   ; must end after 2025, or the flow model never runs
calibrate       = 'n'
read_parameters = 'y'

; -----------------------------------------------------------------------
; CLIMATE DATA — MODEL INTERCOMPARISON PROJECT
; -----------------------------------------------------------------------
; Only MRI-ESM2-0 ssp126 is bundled (see config_aletsch_monthly_projection.pro).
MIP = 'GMIP4'
GCM_model_idx = [5]   ; MRI-ESM2-0
GCM_rcp_idx   = [1]   ; ssp126

; -----------------------------------------------------------------------
; GEOMETRY CHANGE
; -----------------------------------------------------------------------
use_flow_model   = 'y'   ; GloGEMflow; glaciers it cannot use fall back to the Δh parameterisation
frontal_ablation = 'n'   ; land-terminating glaciers — calving does not apply
;write_geometry_output = 'y'   ; save the flowline geometry per glacier (.sav)
