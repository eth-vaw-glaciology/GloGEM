; *************************************************************
; freeair_blend
;
; Band air of air_temperature = 'freeair' [C]: the free air fa above the climate cell's ground hclim;
; below it (1 - w) * fa + w * t2 with w = (hclim - elev) / depth in [0, 1], t2 the 2 m air of the cell
; carried to elev with the lapse rate (freeair_blend_depth; plan Step 2, 28 Oct 2026).
; *************************************************************
function freeair_blend, fa, t2, elev, hclim, depth
  compile_opt idl2
  w = (((hclim - elev) / depth) > 0d) < 1d
  return, fa * (1d - w) + t2 * w
end
