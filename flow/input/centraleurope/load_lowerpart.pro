; Load lower part script - IDL translation from MATLAB
; Close all graphics windows
compile_opt idl2
while (!d.window ne -1) do wdelete

; Clear variables (IDL doesn't need this explicitly, but including for clarity)
; IDL doesn't have direct equivalents to MATLAB's clear/clc

; getting the directory of the current script
routine_path = routine_filepath()
script_path = file_dirname(routine_path)

; Load glacier stats file
restore, script_path + '/glacier_stats.sav' ; Load indices of glaciers

; Define which glacier IDs to process
; id = index_larger_than_1_km2_glaciers_save
id = indgen(28) + 3900 ; Equivalent to 3900:3927 in MATLAB
id_start = 0
id_end = 5000

; Filter IDs based on start/end range
indices = where(id ge id_start and id le id_end, count)
if count gt 0 then begin
  id = id[indices]
endif else begin
  print, 'No glacier IDs in specified range'
  RETURN
endelse

; Set up parallel processing flag
core_flag = 1 ; X = number of cores (1 = serial, >1 = parallel)

; IDL doesn't have built-in parallel processing like MATLAB
; We'll use a simple loop for all cases, but note that IDL
; has the THREAD pool functionality in newer versions

; Process each glacier ID
num_ids = n_elements(id)
for i = 0, num_ids - 1 do begin
  glacier_id = id[i]

  ; Call the processing function with parameters
  ; equivalent to: load_lowerpart_function(glacier_id, 5, 8)
  print, 'Processing glacier ID: ', glacier_id
  load_lowerpart_function(glacier_id, 5, 8)
endfor

print, 'Processing complete'
