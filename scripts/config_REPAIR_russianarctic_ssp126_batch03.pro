; REPAIR config -- fills the specific GCM gaps left in RussianArctic flow
; ssp126 batch03 (see status_scan.py sweep, 2026-08-18). Targets only the
; missing GCMs for this batch so we don't recompute GCMs that already
; finished. Writes into the same real output dir as the original run.
dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/russianarctic_flow_rgi7_gmip4/'
RGIversion = '7'

time_resolution = 'monthly'
region_id_loop  = [9, 9]

calibrate = 'n'

MIP           = 'GMIP4'
GCM_model_idx = [5,6,8]
GCM_rcp_idx   = [1]

refreezing_parametrised = 'y'
write_netcdf            = 'y'
use_flow_model = 'y'
_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'russianarctic_batch' + _batch $
else catchment_selection = ''
