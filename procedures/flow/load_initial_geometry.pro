; -----------------------------
; Short script to load the initial geometry of the glacier
; will be executed at the start of the model run
;
; @authors: Janosch Beer (2025)
; -----------------------------

compile_opt idl2

; Load initial geometry only at the very first run of the model
if ye eq 0 then begin
  print, 'Loading initial geometry...'
  dist_dx = horizontal_grid_inputs.dist_dx ; distance along the glacier in m
  sur_dx = horizontal_grid_inputs.sur_dx ; Surface elevation (m)
  width_dx = horizontal_grid_inputs.width_dx ; Surface width (m)
  thick_dx = horizontal_grid_inputs.thick_dx ; Ice thickness (m)
  bed_dx = horizontal_grid_inputs.bed_dx ; Bed elevation (m)

  width_surface_dx = width_surface_dx_init ; Width at surface of the glacier (m)
  width_mid_dx = width_mid_dx_init ; Width at mid-point of the glacier (m)
  width_base_dx = width_base_dx_init ; Width at base of the glacier (m)
  lambda_dx = lambda_dx_init ; Slope parameter (m)
endif
