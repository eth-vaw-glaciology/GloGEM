PRO read_snowlinedata, dir, dir_region, region_loop_data, calibrate_glacierspecific_period, year_obs, doy_obs, snowlineday_obs, snowline_stdev_obs, calisnow_p0, calisnow_p1, calisnow_gid

  ;--------------------------------------------
  ; Identify file and read metadata
  ;--------------------------------------------
  ii = where(dir_region EQ region_loop_data(2,*))
  fn = dir + 'snowline/snowline_' + calibrate_glacierspecific_period + '/' + $
       strcompress(region_loop_data(1, ii), /remove_all) + '_snowline_median.dat'

  ; Get number of data lines and initialize arrays
  anz = file_lines(fn) - 1
  anz = anz(0)
  calisnow_gid    = strarr(anz)
  tt            = strarr(anz)
  calisnow_idname = dblarr(anz) + 9

  ; Parse calibration period into numeric start/end arrays
  a = strsplit(calibrate_glacierspecific_period, '_', /extract)
  calisnow_p0 = dblarr(anz) + double(a(0))
  calisnow_p1 = dblarr(anz) + double(a(1)) - 1

  ; Prepare arrays for reading data
  tt2 = dblarr(5, anz) ; Organize the numeric values from each data line; Creates a 2D double-precision array with 6 rows and anz columns. It will store 6 numerical values per data line, such as mass balance, area, uncertainty, or flags 
  b   = strarr(anz) ; Read raw data lines ; Creates a string array with anz elements. This will hold the raw text lines of data read from the file (one line per glacier).
  s   = strarr(1); Creates a string array with 1 element. This is used to skip or temporarily store the first three lines of the file, which are assumed to be headers or metadata.

  ;--------------------------------------------
  ; Read and parse data from file
  ;--------------------------------------------
  openr, 1, fn
  readf, 1, s         ; Skip header
  readf, 1, b         ; Read data lines
  close, 1

  ; Split lines into components and populate arrays
  FOR i = 0, anz - 1 DO BEGIN
    a = strsplit(b(i), ' ', /extract)
    tt(i) = a(0) ;Store the first token (e.g., a glacier identifier or date string) in the array tt.
    FOR j = 0, 3 DO tt2(j, i) = a(1 + j) ;Loop over the next 6 tokens in a (from a(1) to a(6)). Convert and store these values in the 2D array tt2, where:j = which variable (row),i = which glacier (column).
  ENDFOR

  ; Extract glacier IDs from identifier string
  FOR i = 0, anz - 1 DO calisnow_gid(i) = strmid(tt(i), 9, 5) ; The result is stored in calimb_gid(i).

  ;--------------------------------------------
  ; Extract snowline, year, doy, snowlineday_obs, snowline_stdev_obs
  ;--------------------------------------------
  ;calimb_bn = tt2(3, *)
  year_obs =tt2(2,*)
  doy_obs = tt2(3,*)
  snowlineday_obs = tt2(0,*)
  snowline_stdev_obs = tt2(1,*)  
 
end
