; REPAIR config v2 -- the first two attempts used GCM_model_idx=[5] intending
; MIROC6, but settings.pro's GMIP4 GCM_model array (verified directly from
; source, 2026-08-19) has MIROC6 at index 7, not 5 (index 5 is MRI-ESM2-0 --
; already-complete, so both prior attempts silently reran the wrong GCM with
; no error). This is the corrected version: GCM_model_idx=[7].
dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/russianarctic_flow_rgi7_gmip4/'
RGIversion = '7'

time_resolution = 'monthly'
region_id_loop  = [9, 9]

calibrate = 'n'

MIP           = 'GMIP4'
GCM_model_idx = [7]
GCM_rcp_idx   = [1]

refreezing_parametrised = 'y'
write_netcdf            = 'y'
use_flow_model = 'y'
_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'russianarctic_batch' + _batch $
else catchment_selection = ''
