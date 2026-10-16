FUNCTION compare_snowline_rmse, calisnow_gid, id_glac, year_obs, doy_obs, snowlineday_obs, snowline_stdev_obs, snowlineday, year

  COMPILE_OPT IDL2

  ;*******************************************
  ; Get unique glacier IDs
  ;*******************************************
  unique_ids = uniq(calisnow_gid) ; Gives  the indices where each new, unique value first appears in the array calisnow_gid
  num_glaciers = n_elements(unique_ids) ; it's counting how many unique glacier IDs there are

  ; Prepare output arrays
  glacier_ids = calisnow_gid[unique_ids]
  rmse_values = dblarr(num_glaciers)

  ;********************************************
  ; Select unique data
  ;********************************************
  
  ; Find all entries for this glacier ID
  idx = where(calisnow_gid EQ id_glac, count) ;calisnow_gid contains all glacier IDs (with possible repeats). where(... EQ this_id) finds the indices in the full data where this glacier appears. count tells you how many rows matched.

  ; Compute the index in the snowcover array
  day_index = 365 * (year_obs[idx] - year) + doy_obs[idx] + 365 - 274
    
  ; Ensure all indices are within bounds, Avoids trying to access out-of-bounds indices in snowcover_percentage.
  observed = snowlineday_obs[idx] ; change to snowcover if needed - for test with Aletsch, Findelen
  observed_std = snowline_stdev_obs[idx] ; change to snowcover if needed - for test with Aletsch, Findelen
  predicted = snowlineday[day_index]
  
  ;*** RMSE
  squared_errors = (observed - predicted)^2
  weighted_rmse = sqrt(total(squared_errors) / n_elements(squared_errors))
  ;rmse = sqrt(total(squared_errors) / n_elements(squared_errors))
  
  ;*** Weighted RMSE using Stddevs
  ; Compute weights as inverse variance
  weights = 1.0 / observed_std 
  ; Weighted sum of squared errors
  weighted_error_sum = total(squared_errors * weights)
  ; Sum of weights
  weight_sum = total(weights)
  ; Weighted RMSE
  ;weighted_rmse = sqrt(weighted_error_sum / weight_sum)
  rmse = sqrt(weighted_error_sum / weight_sum)
  ; Return a structure with results
  RETURN, rmse

END
