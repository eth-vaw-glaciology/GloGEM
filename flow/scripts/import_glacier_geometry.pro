function import_glacier_geometry, filename, startRow, endRow
  compile_opt idl2
  ; ; Import numeric data from a text file as a matrix.
  ; ;   RESULT = IMPORT_GLACIER_GEOMETRY(FILENAME) Reads data from text file FILENAME for
  ; ;   the default selection.
  ; ;
  ; ;   RESULT = IMPORT_GLACIER_GEOMETRY(FILENAME, STARTROW, ENDROW) Reads data from rows
  ; ;   STARTROW through ENDROW of text file FILENAME.
  ; ;
  ; ; Example:
  ; ;   result = import_glacier_geometry('01328.dat', 6, 205)
  ;
  ; ; returns:
  ; ;   2D array with 12 columns:
  ; ;   band_id, elev_start, elev_end, area, thickness, width, length,
  ; ;   slope, aspect, b_app, basal_stress, shape_factor

  ; Set default start row if not provided
  if n_elements(startRow) eq 0 then startRow = 6

  ; Set default endRow to infinity if not provided
  if n_elements(endRow) eq 0 then endRow = !values.f_infinity

  ; Check if file exists
  if ~file_test(filename) then begin
    print, 'Error: File does not exist: ' + filename
    return, -1
  endif

  ; Get the total number of lines in the file
  n_lines = file_lines(filename)

  ; If endRow is not specified or is infinity, read until end of file
  if n_elements(endRow) eq 0 or endRow eq !values.f_infinity then begin
    endRow = n_lines
  endif

  ; Calculate number of data rows to read
  n_data_rows = (endRow - startRow + 1) > 0

  ; Read the file using READCOL (more straightforward for tabular data)
  band_id = intarr(n_data_rows)
  elev_start = dblarr(n_data_rows)
  elev_end = dblarr(n_data_rows)
  area = dblarr(n_data_rows)
  thickness = dblarr(n_data_rows)
  width = dblarr(n_data_rows)
  length = dblarr(n_data_rows)
  slope = dblarr(n_data_rows)
  aspect = intarr(n_data_rows)
  b_app = dblarr(n_data_rows)
  basal_stress = dblarr(n_data_rows)
  shape_factor = dblarr(n_data_rows)

  ; Open the file for reading
  openr, lun, filename, /get_lun

  ; Skip header lines
  header = ''
  for i = 1, startRow - 1 do readf, lun, header

  ; Read data rows
  line = ''
  for i = 0, n_data_rows - 1 do begin
    if eof(lun) then break

    readf, lun, line

    ; Parse the line
    parts = strsplit(strtrim(line, 2), /extract)

    ; Ensure parts has at least 12 elements
    if n_elements(parts) ge 12 then begin
      band_id[i] = long(parts[0])
      elev_start[i] = double(parts[1])
      elev_end[i] = double(parts[2])
      area[i] = double(parts[3])
      thickness[i] = double(parts[4])
      width[i] = double(parts[5])
      length[i] = double(parts[6])
      slope[i] = double(parts[7])
      aspect[i] = long(parts[8])
      b_app[i] = double(parts[9])
      basal_stress[i] = double(parts[10])
      shape_factor[i] = double(parts[11])
    endif
  endfor

  ; Close the file
  free_lun, lun

  ; Combine all data into a single 2D array, adjusting for actual number of rows read
  actual_rows = (i < n_data_rows)

  if actual_rows eq 0 then begin
    print, 'Warning: No data rows read from file'
    return, dblarr(12, 0)
  endif

  ; Combine all columns into result matrix
  result = dblarr(actual_rows, 12)
  result[*, 0] = band_id[0 : actual_rows - 1]
  result[*, 1] = elev_start[0 : actual_rows - 1]
  result[*, 2] = elev_end[0 : actual_rows - 1]
  result[*, 3] = area[0 : actual_rows - 1]
  result[*, 4] = thickness[0 : actual_rows - 1]
  result[*, 5] = width[0 : actual_rows - 1]
  result[*, 6] = length[0 : actual_rows - 1]
  result[*, 7] = slope[0 : actual_rows - 1]
  result[*, 8] = aspect[0 : actual_rows - 1]
  result[*, 9] = b_app[0 : actual_rows - 1]
  result[*, 10] = basal_stress[0 : actual_rows - 1]
  result[*, 11] = shape_factor[0 : actual_rows - 1]

  return, result
end
