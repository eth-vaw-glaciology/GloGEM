function import_rgi_data, filename, startRow, endRow
  compile_opt idl2
  ; IMPORTFILE Import numeric data from a text file as a matrix.
  ; RGI60CENTRALEUROPE = IMPORTFILE(FILENAME) Reads data from text file
  ; FILENAME for the default selection.
  ;
  ; RGI60CENTRALEUROPE = IMPORTFILE(FILENAME, STARTROW, ENDROW) Reads data
  ; from rows STARTROW through ENDROW of text file FILENAME.
  ;
  ; Example:
  ; rgi60CentralEurope = import_rgi_data('11_rgi60_CentralEurope.csv', 2, 3928)

  ; Initialize variables.
  delimiter = ','
  if n_params() le 2 then begin
    if n_elements(startRow) eq 0 then startRow = 2
    endRow = !values.f_infinity
  endif

  ; Open the text file.
  openr, lun, filename, /get_lun

  ; Skip header lines
  linecount = file_lines(filename)
  if linecount lt startRow then begin
    message, 'Not enough lines in file'
    RETURN, -1
  endif

  ; If endRow is infinite, set to actual number of lines
  if endRow eq !values.f_infinity then endRow = linecount

  ; Calculate number of lines to read
  numLines = endRow - startRow + 1

  ; Skip header lines
  line = ''
  for i = 0, startRow - 2 do begin
    readf, lun, line
  endfor

  ; Read the data lines
  lines = strarr(numLines)
  for i = 0, numLines - 1 do begin
    readf, lun, line
    lines[i] = line
  endfor

  ; Close the file
  free_lun, lun

  ; Parse the CSV data into a 2D array
  dataArray = strarr(6, numLines)
  for i = 0, numLines - 1 do begin
    ; Split line by delimiter
    parts = strsplit(lines[i], delimiter, /extract)

    ; Handle case where line might have fewer than 6 fields
    n_fields = n_elements(parts) < 6 ? n_elements(parts) : 6
    dataArray[0 : n_fields - 1, i] = parts[0 : n_fields - 1]
  endfor

  ; Convert the contents of columns to numbers
  numericData = fltarr(6, numLines)
  numericData[*, *] = !values.f_nan ; Initialize with NaN

  for col = 0, 5 do begin
    for row = 0, numLines - 1 do begin
      ; Process each value to extract numeric portion
      value = strtrim(dataArray[col, row], 2)

      ; Try to convert to number
      on_ioerror, skip_conversion

      ; Check for commas and remove them
      value = strjoin(strsplit(value, ',', /extract), '')

      ; Convert to float
      numericData[col, row] = float(value)
      continue

      skip_conversion:
      ; If conversion fails, leave as NaN
      numericData[col, row] = !values.f_nan
    endfor
  endfor

  ; Transpose to match MATLAB's format (rows x columns)
  rgi60CentralEurope = transpose(numericData)

  RETURN, rgi60CentralEurope
end
