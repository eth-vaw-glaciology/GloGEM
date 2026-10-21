; *************************************************************
; initialise_snowline_extension
;
; Ground bands for the snowline below the glacier front (snowline_ext_depth).
; 10 m bands continue below the lowest band of the glacier, down to snowline_ext_depth below the inventory front
; (bands already below the front, e.g. advance bands, count), not below the glacier's valley floor when
; snowline_ext_valley is set, and not below sea level. They carry only a snow
; pack (procedures/processing/snowline_extension.pro), which starts at zero. Their precipitation is that of the
; inventory front (sx_zp: the elevation used for precipitation).
; *************************************************************

compile_opt idl2

sx_ii = where(gl ne noval, sx_ci)
if sx_ci gt 0 then sx_if = sx_ii[0] else sx_if = 0l
sx_n = round(snowline_ext_depth / 10.)
sx_zmin = 0d   ; lowest ground band the snowline may use (functions/snowline_below_front.pro)
; not below the glacier's own valley floor (read_valley_floor.pro); glaciers not in the file keep the depth
if snowline_ext_valley ne '' then begin
  sx_k = where(vf_id eq long(id[gg[g]]), sx_ck)
  if sx_ck gt 0 then begin
    sx_n = sx_n < (long(floor((elev0[sx_if] - vf_z[sx_k[0]]) / 10.)) > 0)
    sx_zmin = sx_zmin > vf_z[sx_k[0]]
  endif
endif
sx_n = sx_n - sx_if
sx_n = sx_n < long(floor((min(elev0) - 5.) / 10.))
sx_n = sx_n > 0
sx_ye = 0l & sx_sno = 0d & sx_elev = 0d
if sx_n gt 0 then begin
  sx_elev = min(elev0) - 10. * (sx_n - findgen(sx_n)) ; lowest band first, as elev
  sx_zp = sx_elev * 0 + elev0[sx_if]
  sx_sno = dblarr(sx_n) & sx_sur = sx_sno & sx_snostor = sx_sno
endif
