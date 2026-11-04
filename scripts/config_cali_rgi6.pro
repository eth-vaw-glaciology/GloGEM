; GloGEM config — RGI6 calibration
; Managed by run_rgi6_repair.sh — do not edit while script is running.

dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/alps_dhdt_rgi6/'
RGIversion = '6'

time_resolution = 'monthly'
region_id_loop  = [14, 14]

calibrate = 'y'

refreezing_parametrised = 'y'

_batch = getenv('GLOGEM_BATCH')
if _batch ne '' then catchment_selection = 'alps_batch' + _batch $
else catchment_selection = ''
