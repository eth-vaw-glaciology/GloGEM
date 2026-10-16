; *************************************************************
; select_snowline_minimum
;
; After the last phase of a pass (calibrate_snowline = 'y'): weighted
; RMSE of the glacier's daily snow line against its observations, and
; the stopping rule of the scan (A. von der Esch). At the first rise
; of the RMSE, or at the last scanned value, a cubic spline through
; the RMSE of all values scanned so far gives c_prec at its minimum;
; the glacier is run once more there (next pass) and is then done.
; *************************************************************

compile_opt idl2

if snowcal_ran and cphl eq double(caliphase_loop) then begin
  snowcal_g = gg[g]
  snowcal_rmse[snowcal_g, snowcal_r] = compare_snowline_rmse(calisnow_gid, id[gg[g]], year_obs, doy_obs, $
    snowlineday_obs, snowline_stdev_obs, snowlineday, tran[0], start_doy = bal_month, n_used = snowcal_nu)
  if snowcal_nu ne snowcal_nobs[snowcal_g] then $
    message, 'snowline calibration: ' + id[gg[g]] + ' used ' + strtrim(snowcal_nu, 2) + ' of ' + $
    strtrim(snowcal_nobs[snowcal_g], 2) + ' observations'
  if snowcal_flag[snowcal_g] eq 1 then snowcal_flag[snowcal_g] = 2 else begin
    snowcal_x = reform(snowcal_cprec[snowcal_g, 0:snowcal_r])
    snowcal_y = reform(snowcal_rmse[snowcal_g, 0:snowcal_r])
    snowcal_rise = 0b
    if snowcal_r gt 0 then snowcal_rise = snowcal_y[snowcal_r] gt snowcal_y[snowcal_r - 1]
    if snowcal_rise or snowcal_r eq snowcal_nsc - 1 then begin
      if snowcal_r eq 0 then begin
        snowcal_xmin = snowcal_x[0] & snowcal_ymin = snowcal_y[0]
      endif else begin
        snowcal_spl = spl_init(snowcal_x, snowcal_y)
        snowcal_xf = findgen(1000) / 999.0 * (snowcal_x[snowcal_r] - snowcal_x[0]) + snowcal_x[0]
        snowcal_yf = spl_interp(snowcal_x, snowcal_y, snowcal_spl, snowcal_xf)
        snowcal_ymin = min(snowcal_yf, snowcal_imin)
        snowcal_xmin = snowcal_xf[snowcal_imin]
      endelse
      snowcal_cmin[snowcal_g] = snowcal_xmin
      if snowcal_xmin le snowline_cprec_values[0] then snowcal_bound[snowcal_g] = -1
      if snowcal_xmin ge snowline_cprec_values[snowcal_nsc - 1] then snowcal_bound[snowcal_g] = 1
      snowcal_cprec[snowcal_g, snowcal_r + 1:*] = snowcal_xmin
      snowcal_nscan[snowcal_g] = snowcal_r + 1
      snowcal_flag[snowcal_g] = 1
      print, '   Snowline minimum ' + id[gg[g]] + ': c_prec' + string(snowcal_xmin, fo = '(f6.3)') + $
        ', RMSE' + string(snowcal_ymin, fo = '(f7.1)') + ' m (' + strtrim(snowcal_r + 1, 2) + ' values)'
    endif
  endelse
endif
