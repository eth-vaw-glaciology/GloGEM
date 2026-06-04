; *************************************************************
; read_climate_series
;
; Read the climate time series for the current evaluation cell.
;
; Selects the appropriate climate input path (reanalysis or GCM/RCP),
; prints a progress line for cells with more than 10 km2 of glacier
; area, and dispatches to the daily or monthly reading and downscaling
; routines. For daily resolution, reanalysis data are read for the past
; period and, unless reanalysis_direct is set, GCM data are read and
; bias-corrected for the future period. For monthly resolution,
; downscaling and gradient-variability adjustment are applied directly.
; *************************************************************

; climate series - read individual series for every evaluation cell!

if cg gt 0 then begin

  if calibrate eq 'n' then a=GCM_model[gcms]+'/'+GCM_rcp[rcps] else a='CALI - '+reanalysis
  if total(a_gl[gg]) gt 10. and gx mod 2 eq 0 and gy mod 2 eq 0 then $
  print, dir_region+' '+clim_subregion+' ('+a+'): '+string(mean(lat),fo='(f5.1)')+'/'+string(mean(lon),fo='(f6.1)')+$
  ', '+string(total(a_gl[gg]),fo='(i5)')+'km2 ('+string(cg,fo='(i4)')+')'

  ; SPLIT between DAILY climate data and MONTHLY climate data
  if time_resolution eq 'daily' then begin

    ; select reanalysis series from closest grid point
    rmid=[mean(lon),mean(lat)]
    gxs=strcompress(string(rmid[0],fo='(f7.2)'),/remove_all)
    gys=strcompress(string(rmid[1],fo='(f7.2)'),/remove_all)

    ; meteo time series read from re-analysis data (past)

    @procedures/read/read_climatepast_daily.pro

    ; meteo time series downscaled from GCMs or whatever (future)
    if reanalysis_direct eq 'n' then begin

      @procedures/read/read_gcmdata_daily.pro
      @procedures/processing/downscale_gcmdata_daily.pro

    endif

  endif    ; daily time resolution

  ; --- MONTHLY

  if time_resolution eq 'monthly' then begin

    gmid=[mean(latitudes),mean(longitudes)]
    @procedures/processing/downscale_gcmdata_monthly.pro
    @procedures/processing/gradient_variability_monthly.pro

  endif

endif                               ; is there a glacier in the cell?
