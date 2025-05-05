function gridread, filename, startRow, endRow
  compile_opt idl2
  ;+
  ; NAME:
  ;   gridread
  ;
  ; PURPOSE:
  ;   Import numeric data from a text file as an array.
  ;
  ; CALLING SEQUENCE:
  ;   dem = gridread(filename [, startRow, endRow])
  ;
  ; INPUTS:
  ;   filename - String containing the path to the text file
  ;   startRow - Optional. First row to read (default=1)
  ;   endRow   - Optional. Last row to read (default=all rows)
  ;
  ; OUTPUTS:
  ;   dem - 2D array containing the imported numeric data
  ;
  ; EXAMPLE:
  ;   dem = gridread('dem.grid', 1, 24316)
  ;-

  ; Initialize variables
  if n_params() lt 3 then begin
    if n_params() lt 2 then startRow = 1
    endRow = !values.f_infinity
  endif

  ; Open the text file
  openr, fileID, filename, /get_lun

  ; Count the number of lines in the file if endRow is infinity
  if endRow eq !values.f_infinity then begin
    count = 0l
    line = ''
    while not eof(fileID) do begin
      readf, fileID, line
      count++
    endwhile
    endRow = count
    point_lun, fileID, 0 ; Reset to beginning of file
  endif

  ; Skip header lines
  if startRow gt 1 then begin
    line = ''
    for i = 1, startRow - 1 do readf, fileID, line
  endif

  ; Read the data
  num_lines = endRow - startRow + 1
  data = strarr(5, num_lines)

  for i = 0, num_lines - 1 do begin
    line = ''
    readf, fileID, line

    ; Split the line into columns (assuming fixed width format)
    if strlen(line) ge 64 then begin
      data[0, i] = strmid(line, 0, 16)
      data[1, i] = strmid(line, 16, 16)
      data[2, i] = strmid(line, 32, 16)
      data[3, i] = strmid(line, 48, 16)
      data[4, i] = strmid(line, 64)
    endif else begin
      ; Handle possible short lines
      parts = strsplit(line, /extract)
      for j = 0, n_elements(parts) - 1 < 4 do data[j, i] = parts[j]
    endelse
  endfor

  ; Close the file
  free_lun, fileID

  ; Convert string data to numeric values
  numericData = dblarr(5, num_lines)

  for col = 0, 4 do begin
    for row = 0, num_lines - 1 do begin
      ; Trim spaces
      val = strtrim(data[col, row], 2)

      ; Try to convert to numeric
      on_ioerror, bad_numeric
      numericData[col, row] = double(val)
      continue

      bad_numeric:numericData[col, row] = !values.d_nan
    endfor
  endfor

  ; Return the numeric data
  RETURN, numericData
end
