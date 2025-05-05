function import_glacier_smb, filename, startRow, endRow
  compile_opt idl2
  ;+
  ; NAME:
  ;    import_glacier_smb
  ;
  ; PURPOSE:
  ;    Import numeric data from a text file as a 2D array.
  ;
  ; CALLING SEQUENCE:
  ;    belev = import_glacier_smb(filename [, startRow [, endRow]])
  ;
  ; INPUTS:
  ;    filename - String containing the path to the file to be read
  ;
  ; OPTIONAL INPUTS:
  ;    startRow - Row number to start reading from (default: 1)
  ;    endRow   - Row number to end reading at (default: all rows)
  ;
  ; OUTPUTS:
  ;    belev - 2D array of the numeric data read from the file
  ;
  ; EXAMPLE:
  ;    belev00001 = import_glacier_smb('belev_00001.dat', 1, 16)
  ;-

  ; Initialize variables
  delimiter = ' '

  ; Set default values for startRow and endRow if not provided
  if n_params() lt 2 then startRow = 2 ; IDL is 0-based but we want to start from header line (1)
  if n_params() lt 3 then endRow = 0 ; 0 means read all rows

  ; Open the file
  openr, lun, filename, /get_lun, error = err
  if err ne 0 then begin
    message, 'Error opening file: ' + filename
    RETURN, -1
  endif

  ; Skip header lines (startRow-1)
  if startRow gt 1 then begin
    header = ''
    for i = 0, startRow - 2 do begin
      readf, lun, header
    endfor
  endif

  ; Read all lines from the file into a string array
  lines = ''
  if endRow gt 0 then begin
    ; Read specified number of rows
    data_lines = strarr(endRow - startRow + 1)
    for i = 0, (endRow - startRow) do begin
      readf, lun, lines
      data_lines[i] = lines
    endfor
  endif else begin
    ; Read all rows until end of file
    data_lines = ''
    while ~eof(lun) do begin
      readf, lun, lines
      data_lines = [data_lines, lines]
    endwhile

    ; Remove the initial empty entry
    if data_lines[0] eq '' then data_lines = data_lines[1 : *]
  endelse

  ; Close the file
  free_lun, lun

  ; Determine the number of rows and columns
  n_rows = n_elements(data_lines)

  ; Create a temporary array to hold string values from each line
  temp_values = strsplit(data_lines[0], delimiter, /extract)
  n_cols = n_elements(temp_values)

  ; Create the output array
  belev = dblarr(n_cols, n_rows)

  ; Parse each line and fill the output array
  for i = 0, n_rows - 1 do begin
    ; Skip the header line (first line with column names)
    if i eq 0 and strmatch(data_lines[0], '*Elev*') then continue

    ; Split the line by the delimiter
    values = strsplit(strtrim(data_lines[i], 2), delimiter, /extract)

    ; Convert string values to doubles and store in output array
    ; Skip empty entries that might exist after splitting
    n_values = n_elements(values)
    for j = 0, n_values - 1 < (n_cols - 1) do begin
      if values[j] ne '' then belev[j, i] = double(values[j])
    endfor
  endfor

  ; Return the final array (transposed to match MATLAB's format)
  RETURN, transpose(belev)
end
