; Script: conservative_volume_vertical_grid_update.pro
; Purpose: Convert horizontal grid (flow model) back to vertical grid (main model)
; Call with: @conservative_volume_vertical_grid_update -> annually updates vertical grid based on flow model thickness

; arrays:
; _dx: arrays containing geometry for horizontally equidistant grid
; _dz: arrays containing geometry for vertically equidistant grid

compile_opt idl2

; Set ice thickness in the horizontal grid to 0 where it is lower than 1m (for stability and consistency)
for i = 0, n_elements(thick_dx) - 1 do begin
  if thick_dx[i] lt 1.0 then thick_dx[i] = 0.0
endfor

; ========== STEP 1: READ VERTICAL GRID WITHOUT SEGMENTATION ==========
print, ''
print, '=== READ VERTICAL GRID ==='

; Read vertical grid data from main GloGEM script at the start of the model run
if ye eq 0 then begin
  bed_dz = bed_elev ; Bedrock elevation (m), does not need a _init suffix as it will always be the same
  sur_dz = elev ; Surface elevation (m), can be initialized from the original elevation band centers
  nb_dz = n_elements(sur_dz) ; number of elevation bands in vertical grid
  print, 'Elevation range of vertical grid (sur_dz): ', min(sur_dz), ' to ', max(sur_dz)
  print, 'Elevation range of horizontal grid (sur_dx): ', min(sur_dx_init), ' to ', max(sur_dx_init)
endif else begin
  nb_dz = n_elements(sur_dz) ; number of elevation bands in recent vertical grid
  print, 'Elevation range of vertical grid (sur_dz): ', min(sur_dz), ' to ', max(sur_dz)
  print, 'Elevation range of horizontal grid (sur_dx): ', min(sur_dx), ' to ', max(sur_dx)
endelse

; ========== STEP 2: DISTANCE-BASED INTERPOLATION WITHOUT REDUNDANT ARRAYS ==========

; 1. Get valid elevation bands
surf_min_dx = min(sur_dx)
surf_max_dx = max(sur_dx)
valid_bands = where((sur_dz ge surf_min_dx) and (sur_dz le surf_max_dx), n_valid_bands)

; 2. Find monotonic segments in the surface
d_surface = deriv(sur_dx)
sign_change = where(d_surface * shift(d_surface, -1) lt 0, n_change)
segment_edges = [0, sign_change + 1, n_elements(sur_dx)]

; 3. Prepare output arrays for the vertical grid
thick_dz = dblarr(nb_dz)
width_dz = dblarr(nb_dz)
area_dz = dblarr(nb_dz)
gl_dz = dblarr(nb_dz) + noval

; 4. Interpolate within each monotonic segment
for s = 0, n_elements(segment_edges) - 2 do begin
  seg_start = segment_edges[s]
  seg_end = segment_edges[s + 1] - 1
  seg_surface = sur_dx[seg_start : seg_end]
  seg_thick = thick_dx[seg_start : seg_end]
  seg_width = width_dx[seg_start : seg_end]
  ; Sort segment by surface elevation
  sort_idx = sort(seg_surface)
  seg_surface_sorted = seg_surface[sort_idx]
  seg_thick_sorted = seg_thick[sort_idx]
  seg_width_sorted = seg_width[sort_idx]
  ; Find valid bands for this segment
  seg_valid = where((sur_dz ge min(seg_surface_sorted)) and (sur_dz le max(seg_surface_sorted)), n_seg_valid)
  if n_seg_valid gt 0 then begin
    thick_interp = interpol(seg_thick_sorted, seg_surface_sorted, sur_dz[seg_valid])
    width_interp = interpol(seg_width_sorted, seg_surface_sorted, sur_dz[seg_valid])
    for j = 0, n_seg_valid - 1 do begin
      idx = seg_valid[j]
      thick_dz[idx] = thick_interp[j]
      width_dz[idx] = width_interp[j]
    endfor
  endif
endfor

; 5. Prepare arrays for area and distance per band
distance_per_band_dz = dblarr(nb_dz)

; 6. Map each elevation band to its distance along glacier and compute area
for i = 0, nb_dz - 1 do begin
  elev_target = sur_dz[i]
  x_interp = interpol(dist_dx, sur_dx, elev_target)
  ; Calculate distance step by looking at neighboring elevations
  if i eq 0 then begin
    if nb_dz gt 1 then begin
      next_elev = sur_dz[1]
      next_x = interpol(dist_dx, sur_dx, next_elev)
      distance_step = abs(next_x - x_interp)
    endif else distance_step = dist_dx[1] - dist_dx[0]
  endif else if i eq nb_dz - 1 then begin
    prev_elev = sur_dz[nb_dz - 2]
    prev_x = interpol(dist_dx, sur_dx, prev_elev)
    distance_step = abs(x_interp - prev_x)
  endif else begin
    prev_elev = sur_dz[i - 1]
    next_elev = sur_dz[i + 1]
    prev_x = interpol(dist_dx, sur_dx, prev_elev)
    next_x = interpol(dist_dx, sur_dx, next_elev)
    distance_step = abs(next_x - prev_x) / 2.0
  endelse
  distance_per_band_dz[i] = distance_step
  area_dz[i] = width_dz[i] * distance_step / 1000.0 ; km²
