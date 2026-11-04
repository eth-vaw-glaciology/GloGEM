; Renew the variables while solving the continuity equation
; (which is performed in three intermediate steps)
compile_opt idl2

; Store original width_surface before any modifications (for volume conservation)
if n_elements(width_surface_original) eq 0 then begin
  ; First time - create the variable
  width_surface_original = width_base_dx + lambda_dx * thick_dx
endif else begin
  ; Store current width_surface as original for this timestep
  width_surface_original = width_surface_dx
endelse

sur_dx[1 : xnum - 1] = bed_dx[1 : xnum - 1] + thick_dx[1 : xnum - 1]
width_surface_dx = width_base_dx + lambda_dx * thick_dx
width_mid_dx = (width_base_dx + width_surface_dx) / 2.0
