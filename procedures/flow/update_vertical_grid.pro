; ----- Convert horizontal to vertical grid -----
; Script to convert the horizontally equidistant grid used in GloGEMflow back into a vertically equidistant grid
; It is called from the main script 'glogemflow.pro'.
; -----------------------------------------------------
;
; @authors: Janosch Beer (2025)

compile_opt idl2

; Input from horizontal grid (from GloGEMflow):
; - x: horizontal distance coordinates
; - th_x: ice thickness on horizontal grid (current state)
; - width_surface: width on horizontal grid at the surface (current state)
; - sur_x: surface elevation on horizontal grid (current state)
; - bed_x: bedrock elevation on horizontal grid (current state)
; - dx: horizontal grid spacing

; Original vertical grid parameters (should be preserved from initial setup):
; - elev0: original elevation band centers
; - bed_elev: original bedrock elevation for each elevation band
; - nb: number of elevation bands

; Initialize output arrays for vertical grid
thick = dblarr(nb)
area = dblarr(nb)
width = dblarr(nb)
elev = dblarr(nb)
gl = dblarr(nb) + noval ; Initialize with no-data value
length = dblarr(nb) ; Length of glacier in each elevation band

; Find ice-covered horizontal cells
ice_idx = where(th_x gt 0.01, ice_count)

if ice_count gt 3 then begin ; Need at least 3 points for meaningful interpolation

  ; Get ice-covered data only
  sur_ice = sur_x[ice_idx]
  th_ice = th_x[ice_idx]
  width_ice = width_surface[ice_idx]

  ; Sort by surface elevation for proper interpolation
  sort_idx = sort(sur_ice)
  sur_sorted = sur_ice[sort_idx]
  th_sorted = th_ice[sort_idx]
  width_sorted = width_ice[sort_idx]

  ; Remove duplicates more carefully
  unique_idx = uniq(sur_sorted, sort(sur_sorted))
  sur_unique = sur_sorted[unique_idx]
  th_unique = th_sorted[unique_idx]
  width_unique = width_sorted[unique_idx]

  ; Check if we have enough unique points
  if n_elements(sur_unique) lt 3 then begin
    print, 'Warning: Not enough unique elevation points for interpolation'
    thick = dblarr(nb)
    width = dblarr(nb)
    area = dblarr(nb)
    length = dblarr(nb)
    elev = bed_elev
  endif else begin
    ; Find elevation range with ice
    min_ice_elev = min(sur_unique)
    max_ice_elev = max(sur_unique)

    ; Initialize all values to zero
    thick = dblarr(nb)
    width = dblarr(nb)

    ; Only interpolate for elevation bands within the ice range
    valid_bands = where((elev0 ge min_ice_elev) and (elev0 le max_ice_elev), count_valid)

    if count_valid gt 0 then begin
      ; Interpolate only for valid elevation bands
      thick[valid_bands] = interpol(th_unique, sur_unique, elev0[valid_bands])
      width[valid_bands] = interpol(width_unique, sur_unique, elev0[valid_bands])

      ; Clean up negative or very small values
      thin_idx = where(thick lt 0.01, count_thin)
      if count_thin gt 0 then begin
        thick[thin_idx] = 0.0
        width[thin_idx] = 0.0
      endif

      ; Limit maximum thickness to reasonable values
      max_reasonable_thickness = 3.0 * max(th_unique) ; 3x max observed thickness
      too_thick = where(thick gt max_reasonable_thickness, count_thick)
      if count_thick gt 0 then begin
        print, 'Warning: Capping unrealistic thickness values'
        thick[too_thick] = max_reasonable_thickness
      endif
    endif

    ; Calculate area
    step = 10.0
    area = width * step

    ; Calculate length (distance from terminus) - decreases with elevation
    total_length = max(x) / 1000.0 ; total glacier length in km
    min_elev = min(elev0)
    max_elev = max(elev0)
    total_elev_range = max_elev - min_elev

    for j = 0, nb - 1 do begin
      ; Distance decreases with elevation (max at headwall, 0 at terminus)
      elev_fraction = (max_elev - elev0[j]) / total_elev_range
      length[j] = elev_fraction * total_length
    endfor

    ; Ensure the last element (terminus) is exactly 0
    length[nb - 1] = 0.0

    ; Set surface elevation
    elev = elev0 + thick / 2.0
  endelse
endif else begin
  ; Insufficient ice coverage
  thick = dblarr(nb)
  width = dblarr(nb)
  area = dblarr(nb)
  length = dblarr(nb)
  elev = bed_elev
endelse

; Set glacier surface elevation (gl) where ice exists
ice_bands = where(thick gt 0.01, count_ice)
if count_ice gt 0 then begin
  gl[ice_bands] = elev[ice_bands]
endif else begin
  gl[*] = noval
endelse

; Ensure consistency: where there's no ice, surface equals bedrock
no_ice = where(thick le 0.01, count_no_ice)
if count_no_ice gt 0 then begin
  elev[no_ice] = bed_elev[no_ice]
  area[no_ice] = 0.0
  ; Note: length is NOT set to 0 for no-ice bands - it represents domain distance
  gl[no_ice] = noval
endif

; Add diagnostic output
print, 'Robust interpolation-based conversion from horizontal to vertical grid:'
print, 'elev0 range:', min(elev0), ' to ', max(elev0)
print, 'sur_x range:', min(sur_x), ' to ', max(sur_x)
print, 'Ice-bearing horizontal cells:', ice_count
print, 'Ice-bearing elevation bands:', n_elements(where(thick gt 0.01))

; Fix the elevation range with ice output
ice_bands_check = where(thick gt 0.01, count_ice_check)
if count_ice_check gt 0 then begin
  print, 'Elevation range with ice:', min(elev0[ice_bands_check]), ' to ', max(elev0[ice_bands_check])
  print, 'Max thickness observed:', max(thick[ice_bands_check])
endif else begin
  print, 'Elevation range with ice: No ice present'
endelse

; Conservation check (optional - comment out for production runs)
if ice_count gt 0 then begin
  ; Calculate area using horizontal grid resolution
  area_x = width_surface * dx
  horizontal_volume = total(th_x * area_x)
  vertical_volume = total(thick * area)
  horizontal_area = total(area_x[ice_idx])
  vertical_area = total(area)

  print, 'Volume conservation:'
  print, '  Horizontal grid volume:', horizontal_volume
  print, '  Vertical grid volume:', vertical_volume
  if horizontal_volume gt 0 then begin
    print, '  Volume error (%):', (vertical_volume - horizontal_volume) / horizontal_volume * 100
  endif

  print, 'Area conservation:'
  print, '  Horizontal grid area:', horizontal_area
  print, '  Vertical grid area:', vertical_area
  if horizontal_area gt 0 then begin
    print, '  Area error (%):', (vertical_area - horizontal_area) / horizontal_area * 100
  endif
endif
