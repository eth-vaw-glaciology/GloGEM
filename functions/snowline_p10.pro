; *************************************************************
; snowline_p10
;
; Snow line as the 10th percentile of the elevation of the
; snow-covered glacier area, the statistic of the Alpine snow-line
; product of Sommer et al. (ESSD, essd-2026-35); a fully snow-covered
; glacier gives its own 10th-percentile elevation. Snow is spread
; evenly over each band's height range; a glacier without snow gives
; its top. noval if the glacier has no area.
; *************************************************************

FUNCTION snowline_p10, sno, gl, area, elev, step, noval

  compile_opt idl2

  ig = where(gl ne noval and area gt 0, cg)
  if cg eq 0 then return, noval
  js = where(sno gt 0 and gl ne noval and area gt 0, cs)
  if cs eq 0 then return, max(elev[ig]) + step / 2.

  ca = total(area[js], /cumulative) / total(area[js])
  k = (where(ca ge 0.1d))[0]
  if k gt 0 then ca0 = ca[k - 1] else ca0 = 0.d
  return, elev[js[k]] - step / 2. + step * (0.1d - ca0) / (ca[k] - ca0)

END
