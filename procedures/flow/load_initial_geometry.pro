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

  print, 'thick_dx at initialization:', thick_dx

  bed_dx = horizontal_grid_inputs.bed_dx ; Bed elevation (m)

  width_surface_dx = width_surface_dx_init ; Width at surface of the glacier (m)
  width_mid_dx = width_mid_dx_init ; Width at mid-point of the glacier (m)
  width_base_dx = width_base_dx_init ; Width at base of the glacier (m)
  lambda_dx = lambda_dx_init ; Slope parameter (m)

  ; mask NaN values in all geometry arrays
  arrays = [sur_dx, bed_dx, width_dx, thick_dx, width_surface_dx, width_mid_dx, width_base_dx, lambda_dx]
  foreach arr, arrays do begin
    bad = where((finite(arr) eq 0) or (arr eq -9999), count)
    if count gt 0 then arr[bad] = 0.0 ; or use a more physical value if appropriate
  endforeach

  ; print out all arrays to check for remaining NaN or invalid values
  print, 'Surface elevation (sur_dx):', sur_dx
  print, 'Bed elevation (bed_dx):', bed_dx
  print, 'Surface width (width_dx):', width_dx
  print, 'Ice thickness (thick_dx):', thick_dx
  print, 'Width at surface (width_surface_dx):', width_surface_dx
  print, 'Width at mid-point (width_mid_dx):', width_mid_dx
  print, 'Width at base (width_base_dx):', width_base_dx
  print, 'Slope parameter (lambda_dx):', lambda_dx
endif
