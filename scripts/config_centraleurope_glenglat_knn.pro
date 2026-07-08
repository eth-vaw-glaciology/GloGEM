; GloGEM config — CentralEurope glenglat test: k-NN residual-corrected firn/ice
; temperature calibration ("Run G", following on from Run D "CentralEurope_glenglat_calib"
; in 04_firnicetemp_validation.ipynb, which tested the 2D transfer model dT_scale x Z0).
;
; This run adds the new 3D (perm_frac, dT_scale, z0) transfer model PLUS the spatial k-NN
; residual correction (05_firnicetemp_calibration.ipynb, ce-knn cell) on the 16-glacier
; RGI11_CentralEurope_glenglat catchment: the 6 directly calibrated glenglat glaciers
; (Jungfraufirn, Vadret dal Corvatsch, Gornergletscher, Glacier de Tete Rousse,
; Grenzgletscher, Glacier des Bossons) plus 10 nearby k-NN-assigned neighbours.
;
; Uses the default production data paths (main_dir/dir/dir_clim from settings.pro, NOT the
; repo's test/ sandbox) since the full RGI7 CentralEurope geometry/climate/MB-calibration
; already exists there for all ~4079 glaciers. Mass-balance calibration is reused (copied)
; from the existing CentralEurope_glenglat_calib run rather than re-calibrated.
;
; To launch (from the GloGEM/ directory):
;   cp scripts/config_centraleurope_glenglat_knn.pro config.pro
;   echo '.r glogem' | idl
;
; NOTE: this OVERWRITES config.pro. Back up / note your current config.pro first if you
; want to restore it afterward — config.pro is otherwise left as whatever it was.

dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/CentralEurope_glenglat_knn/'
RGIversion = '7'

time_resolution = 'monthly'
region_id_loop      = [14, 14]
catchment_selection = 'CentralEurope_glenglat'

tran            = [1991, 2020]
calibrate       = 'n'
read_parameters = 'y'

refreezing_parametrised = 'y'
glacier_retreat  = 'n'   ; fixed geometry — isolate the firn/ice temperature module
use_flow_model   = 'n'
frontal_ablation = 'n'   ; none of these 16 glaciers calve

; Explicitly pinned even where it matches the settings.pro default: `.r glogem` re-runs
; in the SAME IDL session do not reset variables this config doesn't mention — they keep
; whatever value a PREVIOUS run in this session left them at (this bit us once already,
; see firnice_glenglat_lookup below). Pin everything this run's physics depends on.
firnice_batch           = 'n'
firnice_thermal_spinup  = 'n'
enable_advection        = 'n'
enable_strain_heating   = 'n'

; --- firn/ice temperature module: k-NN residual-corrected transfer model -----------------
firnice_temperature         = 'y'
firnice_temp_calib          = 'y'
firnice_temp_calib_file     = ''   ; ensure the OLD flat-override mechanism is off —
                                    ; combining it with the knn residual file double-applies
firnice_temp_calib_knn_file = '/home/jabeer/projects/glogemflow_development/GloGEM/test/data/firnicetemp_calibration_CentralEurope_knn_residual.dat'

; Write IDX profile output at the real glenglat borehole elevations (covers all 16
; catchment glaciers) instead of generic fractional positions — directly comparable
; to observations. Explicitly set (even though settings.pro defaults to '') because
; `.r glogem` re-runs in the same IDL session don't reset variables config.pro doesn't
; touch — a stale non-empty value from an earlier run otherwise crashes
; setup_firnice_profile_from_glenglat.pro with "OPENR: Null filename not allowed".
firnice_glenglat_lookup = '/home/jabeer/projects/glogemflow_development/GloGEM/test/data/glenglat_borehole_elevations_CentralEurope.dat'
