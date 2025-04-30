; IDL translation of stats.m
compile_opt idl2

; Close all graphics windows
while (!d.window ne -1) do wdelete

t_start = systime(/seconds)

data_glaciers = fltarr(3927, 3)

; Read RGI data - note: you'll need to create an equivalent import_rgi_data function in IDL
data_rgi = import_rgi_data('rgi/11_rgi60_CentralEurope.csv')
restore, 'inventory_date.sav'

for glacier_id = 1, 3927 do begin ; Range over which geometry files exist
  print, 'Processing glacier ID: ', glacier_id

  ; You'll need to create an equivalent import_glacier_geometry_1d function in IDL
  filename = string(glacier_id, format = '("flowline_geom/",I05,".dat")')
  glacier_geom = import_glacier_geometry_1d(filename)

  length_array = n_elements(glacier_geom[*, 0])
  data_glaciers[glacier_id - 1, 0] = glacier_geom[length_array - 1, 7] / 1000.0 ; Glacier length (km)
  data_glaciers[glacier_id - 1, 1] = total(glacier_geom[*, 4]) ; Glacier area (km^2)

  vol = 0.0
  for i = 0, length_array - 1 do begin
    vol = vol + glacier_geom[i, 4] * glacier_geom[i, 5] / 1000.0 ; area*thick
  endfor

  data_glaciers[glacier_id - 1, 2] = vol ; Glacier volume (km^3)
endfor

; Create plots
w1 = window(dimensions = [800, 600])
p1 = plot(data_glaciers[*, 0], symbol = 'o', /current, $
  xtitle = 'Glacier ID', ytitle = 'Length (km)', $
  font_size = 18, grid = 1)

w2 = window(dimensions = [800, 600])
p2 = plot(data_glaciers[*, 1], symbol = 'o', /current, $
  xtitle = 'Glacier ID', ytitle = 'Area (km^2)', $
  font_size = 18, grid = 1)

w3 = window(dimensions = [800, 600])
p3 = plot(data_glaciers[*, 2], symbol = 'o', /current, $
  xtitle = 'Glacier ID', ytitle = 'Volume (km^3)', $
  font_size = 18, grid = 1)

; Subdivide in category:
index_larger_than_1_km_glaciers = where(data_glaciers[*, 0] gt 1, /null)
index_larger_than_1_km2_glaciers = where(data_glaciers[*, 1] gt 1, /null)
index_larger_than_1_km3_glaciers = where(data_glaciers[*, 2] gt 1, /null)
index_smaller_than_1_km_glaciers = where(data_glaciers[*, 0] lt 1, /null)
index_2003inventorydate_glaciers = where(inventory_date eq 2003, /null)

; Calculate some areas and volume
area_total = total(data_glaciers[*, 1])
print, 'Area total: ', area_total
area_larger_than_1_km_glaciers = total(data_glaciers[index_larger_than_1_km_glaciers, 1])
print, 'Area larger than 1 km glaciers: ', area_larger_than_1_km_glaciers
area_larger_than_1_km2_glaciers = total(data_glaciers[index_larger_than_1_km2_glaciers, 1])
print, 'Area larger than 1 km^2 glaciers: ', area_larger_than_1_km2_glaciers
area_larger_than_1_km3_glaciers = total(data_glaciers[index_larger_than_1_km3_glaciers, 1])
print, 'Area larger than 1 km^3 glaciers: ', area_larger_than_1_km3_glaciers
area_2003inventorydate_glacier = total(data_glaciers[index_2003inventorydate_glaciers, 1])
print, 'Area 2003 inventory date glaciers: ', area_2003inventorydate_glacier

vol_total = total(data_glaciers[*, 2])
print, 'Volume total: ', vol_total
vol_larger_than_1_km_glaciers = total(data_glaciers[index_larger_than_1_km_glaciers, 2])
print, 'Volume larger than 1 km glaciers: ', vol_larger_than_1_km_glaciers
vol_larger_than_1_km2_glaciers = total(data_glaciers[index_larger_than_1_km2_glaciers, 2])
print, 'Volume larger than 1 km^2 glaciers: ', vol_larger_than_1_km2_glaciers
vol_larger_than_1_km3_glaciers = total(data_glaciers[index_larger_than_1_km3_glaciers, 2])
print, 'Volume larger than 1 km^3 glaciers: ', vol_larger_than_1_km3_glaciers
vol_2003inventorydate_glacier = total(data_glaciers[index_2003inventorydate_glaciers, 2])
print, 'Volume 2003 inventory date glaciers: ', vol_2003inventorydate_glacier

; Before saving: prepare arrays for saving
index_larger_than_1_km_glaciers_save = index_larger_than_1_km_glaciers
index_larger_than_1_km2_glaciers_save = index_larger_than_1_km2_glaciers
index_larger_than_1_km3_glaciers_save = index_larger_than_1_km3_glaciers
index_smaller_than_1_km_glaciers_save = index_smaller_than_1_km_glaciers

; Find glaciers longer than 1 km but smaller than 1 km^2
counter = 0
index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save = []

for i = 0, n_elements(index_larger_than_1_km_glaciers_save) - 1 do begin
  z = where(index_larger_than_1_km2_glaciers_save eq index_larger_than_1_km_glaciers_save[i], count)
  if count eq 0 then begin
    if counter eq 0 then begin
      index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save = [index_larger_than_1_km_glaciers_save[i]]
    endif else begin
      index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save = [index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save, $
        index_larger_than_1_km_glaciers_save[i]]
    endelse
    counter++
  endif
endfor

; Save variables to a .sav file
save, index_larger_than_1_km_glaciers_save, $
  index_larger_than_1_km2_glaciers_save, $
  index_larger_than_1_km3_glaciers_save, $
  index_smaller_than_1_km_glaciers_save, $
  index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save, $
  filename = 'glacier_stats.sav'

t_elapsed = systime(/seconds) - t_start
print, 'Elapsed time: ', t_elapsed, ' seconds'
end
