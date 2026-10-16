; *************************************************************
; compare_snowline_rmse
;
; Weighted RMSE between the modelled daily snow line of one glacier
; and its observed snow lines (A. von der Esch,
; snowline_calibration/compare_snowline_rmse.pro); weights 1/stdev.
;
; Day 0 of snowlineday is day start_doy of year-1 (the start of the
; first mass-balance year, 274 = 1 October); 365-day calendar.
; Observations outside the modelled days are not used; their number
; is returned in n_used.
; *************************************************************

FUNCTION compare_snowline_rmse, calisnow_gid, id_glac, year_obs, doy_obs, snowlineday_obs, snowline_stdev_obs, $
  snowlineday, year, START_DOY = start_doy, N_USED = n_used, RMSE_UNWEIGHTED = rmse_unweighted

  compile_opt idl2

  if n_elements(start_doy) eq 0 then start_doy = 274
  n_used = 0l
  rmse_unweighted = !values.d_nan

  idx = where(calisnow_gid eq id_glac, count)
  if count eq 0 then return, !values.d_nan

  day_index = 365l * (long(year_obs[idx]) - long(year) + 1) + long(doy_obs[idx]) - long(start_doy)
  ok = where(day_index ge 0 and day_index lt n_elements(snowlineday), n_used)
  if n_used eq 0 then return, !values.d_nan

  observed = snowlineday_obs[idx[ok]]
  observed_std = snowline_stdev_obs[idx[ok]]
  predicted = snowlineday[day_index[ok]]

  squared_errors = (observed - predicted) ^ 2
  rmse_unweighted = sqrt(total(squared_errors) / n_used)

  weights = 1.0 / observed_std
  rmse = sqrt(total(squared_errors * weights) / total(weights))
  return, rmse

END
