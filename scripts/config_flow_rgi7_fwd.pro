; GloGEM config — RGI7 GloGEMflow forward run
; Managed by overnight_chain.sh — do not edit while chain is running.

dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/alps_flow_rgi7/'
RGIversion = '7'

time_resolution = 'monthly'
region_id_loop  = [14, 14]

calibrate = 'n'

GCM_model_idx = [0]
GCM_rcp_idx   = [1,2,4]

refreezing_parametrised = 'y'
use_flow_model = 'y'

_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'alps_batch' + _batch $
else catchment_selection = ''
