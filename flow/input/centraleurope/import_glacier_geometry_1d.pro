function import_glacier_geometry_1d, filename, startRow, endRow
  ;+
  ; :Description:
  ;   Imports numeric data from a text file as a matrix.
  ;
  ; :Params:
  ;   filename : in, required, type=string
  ;     Path to the file to be read
  ;   startRow : in, optional, type=integer, default=6
  ;     First row to read
  ;   endRow : in, optional, type=integer, default=infinity
  ;     Last row to read
  ;
  ; :Returns:
  ;   A 2D array containing the numeric data
  ;
  ; :Example:
  ;   data = import_glacier_geometry_1d('01328.dat', 6, 205)
  ;-

  compile_opt idl2

  ; Initialize variables
  if n_params() le 2 then begin
    if n_elements(startRow) eq 0 then startRow = 6
    endRow = !values.f_infinity
  endif

  ; Open the text file
  openr, lun, filename, /get_lun

  ; Check if there are enough lines in the file
  linecount = file_lines(filename)
  if linecount lt startRow then begin
    print, 'Error: Not enough lines in file'
    free_lun, lun
    free_lun, lun
    return, -1
  endif

  ; If endRow is infinite, set to actual number of lines
  if endRow eq !values.f_infinity then endRow = linecount

  ; Calculate number of lines to read
  num_lines = endRow - startRow + 1

  ; Skip header lines by reading and discarding them
  line = ''
  for i = 0, startRow - 2 do begin
    readf, lun, line
  endfor

  ; Create output array for the fixed-width data (12 columns)
  result = fltarr(12, num_lines)
  ; Initialize with NaN to identify unconverted values
  result[*, *] = !values.f_nan

  ; Read all data lines first into a string array
  lines = strarr(num_lines)
  for i = 0, num_lines - 1 do begin
    readf, lun, line
    lines[i] = line
  endfor

  ; Close the file since we've read all data
  free_lun, lun

  ; Parse the fixed-width data into a 2D array
  for i = 0, num_lines - 1 do begin
    ; Define the field widths for the glacier data format
    field_widths = [4, 8, 8, 11, 10, 10, 10, 6, 4, 8, 7, 0] ; last is remainder

    ; Get the current line
    line = lines[i]

    ; Process each field
    start_pos = 0
    for j = 0, 10 do begin ; Handle first 11 fields with fixed width
      ; Extract field
      field = strmid(line, start_pos, field_widths[j])

      ; Trim whitespace and convert to float
      field = strtrim(field, 2)
      if field ne '' then begin
        result[j, i] = float(field)
      endif

      ; Move to next field position
      start_pos += field_widths[j]
    endfor

    ; Handle the last field (remainder of line)
    field = strmid(line, start_pos)
    field = strtrim(field, 2)
    if field ne '' then begin
      result[11, i] = float(field)
    endif
  endfor

  ; Close the file
  free_lun, lun

  ; Return the result
  RETURN, transpose(result)
end
