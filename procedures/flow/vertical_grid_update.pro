; Script: conservative_volume_vertical_grid_update.pro
; Purpose: Convert horizontal grid (flow model) back to vertical grid (main model)
; Call with: @conservative_volume_vertical_grid_update -> annually updates vertical grid based on flow model thickness

; arrays:
; _dx: arrays containing geometry for horizontally equidistant grid
; _dz: arrays containing geometry for vertically equidistant grid

compile_opt idl2

; ========== STEP 1: CREATE VERTICAL GRID WITHOUT SEGMENTATION ==========
print, ''
print, '=== CREATING VERTICAL GRID ==='

; Smooth surface to reduce noise
sur_dx_smooth = smooth(sur_dx, 5)

; Set initial vertical band spacing and options
dz = 10.0
min_elev_span = 1000.0 ; <-- minimum elevation span in meters (option)

; Find min and max surface elevation (rounded to nearest 10)
surf_min = min(sur_dx_smooth)
surf_max = max(sur_dx_smooth)
surf_min_rounded = ceil(surf_min / 10.0) * 10.0
surf_max_rounded = floor(surf_max / 10.0) * 10.0

; Calculate elevation span
elev_span = surf_max_rounded - surf_min_rounded

; Adjust dz if elevation span is below threshold
if elev_span lt min_elev_span then begin
  dz = dz * (elev_span / min_elev_span)
  print, '  dz reduced to ', dz, ' m due to low elevation span (', elev_span, ' m, min allowed: ', min_elev_span, ' m)'
endif

; Always create ascending vertical grid
sur_dz = surf_min_rounded + findgen(fix((surf_max_rounded - surf_min_rounded) / dz) + 1) * dz
sur_dz = sur_dz[where(sur_dz le surf_max)]

nb = n_elements(sur_dz)

; ========== STEP 1b: CALCULATE FLOW MODEL VOLUME ==========
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

; ========== STEP 2: IMPROVED DISTANCE-BASED INTERPOLATION WITH MONOTONIC SEGMENTS ==========

; 1. Get valid elevation bands
surf_min_dx = min(sur_dx)
surf_max_dx = max(sur_dx)
valid_bands = where((sur_dz ge surf_min_dx) and (sur_dz le surf_max_dx), n_valid_bands)

; 2. Use original horizontal grid data (no smoothing)
sur_dx_used = sur_dx
thick_dx_used = th_x
width_dx_used = width_for_volume
dist_dx_used = x_dist
dx_used = x_dist[1] - x_dist[0]
nb_dz = n_elements(sur_dz)

; 3. Find monotonic segments in the surface
d_surface = deriv(sur_dx_used)
sign_change = where(d_surface * shift(d_surface, -1) lt 0, n_change)
segment_edges = [0, sign_change + 1, n_elements(sur_dx_used)]

; 4. Prepare output arrays for the vertical grid
thick_dz = dblarr(nb_dz)
width_dz = dblarr(nb_dz)
area_dz = dblarr(nb_dz)
gl_dz = dblarr(nb_dz) + noval

; 5. Interpolate within each monotonic segment
for s = 0, n_elements(segment_edges) - 2 do begin
  seg_start = segment_edges[s]
  seg_end = segment_edges[s + 1] - 1
  seg_surface = sur_dx_used[seg_start : seg_end]
  seg_thick = thick_dx_used[seg_start : seg_end]
  seg_width = width_dx_used[seg_start : seg_end]
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

; 6. Prepare arrays for area and distance per band
distance_per_band_dz = dblarr(nb_dz)

