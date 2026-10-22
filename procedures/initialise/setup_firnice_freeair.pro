; *************************************************************
; setup_firnice_freeair
;
; Free air of the thermal model (firnice_thermal_air = 'freeair'). Reads from firnice_freeair_file
; the table of the glacier's climate cell (clim_ilon, clim_ilat: the cell the mass balance uses):
; ERA5 pressure-level temperature at fixed heights, per month (make_freeair_table.py).
; Sets: fa_node[nh, nt] [C], fa_h0, fa_dh [m], fa_year[nt], fa_mon[nt], and fa_tix, the table
; month of each month of the run's climate series (temp, cyear, cmon).
; freeair_at(fa_node, fa_h0, fa_dh, elev, t) gives the free air at band elevations.
; *************************************************************

compile_opt idl2

if new eq 'y' then message, "firnice_thermal_air = 'freeair': only for the gridded (.mdi) climate files"
fa_lon = rlon[clim_ilon] & fa_lat = rlat[clim_ilat]
id_fa = ncdf_open(firnice_freeair_file)
ncdf_varget, id_fa, 'longitude', fa_lons
ncdf_varget, id_fa, 'latitude', fa_lats
ncdf_varget, id_fa, 'height', fa_hgt
ncdf_varget, id_fa, 'year', fa_year
ncdf_varget, id_fa, 'month', fa_mon
dlon_fa = min(abs(fa_lons - fa_lon), j_fa) & dlat_fa = min(abs(fa_lats - fa_lat), i_fa)
if dlon_fa gt 1d-3 or dlat_fa gt 1d-3 then begin
  ncdf_close, id_fa
  message, 'firnice_thermal_air: no free air for the climate cell ' + strtrim(fa_lon, 2) + ' E ' + $
           strtrim(fa_lat, 2) + ' N in ' + firnice_freeair_file
endif
nh_fa = n_elements(fa_hgt) & nt_fa = n_elements(fa_year)
ncdf_varget, id_fa, 'tfa', fa_node, offset = [0, 0, j_fa, i_fa], count = [nh_fa, nt_fa, 1, 1]
ncdf_close, id_fa
fa_node = double(reform(fa_node, nh_fa, nt_fa))
fa_h0 = double(fa_hgt[0]) & fa_dh = double(fa_hgt[1] - fa_hgt[0])
if max(abs((fa_hgt[1 : *] - fa_hgt[0 : -2]) - fa_dh)) gt 1d-6 then $
  message, 'firnice_thermal_air: the heights of ' + firnice_freeair_file + ' are not evenly spaced'
if max(abs((long(fa_year) - long(fa_year[0])) * 12 + long(fa_mon) - long(fa_mon[0]) - lindgen(nt_fa))) ne 0 then $
  message, 'firnice_thermal_air: the months of ' + firnice_freeair_file + ' are not consecutive'
fa_tix = (long(cyear) - long(fa_year[0])) * 12 + long(cmon) - long(fa_mon[0])
if min(fa_tix) lt 0 or max(fa_tix) ge nt_fa then $
  message, 'firnice_thermal_air: the run (' + strtrim(long(cyear[0]), 2) + '-' + strtrim(long(cyear[-1]), 2) + $
           ') reaches beyond the free air (' + strtrim(fa_year[0], 2) + '-' + strtrim(fa_year[-1], 2) + ')'
print, '  [free air] cell ' + strtrim(string(fa_lon, fo = '(f7.2)'), 2) + ' E ' + $
       strtrim(string(fa_lat, fo = '(f6.2)'), 2) + ' N, ' + strtrim(fa_year[0], 2) + '-' + $
       strtrim(fa_year[-1], 2) + ', ' + strtrim(round(fa_h0), 2) + '-' + strtrim(round(fa_hgt[-1]), 2) + ' m'
