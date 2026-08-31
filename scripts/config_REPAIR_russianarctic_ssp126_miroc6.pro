; REPAIR config -- MIROC6 output for RussianArctic flow ssp126 batches
; 01,02,03,05,06 came back 0-byte/missing despite "FINISHED region" firing
; the correct number of times in the first repair pass (2026-08-18) -- the
; same intermittent NFS/NCDF_CREATE write failure seen elsewhere this
; session. Relaunching just MIROC6 after cleaning the stale files.
dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/russianarctic_flow_rgi7_gmip4/'
RGIversion = '7'

time_resolution = 'monthly'
region_id_loop  = [9, 9]

calibrate = 'n'

MIP           = 'GMIP4'
GCM_model_idx = [5]
GCM_rcp_idx   = [1]

refreezing_parametrised = 'y'
write_netcdf            = 'y'
use_flow_model = 'y'
_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'russianarctic_batch' + _batch $
else catchment_selection = ''
