; Close any open windows and clear memory in IDL
compile_opt idl2

; Import RGI data
data = import_rgi_data('rgi/11_rgi60_CentralEurope.csv')
i = where(data eq -9999999, count)
if count gt 0 then data[i] = !values.f_nan

; Create date array
date = fltarr(n_elements(data[*, 0]))

; Process dates
for i = 0, n_elements(date) - 1 do begin
  date_start = data[i, 2] ; Adjusted for 0-based indexing
  date_end = data[i, 3] ; Adjusted for 0-based indexing

  ; Calculate mean, handling NaN values
  if finite(date_start) and finite(date_end) then begin
    date[i] = (date_start + date_end) / 2.0
  endif else if finite(date_start) then begin
    date[i] = date_start
  endif else if finite(date_end) then begin
    date[i] = date_end
  endif else begin
    date[i] = !values.f_nan
  endelse

  ; If unknown, take inventory date from previous glacier
  if ~finite(date[i]) then begin
    if i gt 0 then date[i] = date[i - 1]
  endif
endfor

; Round to year
inventory_date = round(date / 10000)
print, 'inventory_date = ', inventory_date

; Save to .dat file in the specified directory
home_dir = file_dirname(file_expand_path('inventorydate.pro'))
file_path = home_dir + '/flow/input/' + region + '/inventory_date.dat'
openw, unit, file_path, /get_lun
for i = 0, n_elements(inventory_date) - 1 do printf, unit, inventory_date[i]
free_lun, unit
