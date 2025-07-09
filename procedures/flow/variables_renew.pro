; Renew the variables while solving the continuity equation
; (which is performed in three intermediate steps)
compile_opt idl2

; Store original width_surface before any modifications (for volume conservation)
if n_elements(width_surface_original) eq 0 then begin
  ; First time - create the variable
  width_surface_original = width_base + lambda * th_x
endif else begin
  ; Store current width_surface as original for this timestep
  width_surface_original = width_surface
endelse

sur_x[1 : xnum - 1] = bed_x[1 : xnum - 1] + th_x[1 : xnum - 1]
width_surface = width_base + lambda * th_x
width_mid = (width_base + width_surface) / 2.0
