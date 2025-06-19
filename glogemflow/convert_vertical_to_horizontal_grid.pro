
print, 'TEST'

glacier_geom = import_glacier_geometry(fn)

print, 'The file we want to open =', fn
print, glacier_geom

; parameters (25% of the total lenght is added in the front)
frontal_length = 1.0/4.0

; ; Determine the original horizontal resolution in data Matthias (not equidistant, as is derived from elevation bands and slope between them!)
length_glacier_geom = n_elements(glacier_geom[*, 0])
dx_original = fltarr(length_glacier_geom)
for i = 1, length_glacier_geom - 1 do begin
    dx_original[i] = glacier_geom[i, 6] - glacier_geom[i - 1, 6]
endfor

; Interpolation to a horizontally regular (i.e. equidistant) grid
dx_bin = glacier_geom[*,6] ; bin size in x-direction
gl_length = dx_bin[-1] ; total length of the glacier grid in x-direction (glacier length)
dx = round(gl_length / 100)

grid_cells = floor(glacier_geom[length_glacier_geom - 1, 6] / dx)

x = findgen(grid_cells) * dx + dx

glacier_geom_lookup_x = glacier_geom[*, 6] ; Distance along the flowline (m)
glacier_geom_lookup_sur = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2 ; Surface elevation (m)
glacier_geom_lookup_width = glacier_geom[*, 5] ; Width (m)
glacier_geom_lookup_th = glacier_geom[*, 4] ; Thickness (m)

i = where(glacier_geom_lookup_width eq 0, count) ; Remove elevation bands with no ice
if count gt 0 then begin
    good_indices = where(glacier_geom_lookup_width ne 0)
    glacier_geom_lookup_x = glacier_geom_lookup_x[good_indices]
    glacier_geom_lookup_sur = glacier_geom_lookup_sur[good_indices]
    glacier_geom_lookup_width = glacier_geom_lookup_width[good_indices]
    glacier_geom_lookup_th = glacier_geom_lookup_th[good_indices]
endif

sur_x = interpol(glacier_geom_lookup_sur, glacier_geom_lookup_x, x)       ; Surface elevation (linear interpolation)
width_x = interpol(glacier_geom_lookup_width, glacier_geom_lookup_x, x)   ; Width (linear interpolation)
i = where(x lt glacier_geom_lookup_x[0], count)
if count gt 0 then width_x[i] = glacier_geom_lookup_width[0]

th_x = interpol(glacier_geom_lookup_th, glacier_geom_lookup_x, x)
i = where(x lt glacier_geom_lookup_x[0], count)
if count gt 0 then th_x[i] = glacier_geom_lookup_th[0] ; Thickness for cells lower than first point on Huss grid: same as thickness first point Huss grid
bed_x = sur_x - th_x


; ; Check how much the volume and area have changed:
volume_Huss_1d = total((glacier_geom[*, 3] * 1e6) * glacier_geom[*, 4])
print, 'volume_Huss_1d = ', volume_Huss_1d
volume_Huss_1d_fixeddistance = total(width_x * th_x * dx)
print, 'volume_Huss_1d_fixeddistance = ', volume_Huss_1d_fixeddistance
area_Huss_1d = total(glacier_geom[*, 3] * 1e6)
print, 'area_Huss_1d = ', area_Huss_1d
area_Huss_1d_fixeddistance = total(width_x * dx)
print, 'area_Huss_1d_fixeddistance = ', area_Huss_1d_fixeddistance
i = where(th_x gt 1, count)
length_fixeddistance = count * dx

difference_volume = volume_Huss_1d_fixeddistance - volume_Huss_1d
print, 'difference_volume = ', difference_volume
print, 'difference_in_percentage = ', (difference_volume / volume_Huss_1d) * 100, '%'
