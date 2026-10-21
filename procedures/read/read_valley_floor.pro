; *************************************************************
; read_valley_floor
;
; Valley floor below each glacier of the region [m a.s.l.], for the snowline below the front
; (snowline_ext_valley): <snowline_ext_valley>/valley_floor_rgi<RGIversion>_<region>.dat, written by
; scripts/valley_floor.py. Columns: ID, valley floor, terrain height at the start, path length, end of path.
; *************************************************************

compile_opt idl2

vf_fn = snowline_ext_valley + '/valley_floor_rgi' + RGIversion + '_' + region + '.dat'
if ~file_test(vf_fn) then message, 'snowline_ext_valley: file not found: ' + vf_fn
vf_n = file_lines(vf_fn) - 1
vf_id = lonarr(vf_n > 1) & vf_z = dblarr(vf_n > 1) + noval
vf_s = ''
openr, vf_lun, vf_fn, /get_lun
readf, vf_lun, vf_s
for vf_i = 0l, vf_n - 1 do begin
  readf, vf_lun, vf_s
  vf_p = strsplit(vf_s, /extract)
  vf_id[vf_i] = long(vf_p[0]) & vf_z[vf_i] = double(vf_p[1])
endfor
free_lun, vf_lun
print, 'Valley floors of ' + strtrim(vf_n, 2) + ' glaciers: ' + vf_fn
