; Script: conservative_volume_vertical_grid_update.pro
; Purpose: Convert horizontal grid (flow model) back to vertical grid (main model)
; Call with: @conservative_volume_vertical_grid_update

; Calculate total volume from flow model (horizontal grid)
compile_opt idl2
total_volume_flow = 0.
valid_flow = where(th_x gt 0, n_valid_flow)

; print, '========== CONVERSION DIAGNOSTICS =========='
; print, 'Total horizontal cells: ', n_elements(th_x)
; print, 'Cells with ice: ', n_valid_flow
; print, 'Total vertical bands: ', nb

if n_valid_flow eq 0 then begin
  ; print, 'WARNING: No ice found in horizontal grid!'
  thick = dblarr(nb)
  area = dblarr(nb)
  width = dblarr(nb)
  gl = dblarr(nb) + noval
  goto, skip_conversion
endif

; Detailed horizontal grid analysis
; print, '--- HORIZONTAL GRID ANALYSIS ---'
; print, 'Thickness range: ', min(th_x[valid_flow]), ' to ', max(th_x[valid_flow]), ' m'
; print, 'Width range: ', min(width_surface[valid_flow]), ' to ', max(width_surface[valid_flow]), ' m'
; print, 'Distance range: ', min(x_dist), ' to ', max(x_dist), ' m'

; Calculate volume from horizontal grid
for i = 0, n_elements(th_x) - 2 do begin
  dx = x_dist[i + 1] - x_dist[i]
  avg_thickness = (th_x[i] + th_x[i + 1]) / 2.
  avg_width = (width_surface[i] + width_surface[i + 1]) / 2.
  if avg_thickness gt 0 then total_volume_flow += avg_thickness * avg_width * dx
endfor

; print, 'Total flow model volume: ', total_volume_flow, ' m³'

; Calculate surface elevation and find glacier extent
sur_x = bed_x + th_x
elev_min = min(bed_x[valid_flow])
elev_max = max(sur_x[valid_flow])

; print, 'Bed elevation range: ', elev_min, ' to ', max(bed_x[valid_flow]), ' m'
; print, 'Surface elevation range: ', min(sur_x[valid_flow]), ' to ', elev_max, ' m'

; Initialize arrays
thick_new = dblarr(nb)
area_new = dblarr(nb)
width_new = dblarr(nb)
gl_new = dblarr(nb) + noval

; STEP 1: Create elevation band centers for vertical grid
if n_elements(elev) eq nb then begin
  elev_bands = elev ; Use current elevation band centers
  ; print, 'Using existing elevation bands'
endif else begin
  elev_bands = bed_elev + step / 2. ; Center of each elevation band
  ; print, 'Reconstructing elevation bands from bed elevation'
endelse

; print, '--- VERTICAL GRID ANALYSIS ---'
; print, 'Elevation band range: ', min(elev_bands), ' to ', max(elev_bands), ' m'
; print, 'Elevation step: ', step, ' m'

; STEP 2: Create center positions for each horizontal cell
x_centers = dblarr(n_elements(th_x))
for i = 0, n_elements(th_x) - 1 do begin
  if i eq 0 then begin
    x_centers[i] = x_dist[i] + (x_dist[i + 1] - x_dist[i]) / 2.
  endif else if i eq n_elements(th_x) - 1 then begin
    x_centers[i] = x_dist[i - 1] + (x_dist[i] - x_dist[i - 1]) / 2.
  endif else begin
    x_centers[i] = x_dist[i]
  endelse
endfor

; Calculate mean elevation for each horizontal cell
elev_centers = bed_x + th_x / 2.

; Only use cells with ice for interpolation
valid_cells = where(th_x gt 0, n_valid)
; print, '--- INTERPOLATION SETUP ---'
; print, 'Valid cells for interpolation: ', n_valid

