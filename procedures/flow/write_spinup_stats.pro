; -----------------------------------------------------------------------
; Append one row of spin-up calibration statistics to the run CSV.
;
; Called from spinup_flowmodel.pro at the end of STEP 5.
; All variables are inherited from the GloGEM/spinup scope.
;
; Output: <base_dir>/logs/spinup_stats.csv
;   Header is written only when the file does not yet exist, so
;   successive glacier runs accumulate in a single file per session.
; -----------------------------------------------------------------------
compile_opt idl2

spinup_stats_file = dircali + '/' + time_resolution + '/' + dir_region + '/calibration/flow_spinup_stats.dat'
spinup_stats_new  = ~file_test(spinup_stats_file)
openw, _stats_lun, spinup_stats_file, /get_lun, /append
if spinup_stats_new then $
  printf, _stats_lun, $
    'glacier_id,region,reanalysis,survey_year,' + $
    'ela_bias_m,aflow_pa3yr,aflow_min_pa3yr,aflow_max_pa3yr,' + $
    'vol_target_km3,vol_final_km3,vol_error_pct,' + $
    'len_obs_km,len_final_km,len_error_pct,' + $
    'final_area_km2,max_thick_m,' + $
    'len_converged,n_len_iter,phase_b_years,spinup_time_s'
_aflow_explored = spinup_len_tbl[0:n_len_done-1, 2]
_len_err = obs_len_m gt 0d0 ? $
  (double(c_fin)*dx - obs_len_m) / obs_len_m * 100d0 : 0d0
printf, _stats_lun, $
  id[gg[g]] + ',' + region + ',' + reanalysis + ',' + $
  strtrim(tran[0]+ye-1, 2) + ',' + $
  strtrim(string(spinup_ela_bias,      fo='(f9.3)'),  2) + ',' + $
  strtrim(string(spinup_aflow,         fo='(e13.6)'), 2) + ',' + $
  strtrim(string(min(_aflow_explored), fo='(e13.6)'), 2) + ',' + $
  strtrim(string(max(_aflow_explored), fo='(e13.6)'), 2) + ',' + $
  strtrim(string(vol_target/1d9,       fo='(f10.6)'), 2) + ',' + $
  strtrim(string(final_vol/1d9,        fo='(f10.6)'), 2) + ',' + $
  strtrim(string((final_vol-vol_target)/vol_target*100d0, fo='(f8.4)'), 2) + ',' + $
  strtrim(string(obs_len_m/1000d0,     fo='(f8.4)'), 2) + ',' + $
  strtrim(string(double(c_fin)*dx/1000d0, fo='(f8.4)'), 2) + ',' + $
  strtrim(string(_len_err,             fo='(f8.4)'), 2) + ',' + $
  strtrim(string(final_area,           fo='(f8.4)'), 2) + ',' + $
  strtrim(string(max(thick_dx),        fo='(f7.2)'), 2) + ',' + $
  strtrim(len_converged, 2) + ',' + $
  strtrim(n_len_done,    2) + ',' + $
  strtrim(hist_n,        2) + ',' + $
  strtrim(string(systime(1)-spinup_t0, fo='(f8.2)'), 2)
free_lun, _stats_lun
