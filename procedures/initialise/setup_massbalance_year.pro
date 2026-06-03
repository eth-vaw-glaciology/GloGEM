; *************************************************************
; setup_massbalance_year
;
; Define mass balance year thresholds and clean stale t_offset.
;
; Sets dd_thresholds and bal_month for the current region and
; time resolution. Southern Hemisphere / tropical regions use
; an April start instead of October. Also removes any pre-existing
; t_offset calibration file at the start of a new calibration run.
; *************************************************************

compile_opt idl2

if time_resolution eq 'daily' then dd_thresholds=[121,181,274,365] else dd_thresholds=[4,7,10,12]
bal_month=dd_thresholds[2]
if dir_region eq 'SouthernAndes' or dir_region eq 'Antarctic' or dir_region eq 'LowLatitudes' or dir_region eq 'NewZealand' then bal_month=dd_thresholds[0]

if calibrate eq 'y' then begin
  if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
  if rp_cali eq 0 then SPAWN, 'rm -f ' + dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+STRING(calperiod_ID,FORMAT='(I1)')+'_'+sub_region+cc+'.dat'
endif
