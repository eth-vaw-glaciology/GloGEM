; *************************************************************
; flow_cell_volume
;
; Ice volume (m3) of the flowline cells ice_thickness.pro updates (2..n-2),
; with the trapezoid cross-section H*(w_base + lambda*H/2) it conserves.
; *************************************************************

function flow_cell_volume, thick, wbase, lam, dx
  compile_opt idl2
  n = n_elements(thick)
  h = thick[2:n-2]
  return, total(h * (wbase[2:n-2] + lam[2:n-2] * h / 2d0)) * dx
end