if n_valid gt 0 then begin
  x_valid = x_centers[valid_cells]
  elev_valid = elev_centers[valid_cells]
  thick_valid = th_x[valid_cells]
  width_valid = width_surface[valid_cells]

  ; print, 'Elevation centers range: ', min(elev_valid), ' to ', max(elev_valid), ' m'
  ; print, 'Thickness for interpolation: ', min(thick_valid), ' to ', max(thick_valid), ' m'
  ; print, 'Width for interpolation: ', min(width_valid), ' to ', max(width_valid), ' m'

  ; Sort by elevation for interpolation
  sort_idx = sort(elev_valid)
  elev_sorted = elev_valid[sort_idx]
  thick_sorted = thick_valid[sort_idx]
  width_sorted = width_valid[sort_idx]

  ; Check for duplicate elevations
  if n_valid gt 1 then begin
    elev_diff = elev_sorted[1 : *] - elev_sorted[0 : n_valid - 2]
    duplicate_count = n_elements(where(elev_diff lt 0.1, /null))
    if duplicate_count gt 0 then begin
      ; print, 'WARNING: Found ', duplicate_count, ' near-duplicate elevations'
    endif
  endif

  ; STEP 3: Interpolate to vertical grid using INTERPOL
  ; Find valid elevation range in vertical grid
  valid_bands = where(elev_bands ge elev_min - step and elev_bands le elev_max + step, n_bands)

  ; print, '--- INTERPOLATION EXECUTION ---'
  ; print, 'Elevation bands in glacier range: ', n_bands, ' out of ', nb

  if n_bands gt 0 then begin
    ; print, 'Band elevation range: ', min(elev_bands[valid_bands]), ' to ', max(elev_bands[valid_bands]), ' m'
  endif

  if n_bands gt 0 and n_valid gt 1 then begin
    ; Interpolate thickness and width to elevation bands
    thick_interp = interpol(thick_sorted, elev_sorted, elev_bands[valid_bands])
    width_interp = interpol(width_sorted, elev_sorted, elev_bands[valid_bands])

    ; print, 'Interpolated thickness range: ', min(thick_interp), ' to ', max(thick_interp), ' m'
    ; print, 'Interpolated width range: ', min(width_interp), ' to ', max(width_interp), ' m'

    ; Count negative values before correction
    neg_thick = n_elements(where(thick_interp lt 0, /null))
    neg_width = n_elements(where(width_interp lt 0, /null))
    ; if neg_thick gt 0 then ; print, 'WARNING: ', neg_thick, ' negative thickness values from interpolation'
    ; if neg_width gt 0 then ; print, 'WARNING: ', neg_width, ' negative width values from interpolation'

    ; Assign interpolated values
    thick_new[valid_bands] = thick_interp > 0. ; Ensure no negative thickness
    width_new[valid_bands] = width_interp > 0. ; Ensure no negative width
    area_new[valid_bands] = width_new[valid_bands] * step / 1000. ; convert to km²
    gl_new[valid_bands] = elev_bands[valid_bands]
  endif else if n_valid eq 1 then begin
    ; print, 'Single point interpolation mode'
    ; Single point - assign to nearest elevation band
    nearest_band = min(abs(elev_bands - elev_valid[0]), min_idx)
    thick_new[min_idx] = thick_valid[0]
    width_new[min_idx] = width_valid[0]
    area_new[min_idx] = width_valid[0] * step / 1000.
    gl_new[min_idx] = elev_bands[min_idx]
    ; print, 'Assigned to elevation band: ', min_idx, ' at elevation: ', elev_bands[min_idx], ' m'
  endif
endif

; STEP 4: Volume conservation check and correction
total_volume_vertical = total(thick_new * area_new * 1000.)

; print, '--- VOLUME CONSERVATION ---'
; print, 'Volume before correction: ', total_volume_vertical, ' m³'
; print, 'Target volume (from flow): ', total_volume_flow, ' m³'

if total_volume_vertical gt 0 then begin
  volume_error = abs(total_volume_flow - total_volume_vertical) / total_volume_flow
  ; print, 'Volume error: ', volume_error * 100., '%'

  if volume_error gt 0.01 then begin ; 1% tolerance
    correction_factor = total_volume_flow / total_volume_vertical
    ; print, 'Applying correction factor: ', correction_factor

    ; Detailed analysis of correction factor
    if correction_factor gt 2.0 then begin
      ; print, 'ERROR: Very large correction factor detected!'
      ; print, 'This suggests fundamental issues with interpolation'
    endif else if correction_factor lt 0.5 then begin
      ; print, 'ERROR: Very small correction factor detected!'
      ; print, 'This suggests interpolation is overestimating volume'
    endif

    thick_new = thick_new * correction_factor
    ; print, 'Volume conservation correction applied: ', correction_factor
  endif else begin
    ; print, 'Volume error within tolerance, no correction needed'
  endelse
endif

; STEP 5: Final assignment and validation
thick = thick_new
area = area_new
width = width_new
gl = gl_new

; Count and analyze final results
final_ice_bands = n_elements(where(thick gt 0, /null))
if final_ice_bands gt 0 then begin
  final_total_area = total(area[where(thick gt 0, /null)])
  final_max_thickness = max(thick)
  final_min_thickness = min(thick[where(thick gt 0, /null)])
endif else begin
  final_total_area = 0.
  final_max_thickness = 0.
  final_min_thickness = 0.
endelse

; print, '--- FINAL RESULTS ---'
; print, 'Glacierized bands: ', final_ice_bands, ' out of ', nb
; print, 'Total glacierized area: ', final_total_area, ' km²'
; print, 'Final thickness range: ', final_min_thickness, ' to ', final_max_thickness, ' m'

; Ensure no negative values
negative_idx = where(thick lt 0, n_negative)
if n_negative gt 0 then begin
  ; print, 'WARNING: Correcting ', n_negative, ' negative thickness values'
  thick[negative_idx] = 0.
  area[negative_idx] = 0.
  width[negative_idx] = 0.
  gl[negative_idx] = noval
endif

; Final consistency check
zero_thick = where(thick eq 0, n_zero)
if n_zero gt 0 then gl[zero_thick] = noval

; Update bed elevation after geometry changes
bed_elev = elev_bands - thick

; STEP 6: Validation output
final_volume = total(thick * area * 1000.)
final_error = 0.
if total_volume_flow gt 0 then begin
  final_error = abs(final_volume - total_volume_flow) / total_volume_flow
  ; print, '--- FINAL VALIDATION ---'
  ; print, 'Flow model volume: ', total_volume_flow, ' m³'
  ; print, 'Vertical grid volume: ', final_volume, ' m³'
  ; print, 'Final volume error: ', final_error * 100., '%'
  ; print, 'Glacierized bands: ', n_elements(where(thick gt 0, /null)), '/', nb

  ; Alert for significant errors
  if final_error gt 0.05 then begin
    ; print, 'ERROR: Final volume error exceeds 5%!'
    ; print, 'Consider investigating interpolation method'
  endif
endif

; print, '========== END DIAGNOSTICS =========='
; print, ''

skip_conversion:
; End of script
