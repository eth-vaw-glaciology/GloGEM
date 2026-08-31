; REPAIR -- CentralAsia ssp126 stalled uniformly at 3/8 GCMs across all 24
; batches (root cause: /home quota pressure hung the watcher + likely killed
; the batch processes simultaneously, 2026-08-28 evening). Relaunching the
; remaining 5 GCMs: IPSL-CM6A-LR(4), MRI-ESM2-0(5), MPI-ESM1-2-HR(6), MIROC6(7), NorESM2-MM(8).
dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/centralasia_flow_rgi7_gmip4/'
RGIversion = '7'
time_resolution = 'monthly'
region_id_loop  = [16, 16]
calibrate = 'n'
MIP           = 'GMIP4'
GCM_model_idx = [4,5,6,7,8]
GCM_rcp_idx   = [1]
refreezing_parametrised = 'y'
write_netcdf            = 'y'
use_flow_model = 'y'
_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'centralasiaN_batch' + _batch $
else catchment_selection = ''
