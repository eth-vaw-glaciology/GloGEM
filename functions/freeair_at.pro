; *************************************************************
; freeair_at
;
; Free-air temperature [C] at the elevations elev for month t of one grid cell's table
; fa[nh, nt] (heights h0, h0+dh, ...; setup_firnice_freeair.pro): linear in height,
; held at the table's ends.
; *************************************************************
function freeair_at, fa, h0, dh, elev, t
  compile_opt idl2
  nh = (size(fa, /dimensions))[0]
  x = (((elev - h0) / dh) > 0d) < (nh - 1d)
  k = long(x) < (nh - 2)
  w = x - k
  return, fa[k, t] * (1d - w) + fa[k + 1, t] * w
end
