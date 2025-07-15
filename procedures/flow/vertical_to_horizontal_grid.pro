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
x = findgen(grid_cells) * dx + dx ; x-coordinates of the new grid (m)

; Create arrays to look up the Huss glacier geometry
glacier_geom_lookup_x = glacier_geom[*, 6] ; Lookup Distance along the flowline (m)
glacier_geom_lookup_sur = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2 ; Lookup Surface elevation (m)
glacier_geom_lookup_width = glacier_geom[*, 5] ; Lookup Width (m)
glacier_geom_lookup_th = glacier_geom[*, 4] ; Lookup Thickness (m)

; Remove elevation bands with no ice
i = where(glacier_geom_lookup_width eq 0, count)
if count gt 0 then begin
  good_indices = where(glacier_geom_lookup_width ne 0)
  glacier_geom_lookup_x = glacier_geom_lookup_x[good_indices]
  glacier_geom_lookup_sur = glacier_geom_lookup_sur[good_indices]
  glacier_geom_lookup_width = glacier_geom_lookup_width[good_indices]
  glacier_geom_lookup_th = glacier_geom_lookup_th[good_indices]
endif

; Perform linear interpolation for surface elevation, width, and thickness to generate a horizontally equidistant grid
sur_x_input = interpol(glacier_geom_lookup_sur, glacier_geom_lookup_x, x) ; Surface elevation (linear interpolation)
width_x_input = interpol(glacier_geom_lookup_width, glacier_geom_lookup_x, x) ; Width (linear interpolation)
i = where(x lt glacier_geom_lookup_x[0], count)
if count gt 0 then width_x_input[i] = glacier_geom_lookup_width[0]

th_x_input = interpol(glacier_geom_lookup_th, glacier_geom_lookup_x, x) ; Thickness (linear interpolation)
i = where(x lt glacier_geom_lookup_x[0], count)
if count gt 0 then th_x_input[i] = glacier_geom_lookup_th[0] ; Thickness for cells lower than first point on Huss grid: same as thickness first point Huss grid
bed_x_input = sur_x_input - th_x_input ; Bedrock elevation (m)

; ; Check how much the volume and area have changed:
volume_Huss_1d = total((glacier_geom[*, 3] * 1e6) * glacier_geom[*, 4])
; print, 'volume_Huss_1d = ', volume_Huss_1d
volume_Huss_1d_fixeddistance = total(width_x_input * th_x_input * dx)
; print, 'volume_Huss_1d_fixeddistance = ', volume_Huss_1d_fixeddistance
area_Huss_1d = total(glacier_geom[*, 3] * 1e6)
; print, 'area_Huss_1d = ', area_Huss_1d
area_Huss_1d_fixeddistance = total(width_x_input * dx)
; print, 'area_Huss_1d_fixeddistance = ', area_Huss_1d_fixeddistance
i = where(th_x_input gt 1, count)
length_fixeddistance = count * dx

difference_volume = volume_Huss_1d_fixeddistance - volume_Huss_1d
; print, 'difference_volume = ', difference_volume
; print, 'difference_in_percentage = ', (difference_volume / volume_Huss_1d) * 100, '%'

horizontal_grid_inputs = {x: x, sur_x_input: sur_x_input, width_x_input: width_x_input, th_x_input: th_x_input, bed_x_input: bed_x_input}
save, horizontal_grid_inputs, file = 'horizontal_grid_inputs.sav'
