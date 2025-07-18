compile_opt idl2
; print, 'TEST'

; Import glacier geometry data
glacier_geom = import_glacier_geometry(fn)

; parameters (25% of the total lenght is added in the front)
frontal_length = 1.0 / 4.0

; ; Determine the original horizontal resolution in data Matthias (not equidistant, as is derived from elevation bands and slope between them!)
length_glacier_geom = n_elements(glacier_geom[*, 0])
dx_original = fltarr(length_glacier_geom)
for i = 1, length_glacier_geom - 1 do begin
  dx_original[i] = glacier_geom[i, 6] - glacier_geom[i - 1, 6]
endfor

; Interpolation to a horizontally regular (i.e. equidistant) grid
dx_bin = glacier_geom[*, 6] ; bin size in x-direction
gl_length = dx_bin[-1] ; total length of the glacier grid in x-direction (glacier length)
dx = round(gl_length / 100)

; Create a new grid with equidistant spacing
grid_cells = floor(glacier_geom[length_glacier_geom - 1, 6] / dx) ; number of grid cells
dist_dx_init = findgen(grid_cells) * dx + dx ; x-coordinates of the new grid (m)

; Create arrays to look up the Huss glacier geometry
dist_dz_init = glacier_geom[*, 6] ; Lookup Distance along the flowline (m)
sur_dz_init = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2 ; Lookup Surface elevation (m)
width_dz_init = glacier_geom[*, 5] ; Lookup Width (m)
thick_dz_init = glacier_geom[*, 4] ; Lookup Thickness (m)

; Remove elevation bands with no ice
i = where(width_dz_init eq 0, count)
if count gt 0 then begin
  good_indices = where(width_dz_init ne 0)
  dist_dz_init = dist_dz_init[good_indices]
  sur_dz_init = sur_dz_init[good_indices]
  width_dz_init = width_dz_init[good_indices]
  thick_dz_init = thick_dz_init[good_indices]
endif

; Perform linear interpolation for surface elevation, width, and thickness to generate a horizontally equidistant grid
sur_dx_init = interpol(sur_dz_init, dist_dz_init, dist_dx_init) ; Surface elevation (linear interpolation)
width_dx_init = interpol(width_dz_init, dist_dz_init, dist_dx_init) ; Width (linear interpolation)
i = where(dist_dx_init lt dist_dz_init[0], count)
if count gt 0 then width_dx_init[i] = width_dz_init[0]

thick_dx_init = interpol(thick_dz_init, dist_dz_init, dist_dx_init) ; Thickness (linear interpolation)
i = where(dist_dx_init lt dist_dz_init[0], count)
if count gt 0 then thick_dx_init[i] = thick_dz_init[0] ; Thickness for cells lower than first point on Huss grid: same as thickness first point Huss grid
bed_dx_init = sur_dx_init - thick_dx_init ; Bedrock elevation (m)

; Find indices where sur_dx_init is within the range of sur_dz_init
valid_idx = where((sur_dx_init ge min(sur_dz_init)) and (sur_dx_init le max(sur_dz_init)), count)

if count gt 0 then begin
  sur_dx_init = sur_dx_init[valid_idx]
  dist_dx_init = dist_dx_init[valid_idx]
  width_dx_init = width_dx_init[valid_idx]
  thick_dx_init = thick_dx_init[valid_idx]
  bed_dx_init = bed_dx_init[valid_idx]
endif

; ; Check how much the volume and area have changed:
volume_Huss_1d = total((glacier_geom[*, 3] * 1e6) * glacier_geom[*, 4])
; print, 'volume_Huss_1d = ', volume_Huss_1d
volume_Huss_1d_fixeddistance = total(width_dx_init * thick_dx_init * dx)
; print, 'volume_Huss_1d_fixeddistance = ', volume_Huss_1d_fixeddistance
area_Huss_1d = total(glacier_geom[*, 3] * 1e6)
; print, 'area_Huss_1d = ', area_Huss_1d
area_Huss_1d_fixeddistance = total(width_dx_init * dx)
; print, 'area_Huss_1d_fixeddistance = ', area_Huss_1d_fixeddistance
i = where(thick_dx_init gt 1, count)
length_fixeddistance = count * dx

difference_volume = volume_Huss_1d_fixeddistance - volume_Huss_1d
; print, 'difference_volume = ', difference_volume
; print, 'difference_in_percentage = ', (difference_volume / volume_Huss_1d) * 100, '%'

horizontal_grid_inputs = {dist_dx: dist_dx_init, sur_dx: sur_dx_init, width_dx: width_dx_init, thick_dx: thick_dx_init, bed_dx: bed_dx_init}
save, horizontal_grid_inputs, file = 'horizontal_grid_inputs.sav'