endfor

if nb_dz gt 1 then distance_per_band_dz[0] = distance_per_band_dz[1]

; 7. Assign elevation to gl_dz
gl_dz = sur_dz

; 8. Apply physical constraints

; Set ice thickness to 0 if it is already below 1m (for stability and physical consistency)
for i = 0, n_elements(thick_dz) - 1 do begin
  if thick_dz[i] lt 1.0 then thick_dz[i] = 0.0
endfor

thick_dz = thick_dz > 0.
width_dz = width_dz > 0.

; 9. Reference volume from horizontal grid (simple sum)
total_volume_dx = total(thick_dx * width_dx * dx) ; m³

print, 'thick_dx: ', thick_dx
print, 'width_dx: ', width_dx
print, 'dx: ', dx

; 10. Calculate vertical grid volume and error
total_volume_dz = total(thick_dz * area_dz * 1000.) ; m³
volume_error = 0.
if total_volume_dx gt 0 then volume_error = abs(total_volume_dx - total_volume_dz) / total_volume_dx

print, 'Reference volume: ', total_volume_dx, ' m³'
print, 'Vertical grid volume: ', total_volume_dz, ' m³'
print, 'Volume error: ', volume_error * 100., ' %'

; ========== STEP 3: COMPUTE DISTANCE ALONG VERTICAL GRID ==========

; Start with the first band distance
distance_dz = [distance_per_band_dz[0] / 1000.0]
for i = 1, n_elements(sur_dz) - 1 do begin
  distance_dz = [distance_dz, distance_dz[i - 1] + distance_per_band_dz[i] / 1000.0]
endfor

; rescale distance_dz to match the horizontal grid length
distance_dz = distance_dz * (max(dist_dx) / max(distance_dz))
distance_dz = distance_dz / 1000.0 ; convert to km

; ========== STEP 4: APPLY THICKNESS CORRECTION IF NECESSARY TO CONSERVE VOLUME ==========

; Add a switch to enable/disable thickness correction
apply_thickness_correction = 0 ; set to 1 to enable, 0 to disable

; Calculate current volume
current_volume = total(thick_dz * area_dz * 1000.)
volume_error = abs(total_volume_dx - current_volume) / total_volume_dx

; Save pre-correction thickness
thick_dz_before = thick_dz

; Apply thickness correction proportional to local volume contribution if error > 0.1%
if apply_thickness_correction eq 1 then begin
  if volume_error gt 0.001 then begin
    print, 'Applying proportional thickness correction due to volume error: ', volume_error * 100., '%'
    ; Only correct where thickness > threshold and area > 0
    threshold = 1.0 ; meters
    valid = where((thick_dz gt threshold) and (area_dz gt 0), n_valid)
    if n_valid gt 0 then begin
      total_vol = total(thick_dz[valid] * area_dz[valid])
      for i = 0, n_elements(thick_dz) - 1 do begin
        if (thick_dz[i] gt threshold) and (area_dz[i] gt 0) then begin
          weight = (thick_dz[i] * area_dz[i]) / total_vol ; weight based on band volume contribution
          thick_dz[i] = thick_dz[i] + (total_volume_dx - current_volume) * weight / (area_dz[i] * 1000.)
        endif
      endfor
    endif
  endif
endif

; After correction, set very small thicknesses to zero for stability
min_thick = 1e-3 ; meters
for i = 0, n_elements(thick_dz) - 1 do begin
  if thick_dz[i] lt min_thick then thick_dz[i] = 0.0
endfor

; Final volume check
final_volume = total(thick_dz * area_dz * 1000.)
final_error = abs(total_volume_dx - final_volume) / total_volume_dx

print, 'Reference volume: ', total_volume_dx, ' m³'
print, 'Final volume: ', final_volume, ' m³'
print, 'Final volume error: ', final_error * 100., '%'

print, 'Thickness before correction: ', thick_dz_before
print, 'Thickness after correction: ', thick_dz

; ========== STEP 5: FINAL ASSIGNMENT =========

sur_dz = bed_dz + thick_dz ; Update surface elevation based on bedrock and thickness

; Assign final arrays so that they can be used in the main model
thick = thick_dz
elev = sur_dz
distance = distance_dz
width = width_dz
area = area_dz

; create a glacier mask on sur_dz: gl_dz holds sur_dz where thickness > 0, else noval
gl_dz = dblarr(n_elements(sur_dz)) + noval
valid_idx = where(thick gt 0, n_valid)
if n_valid gt 0 then gl_dz[valid_idx] = sur_dz[valid_idx]
gl = gl_dz
