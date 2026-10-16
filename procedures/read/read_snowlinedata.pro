; *************************************************************
; read_snowlinedata
;
; Read observed transient snow lines for the snowline calibration
; (A. von der Esch, snowline_calibration/read_snowlinedata.pro).
;
; File: one header line, then one observation per line:
;   <RGI id> <snow line [m a.s.l.]> <stdev [m]> <year> <day of year>
; The day of year is on GloGEM's daily calendar (365 days, no 29 Feb).
; The glacier number is the last five characters of the RGI id
; (RGI60-11.01450, RGI70-11.01450 or RGI2000-v7.0-G-11-01450).
; Blank lines are skipped; stdev <= 0 or a day of year outside
; 1-365 stops the run.
; *************************************************************

PRO read_snowlinedata, fn, calisnow_gid, year_obs, doy_obs, snowlineday_obs, snowline_stdev_obs

  compile_opt idl2

  if ~file_test(fn) then message, 'snowline observation file not found: ' + fn
  anz = file_lines(fn) - 1
  if anz lt 1 then message, 'no snowline observations in ' + fn
  s = strarr(1) & b = strarr(anz)
  openr, lun, fn, /get_lun
  readf, lun, s
  readf, lun, b
  free_lun, lun
  b = b[where(strtrim(b, 2) ne '', anz)]
  if anz eq 0 then message, 'no snowline observations in ' + fn

  calisnow_gid = strarr(anz) & tt2 = dblarr(4, anz)
  for i = 0l, anz - 1 do begin
    a = strsplit(b[i], /extract)
    if n_elements(a) lt 5 then message, 'snowline observation file, line ' + strtrim(i + 2, 2) + ': ' + b[i]
    calisnow_gid[i] = strmid(a[0], strlen(a[0]) - 5, 5)
    for j = 0, 3 do tt2[j, i] = double(a[1 + j])
  endfor
  snowlineday_obs = reform(tt2[0, *])
  snowline_stdev_obs = reform(tt2[1, *])
  year_obs = reform(tt2[2, *])
  doy_obs = reform(tt2[3, *])
  if min(snowline_stdev_obs) le 0 then message, 'snowline observations: stdev <= 0 in ' + fn
  if min(doy_obs) lt 1 or max(doy_obs) gt 365 then message, 'snowline observations: day of year outside 1-365 in ' + fn

end
