; *************************************************************
; snowline_below_front
;
; Snowline [m a.s.l.] when no glacier band is snow-free (snowline_ext_depth > 0).
; Ground bands are the glacier's own bands below its lowest ice band (all its bands once it has no ice) and the
; ground bands of procedures/processing/snowline_extension.pro; bands below zmin (sea level, or the glacier's
; valley floor with snowline_ext_valley) are ignored. Returns the
; highest snow-free ground band, else the lowest ground band (the snowline is at or below it), else fallback when
; there is no ground band.
; *************************************************************

function snowline_below_front, sno, gl, elev, noval, sx_n, sx_sno, sx_elev, zmin, fallback
  compile_opt idl2
  ice = where(gl ne noval, n_ice)
  if n_ice gt 0 then n_dom = ice[0] else n_dom = n_elements(gl)
  z = [] & s = []
  if n_dom gt 0 then begin
    z = [z, reform(elev[0 : n_dom - 1], n_dom)] & s = [s, reform(sno[0 : n_dom - 1], n_dom)]
  endif
  if sx_n gt 0 then begin
    z = [z, reform(sx_elev, sx_n)] & s = [s, reform(sx_sno, sx_n)]
  endif
  if n_elements(z) eq 0 then return, fallback
  land = where(z ge zmin, n_land)
  if n_land eq 0 then return, fallback
  z = z[land] & s = s[land]
  free = where(s eq 0, n_free)
  if n_free gt 0 then return, max(z[free])
  return, min(z)
end
