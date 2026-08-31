; GloGEM config — Aletsch/Morteratsch paired advection experiment, WITHOUT advection.
;
; Purpose: produce the full englacial temperature field T(band, layer) needed for the
; advection-on vs advection-off glacier cross-section figure (GGMW2026 talk, slide 7).
; The four temp_{1m,10m,50m,bedrock} files only sample 4 fixed depths and store the annual
; MAXIMUM; the new firnice_write[2]='y' output (temp_field_<id>.dat) stores the annual MEAN
; of the whole 30-layer column, which is what a cross-section needs.
;
; Companion (advection ON):  scripts/config_icetemp_advfield_aletsch.pro
; Launch both:                bash scripts/run_icetemp_advfield_pair.sh
;
; Matches the earlier paired run in icetemp_test_aletsch_morteratsch/ (BCC-CSM2-MR, ssp126,
; 1940-2100, RGI7, flow model on) so the two are directly comparable. Mass-balance
; calibration is copied from that run by the launch script rather than recomputed.
;
; Glacier IDs in this catchment (RGI7, verified against test/geometricdata/rgiv7/files/
; thick_centraleurope.dat): 02596 = Great Aletsch (90.09 km2), 02216 = Morteratsch
; (18.61 km2). Note these are the reverse of what the directory name suggests.
;
; This file is loaded via the GLOGEM_CONFIG environment variable, so it never touches
; config.pro (which is managed by overnight_chain.sh for the GMIP4 runs).

dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_advfield_aletsch_morteratsch/no_adv/'
RGIversion = '7'

time_resolution     = 'monthly'
region_id_loop      = [14, 14]
catchment_selection = 'Aletsch_Morteratsch'

tran            = [1940, 2100]
calibrate       = 'n'
read_parameters = 'y'

MIP           = 'CMIP6'
GCM_model_idx = [1]   ; BCC-CSM2-MR
GCM_rcp_idx   = [1]   ; ssp126

refreezing_parametrised = 'y'
frontal_ablation        = 'n'   ; neither glacier calves

; --- geometry evolution: coupled SIA flowline (GloGEMflow) --------------------------------
use_flow_model = 'y'

; Required for the cross-section figure: writes flowgrid_<id>_flow.sav (dist_dx, sur,
; thick, bed_dx per year), which is the only place the flowline geometry is persisted.
; Defaults to 'n' in settings.pro, so without this the run produces temperatures with
; nothing to drape them on.
write_geometry_output = 'y'

; Everything this run's physics depends on is pinned explicitly: `.r glogem` re-runs in the
; SAME IDL session do not reset variables a config does not mention, so an unpinned flag
; silently keeps whatever a previous run in that session left it at.
firnice_temperature     = 'y'
firnice_write           = ['y', 'y', 'y']  ; [time series, ID profiles, full T(band,layer) field]
firnice_batch           = 'n'
firnice_thermal_spinup  = 'n'
firnice_temp_calib      = 'n'

; Must be a real, readable path. glogem.pro guards this with
;   if firnice_glenglat_lookup ne '' then $
;   @procedures/initialise/setup_firnice_profile_from_glenglat.pro
; but `@` is a COMPILE-TIME textual include, so the `then $` only guards that file's first
; line (`compile_opt idl2`) -- its `openr, 77, firnice_glenglat_lookup` runs unconditionally
; and aborts the run with "OPENR: Null filename not allowed" when the path is ''.
; Pointing it at the real lookup also gives ID profiles at the actual borehole elevations:
; 4 for Aletsch (02596), 1 for Morteratsch (02216), so units 51..54 -- clear of the
; advection units 70/71 that a >=21-borehole glacier would collide with.
firnice_glenglat_lookup = '/home/jabeer/projects/glogemflow_development/GloGEM/test/data/glenglat_borehole_elevations_CentralEurope.dat'
enable_strain_heating   = 'n'

enable_advection = 'n'
advection_write  = 'n'
