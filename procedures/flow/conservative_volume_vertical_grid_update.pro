; Script: conservative_volume_vertical_grid_update.pro
; Purpose: Convert horizontal grid (flow model) back to vertical grid (main model)
; Approach: Use original width_surface stored before flow model changes
; Call with: @conservative_volume_vertical_grid_update

compile_opt idl2

; ========== STEP 1: CALCULATE FLOW MODEL VOLUME ==========
total_volume_flow = 0.
valid_flow = where(th_x gt 0, n_valid_flow)

if n_valid_flow eq 0 then begin
  thick = dblarr(nb)
  area = dblarr(nb)
  width = dblarr(nb)
  gl = dblarr(nb) + noval
  goto, skip_conversion
endif

; Use the original width_surface stored before flow model modifications
if n_elements(width_surface_original) eq n_elements(th_x) then begin
  width_for_volume = width_surface_original
  print, 'Using stored original width_surface for volume calculation'
endif else begin
  ; Fallback: reconstruct from width_base and lambda
  width_for_volume = width_base + lambda_x * th_x
  print, 'WARNING: Using reconstructed width (width_surface_original not available)'
endelse

; Calculate volume from horizontal grid using trapezoidal rule
for i = 0, n_elements(th_x) - 2 do begin
  dx = x_dist[i + 1] - x_dist[i]
  avg_thickness = (th_x[i] + th_x[i + 1]) / 2.
  avg_width = (width_for_volume[i] + width_for_volume[i + 1]) / 2.
  if avg_thickness gt 0 then total_volume_flow += avg_thickness * avg_width * dx
endfor

print, 'Flow model volume: ', total_volume_flow, ' m³'

; ========== STEP 2: DIRECT ELEVATION-BASED INTERPOLATION ==========
; Calculate surface elevation from horizontal grid
sur_x = bed_x + th_x

; Get elevation bands
if n_elements(elev) eq nb then begin
  elev_bands = elev
endif else begin
  elev_bands = bed_elev + step / 2.
endelse

; Initialize arrays
thick_new = dblarr(nb)
area_new = dblarr(nb)
width_new = dblarr(nb)
gl_new = dblarr(nb) + noval

; Find glacier elevation range
elev_min = min(sur_x[valid_flow])
elev_max = max(sur_x[valid_flow])

print, 'Glacier elevation range: ', elev_min, ' to ', elev_max, ' m'

; Only process bands within glacier range
valid_bands = where(elev_bands ge elev_min - step and elev_bands le elev_max + step, n_bands)

if n_bands gt 0 then begin
  ; Create lookup data sorted by surface elevation
  sur_lookup = sur_x[valid_flow]
  th_lookup = th_x[valid_flow]
  width_lookup = width_for_volume[valid_flow] ; Use the same width as for volume calculation

  sort_idx = sort(sur_lookup)
  sur_sorted = sur_lookup[sort_idx]
  th_sorted = th_lookup[sort_idx]
  width_sorted = width_lookup[sort_idx]

  ; Simple linear interpolation on surface elevation
  thick_interp = interpol(th_sorted, sur_sorted, elev_bands[valid_bands])
  width_interp = interpol(width_sorted, sur_sorted, elev_bands[valid_bands])

  ; Apply basic smoothing
  if n_bands gt 2 then begin
    thick_smooth = thick_interp
    width_smooth = width_interp
    for i = 1, n_bands - 2 do begin
      thick_smooth[i] = (thick_interp[i - 1] + thick_interp[i] + thick_interp[i + 1]) / 3.0
      width_smooth[i] = (width_interp[i - 1] + width_interp[i] + width_interp[i + 1]) / 3.0
    endfor
    thick_interp = thick_smooth
    width_interp = width_smooth
  endif

  ; Apply physical constraints
  thick_interp = thick_interp > 0.
  width_interp = width_interp > 0.

  ; Conservative thickness limit
  max_thick_limit = max(th_sorted) * 1.1 ; Only 10% increase allowed
  extreme_idx = where(thick_interp gt max_thick_limit, n_extreme)
  if n_extreme gt 0 then begin
    print, 'Capping ', n_extreme, ' extreme thickness values'
    thick_interp[extreme_idx] = max_thick_limit
  endif

  ; Assign values
  thick_new[valid_bands] = thick_interp
  width_new[valid_bands] = width_interp
  area_new[valid_bands] = width_new[valid_bands] * step / 1000.
  gl_new[valid_bands] = elev_bands[valid_bands]
endif

; ========== STEP 3: CONSERVATIVE VOLUME CORRECTION ==========
total_volume_vertical = total(thick_new * area_new * 1000.)
volume_error = 0.

if total_volume_vertical gt 0 and total_volume_flow gt 0 then begin
  volume_error = abs(total_volume_flow - total_volume_vertical) / total_volume_flow

  print, 'Volume before correction: ', total_volume_vertical, ' m³'
  print, 'Volume error: ', volume_error * 100., '%'

  ; Apply corrections for reasonable errors
  if volume_error gt 0.05 and volume_error lt 0.5 then begin ; Between 5% and 50%
    correction_factor = total_volume_flow / total_volume_vertical

    ; Conservative limits
    if correction_factor gt 1.5 then correction_factor = 1.5
    if correction_factor lt 0.7 then correction_factor = 0.7

    ; Apply uniform correction
    ice_bands = where(thick_new gt 0, n_ice)
    if n_ice gt 0 then begin
      thick_new[ice_bands] = thick_new[ice_bands] * correction_factor
      print, 'Applied correction factor: ', correction_factor
    endif
  endif else if volume_error gt 0.5 then begin
    print, 'WARNING: Volume error too large (', volume_error * 100., '%) - skipping correction'
  endif
endif

; ========== STEP 4: FINAL ASSIGNMENT ==========
thick = thick_new
area = area_new
width = width_new
gl = gl_new

; Clean up
negative_idx = where(thick lt 0, n_negative)
if n_negative gt 0 then begin
  thick[negative_idx] = 0.
  area[negative_idx] = 0.
  width[negative_idx] = 0.
  gl[negative_idx] = noval
endif

zero_thick = where(thick eq 0, n_zero)
if n_zero gt 0 then gl[zero_thick] = noval

; Update bed elevation
bed_elev = elev_bands - thick

; Final diagnostics
final_volume = total(thick * area * 1000.)
final_error = 0.
if total_volume_flow gt 0 then begin
  final_error = abs(final_volume - total_volume_flow) / total_volume_flow
endif

print, '--- GRID CONVERSION ---'
print, 'Volume error: ', final_error * 100., '%'

ice_bands = where(thick gt 0, n_ice_final)
if n_ice_final gt 0 then begin
  max_thickness = max(thick[ice_bands])
  print, 'Ice bands: ', n_ice_final, '/', nb, ', Max thickness: ', max_thickness, 'm'
endif else begin
  print, 'WARNING: No ice after conversion!'
endelse

skip_conversion:
; End of script