; 7. Map each elevation band to its distance along glacier and compute area
for i = 0, nb_dz - 1 do begin
  elev_target = sur_dz[i]
  x_interp = interpol(dist_dx_used, sur_dx_used, elev_target)
  ; Calculate distance step by looking at neighboring elevations
  if i eq 0 then begin
    if nb_dz gt 1 then begin
      next_elev = sur_dz[1]
      next_x = interpol(dist_dx_used, sur_dx_used, next_elev)
      distance_step = abs(next_x - x_interp)
    endif else distance_step = dx_used
  endif else if i eq nb_dz - 1 then begin
    prev_elev = sur_dz[nb_dz - 2]
    prev_x = interpol(dist_dx_used, sur_dx_used, prev_elev)
    distance_step = abs(x_interp - prev_x)
  endif else begin
    prev_elev = sur_dz[i - 1]
    next_elev = sur_dz[i + 1]
    prev_x = interpol(dist_dx_used, sur_dx_used, prev_elev)
    next_x = interpol(dist_dx_used, sur_dx_used, next_elev)
    distance_step = abs(next_x - prev_x) / 2.0
  endelse
  distance_per_band_dz[i] = distance_step
  area_dz[i] = width_dz[i] * distance_step / 1000.0 ; km²
endfor

if nb_dz gt 1 then distance_per_band_dz[0] = distance_per_band_dz[1]

; 8. Assign elevation to gl_dz
gl_dz = sur_dz

; 9. Apply physical constraints
thick_dz = thick_dz > 0.
width_dz = width_dz > 0.

; 10. Reference volume from horizontal grid (trapezoidal rule)
total_volume_flow = 0.
for i = 0, n_elements(th_x) - 2 do begin
  avg_th = (th_x[i] + th_x[i + 1]) / 2.
  avg_w = (width_for_volume[i] + width_for_volume[i + 1]) / 2.
  dx = x_dist[i + 1] - x_dist[i]
  total_volume_flow += avg_th * avg_w * dx
endfor

; 11. Calculate vertical grid volume and error
total_volume_vertical = total(thick_dz * area_dz * 1000.) ; m³
volume_error = 0.
if total_volume_flow gt 0 then volume_error = abs(total_volume_flow - total_volume_vertical) / total_volume_flow

print, 'Reference volume: ', total_volume_flow, ' m³'
print, 'Vertical grid volume: ', total_volume_vertical, ' m³'
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

; Save pre-correction thickness
thickness_dz_before = thickness_dz

; Apply thickness correction proportional to local thickness if error > 0.05%
if volume_error gt 0.0005 then begin
  print, 'Applying proportional thickness correction due to volume error: ', volume_error * 100., '%'
  ; Calculate total thickness sum for weighting (only where thickness > 0 and area > 0)
  valid = where((thickness_dz gt 0) and (area_dz gt 0), n_valid) ; only bands with ice
  if n_valid gt 0 then begin
    total_thick = total(thickness_dz[valid])
    for i = 0, n_elements(thickness_dz) - 1 do begin
      if (thickness_dz[i] gt 0) and (area_dz[i] gt 0) then begin
        weight = thickness_dz[i] / total_thick
        ; Correction only for valid bands, avoid division by zero
        thickness_dz[i] = thickness_dz[i] + (total_volume_dx - current_volume) / (area_dz[i] * 1000.) * weight
      endif
    endfor
  endif
endif
; Final volume check
final_volume = total(thickness_dz * area_dz * 1000.)
final_error = abs(total_volume_dx - final_volume) / total_volume_dx

print, 'Reference volume: ', total_volume_dx, ' m³'
print, 'Final volume: ', final_volume, ' m³'
print, 'Final volume error: ', final_error * 100., '%'

; ========== STEP 5: FINAL ASSIGNMENT =========

thick = thickness_dz
elev = sur_dz
distance = distance_dz
width = width_dz
area = area_dz

; create a glacier mask on sur_dz: gl_dz holds sur_dz where thickness > 0, else noval
gl_dz = dblarr(n_elements(sur_dz)) + noval
valid_idx = where(thick gt 0, n_valid)
if n_valid gt 0 then gl_dz[valid_idx] = sur_dz[valid_idx]
gl = gl_dz
