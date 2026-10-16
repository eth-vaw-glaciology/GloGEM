; *************************************************************
; write_snowline_log
;
; After every pass of the snowline scan: progress, and the record of
; the scan per glacier, rewritten each pass, beside the calibration
; file: calibrate_m<m>_cID<id>_<sub_region><catchment>_snowline.dat
;
; Columns: ID; observations used; status (2 done, 1 final run pending,
; 0 scanning, -1 not calibrated here); values scanned; c_prec at the
; minimum; bound (-1 / +1: at the lowest / highest scanned value);
; RMSE of the final run [m]; RMSE at each scanned value [m] (-99: not run).
; *************************************************************

compile_opt idl2

snowcal_k = where(snowcal_id ne '', snowcal_n)
snowcal_left = 0l & snowcal_nok = 0l
if snowcal_n gt 0 then begin
  snowcal_left = long(total(snowcal_flag[snowcal_k] eq 0 or snowcal_flag[snowcal_k] eq 1))
  snowcal_nok = long(total(snowcal_flag[snowcal_k] ge 0))
endif
snowcal_finished = snowcal_left eq 0
print, '   Snowline calibration, pass ' + strtrim(snowcal_r + 1, 2) + ': ' + strtrim(snowcal_nok - snowcal_left, 2) + $
  ' of ' + strtrim(snowcal_nok, 2) + ' glaciers done'

if catchment_selection ne '' then snowcal_cc = '_' + catchment_selection else snowcal_cc = ''
snowcal_fn = dircali + '/' + time_resolution + '/' + dir_region + '/calibration/calibrate_m' + meltmodel + '_cID' + $
  string(calperiod_ID, fo = '(i1)') + '_' + sub_region + snowcal_cc + '_snowline.dat'
openw, snowcal_lun, snowcal_fn, /get_lun
snowcal_head = 'ID      Nobs Status Nscan CprecMin Bound  RMSEfinal'
for snowcal_i = 0, snowcal_nsc - 1 do $
  snowcal_head = snowcal_head + string(snowline_cprec_values[snowcal_i], fo = '(f10.2)')
printf, snowcal_lun, snowcal_head
for snowcal_i = 0l, snowcal_n - 1 do begin
  snowcal_g = snowcal_k[snowcal_i]
  snowcal_row = dblarr(snowcal_nsc) + snoval & snowcal_fin = snoval
  case snowcal_flag[snowcal_g] of
    -1: snowcal_m = 0
    0: snowcal_m = snowcal_r + 1
    else: snowcal_m = snowcal_nscan[snowcal_g]
  endcase
  if snowcal_m gt 0 then snowcal_row[0:snowcal_m - 1] = snowcal_rmse[snowcal_g, 0:snowcal_m - 1]
  if snowcal_flag[snowcal_g] eq 2 then snowcal_fin = snowcal_rmse[snowcal_g, snowcal_nscan[snowcal_g]]
  printf, snowcal_lun, snowcal_id[snowcal_g], snowcal_nobs[snowcal_g], snowcal_flag[snowcal_g], snowcal_nscan[snowcal_g], $
    snowcal_cmin[snowcal_g], snowcal_bound[snowcal_g], snowcal_fin, snowcal_row, $
    fo = '(a,i7,i7,i6,f9.4,i6,f11.3,' + strtrim(snowcal_nsc, 2) + 'f10.3)'
endfor
free_lun, snowcal_lun
