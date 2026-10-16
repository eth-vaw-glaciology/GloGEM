; *************************************************************
; initialise_snowline_calibration
;
; Start of a snowline calibration (calibrate_snowline = 'y'), once
; per region: reads the observed snow lines and sets up the record
; of the c_prec scan, one entry per inventory glacier (index gg[g]).
;
; snowcal_flag: -1 not calibrated here (no observations in the
; modelled period, or no hypsometry), 0 scanning, 1 minimum found
; (final run at it next pass), 2 done.
; *************************************************************

compile_opt idl2

if snowline_dataset ne '' then fn_snow = snowline_dataset else begin
  snowcal_k = where(dir_region eq region_loop_data[2, *])
  fn_snow = dir + 'snowline/snowline_' + calibrate_glacierspecific_period + '/' + $
    strcompress(region_loop_data[1, snowcal_k[0]], /remove_all) + '_snowline_median.dat'
endelse
read_snowlinedata, fn_snow, calisnow_gid, year_obs, doy_obs, snowlineday_obs, snowline_stdev_obs

snowcal_nid = n_elements(id)
snowcal_nsc = n_elements(snowline_cprec_values)
snowcal_id = strarr(snowcal_nid)
snowcal_flag = intarr(snowcal_nid)
snowcal_nobs = lonarr(snowcal_nid)
snowcal_nscan = intarr(snowcal_nid)
snowcal_bound = intarr(snowcal_nid) ; -1 / +1: minimum at the lowest / highest scanned value
snowcal_cmin = dblarr(snowcal_nid) + snoval
snowcal_cprec = dblarr(snowcal_nid, snowcal_npass)
for snowcal_k = 0, snowcal_nsc - 1 do snowcal_cprec[*, snowcal_k] = snowline_cprec_values[snowcal_k]
snowcal_rmse = dblarr(snowcal_nid, snowcal_npass) + snoval

; last run of every glacier, written again in the passes after it is done
snowcal_ny = long(cran[1] - cran[0] + 1)
snowcal_st_ann = dblarr(snowcal_nid, 6, snowcal_ny) ; mb, wb, ela, aar, dbdz, btongue
snowcal_st_par = dblarr(snowcal_nid, 7) ; area1, DDFsnow, DDFice, c_prec, t_offset, flag, ccj

toff_grid = 'n'

snowcal_k = where(volume_ini gt 0, snowcal_n) & snowcal_nwith = 0
for snowcal_i = 0l, snowcal_n - 1 do $
  if total(calisnow_gid eq id[snowcal_k[snowcal_i]]) gt 0 then snowcal_nwith = snowcal_nwith + 1
if snowcal_nwith eq 0 then message, 'snowline calibration: no glacier of the inventory has observations in ' + fn_snow
print, '   Snowline calibration: ' + strtrim(snowcal_nsc, 2) + ' values of c_prec (' + $
  string(snowline_cprec_values[0], fo = '(f4.2)') + '-' + string(snowline_cprec_values[snowcal_nsc - 1], fo = '(f4.2)') + $
  '), observations for ' + strtrim(snowcal_nwith, 2) + ' inventory glaciers in ' + fn_snow
