; *************************************************************
; setup_firnice_daily_anomalies
;
; Each month's real daily anomalies of the climate cell (clim_ilon, clim_ilat) for the thermal melt
; (firnice_daily_anomalies; glogemflow_icetemp make_daily_anomalies.py): the day's air minus its
; month's mean, per month of 1940-2025. Called once per cell, after read_climate_series.pro.
; Sets: da_node[31, nt] [C] (NaN after a month's last day), da_year[nt], da_mon[nt], da_tix
; (the table month of each month of the run's climate series: temp, cyear, cmon) and da_ref = 0b.
; *************************************************************

compile_opt idl2

if new eq 'y' then message, 'firnice_daily_anomalies: only for the gridded (.mdi) climate files'
da_lon = rlon[clim_ilon] & da_lat = rlat[clim_ilat]
id_da = ncdf_open(firnice_daily_anomalies)
ncdf_varget, id_da, 'cell_lon', da_lons
ncdf_varget, id_da, 'cell_lat', da_lats
ncdf_varget, id_da, 'year', da_year
ncdf_varget, id_da, 'month', da_mon
ic_da = where(abs(da_lons - da_lon) lt 1d-3 and abs(da_lats - da_lat) lt 1d-3, c_da)
if c_da ne 1 then begin
  ncdf_close, id_da
  message, 'firnice_daily_anomalies: no series for the climate cell ' + strtrim(da_lon, 2) + ' E ' + $
           strtrim(da_lat, 2) + ' N in ' + firnice_daily_anomalies
endif
nt_da = n_elements(da_year)
ncdf_varget, id_da, 'anom', da_node, offset = [0, 0, ic_da[0]], count = [31, nt_da, 1]
ncdf_close, id_da
da_node = double(reform(da_node, 31, nt_da))
if max(abs((long(da_year) - long(da_year[0])) * 12 + long(da_mon) - long(da_mon[0]) - lindgen(nt_da))) ne 0 then $
  message, 'firnice_daily_anomalies: the months of ' + firnice_daily_anomalies + ' are not consecutive'
da_tix = (long(cyear) - long(da_year[0])) * 12 + long(cmon) - long(da_mon[0])
jda = where(da_tix lt 0 or da_tix ge nt_da, cda)
if cda gt 0 then $
  message, 'firnice_daily_anomalies: the run reaches ' + strtrim(long(cyear[jda[0]]), 2) + '-' + $
           strtrim(long(cmon[jda[0]]), 2) + ', beyond the file (' + strtrim(da_year[0], 2) + '-' + $
           strtrim(da_year[-1], 2) + ')'
da_ref = 0b
print, '  [daily anomalies] cell ' + strtrim(string(da_lon, fo = '(f7.2)'), 2) + ' E ' + $
       strtrim(string(da_lat, fo = '(f6.2)'), 2) + ' N, ' + strtrim(da_year[0], 2) + '-' + strtrim(da_year[-1], 2)
