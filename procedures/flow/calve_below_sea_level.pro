; -----------------------------------------------------------------------
; calve_below_sea_level
;
; Flowline ice at the front whose surface (bed + thickness) is below 0 m
; is removed, as the Δh parameterisation removes its bands below sea level
; (glacier_retreat.pro): every ice cell in front of the lowest ice cell
; whose surface is at or above 0 m. Ice below sea level further up the
; flowline, behind ice that reaches above sea level, stays.
;
; In : thick_dx, bed_dx, width_base_dx, lambda_dx, dx, xnum
; Out: thick_dx with those cells ice-free, fc_vol (m3 ice removed),
;      fc_n (cells removed). sur_dx and the widths are not updated here.
; -----------------------------------------------------------------------
compile_opt idl2

fc_vol = 0d0 & fc_n = 0l
fc_up = where(thick_dx gt 0d0 and bed_dx + thick_dx ge 0d0, fc_c)
fc_k = fc_c gt 0 ? fc_up[0] : xnum
if fc_k gt 0 then begin
  fc_j = where(thick_dx[0:fc_k-1] gt 0d0, fc_n)
  if fc_n gt 0 then begin
    ; trapezoid cross-section H*(w_base + lambda*H/2), as the flowline volume
    fc_vol = dx * total(thick_dx[fc_j] * (width_base_dx[fc_j] + lambda_dx[fc_j] * thick_dx[fc_j] / 2d0))
    thick_dx[fc_j] = 0d0
  endif
endif
