; *************************************************************
; read_valley_floor
;
; Valley floor below each glacier of the region, for the snowline below the front (snowline_ext_valley):
; <snowline_ext_valley>/valley_floor_rgi<RGIversion>_<region>.dat, written by scripts/valley_floor.py.
; One header line, then per glacier: ID, valley floor [m], terrain height at the start [m], path length, end of path.
; Lines with fewer than three entries are skipped.
; *************************************************************

compile_opt idl2

vf_fn = snowline_ext_valley + '/valley_floor_rgi' + RGIversion + '_' + region + '.dat'
if ~file_test(vf_fn) then message, 'snowline_ext_valley: file not found: ' + vf_fn
vf_nl = file_lines(vf_fn)
vf_s = strarr(vf_nl > 1)
if vf_nl gt 0 then begin
  openr, vf_lun, vf_fn, /get_lun
  readf, vf_lun, vf_s
  free_lun, vf_lun
endif
vf_id = lonarr(vf_nl > 1) & vf_z = dblarr(vf_nl > 1) & vf_z0 = vf_z
vf_n = 0l
for vf_i = 1l, vf_nl - 1 do begin
  vf_p = strsplit(vf_s[vf_i], /extract, count=vf_c)
  if vf_c ge 3 then begin
    vf_id[vf_n] = long(vf_p[0]) & vf_z[vf_n] = double(vf_p[1]) & vf_z0[vf_n] = double(vf_p[2])
    vf_n++
  endif
endfor
print, 'Valley floors of ' + strtrim(vf_n, 2) + ' glaciers: ' + vf_fn
