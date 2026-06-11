; *************************************************************
; write_elevationband_file
;
; write elevation band file
; *************************************************************

compile_opt idl2

ii = where(thick_ini eq 0, ci)
if ci gt 0 then elev_bmb[*, ii] = snoval
if ci gt 0 then elev_bwb[*, ii] = snoval
if ci gt 0 then elev_refr[*, ii] = snoval
for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f7.1)'
  printf, 8, elev0[i], elev_bmb[*, i], format = fmt
endfor
close, 8

for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f7.1)'
  printf, 40, elev0[i], elev_refr[*, i], format = fmt
endfor
close, 40

if debris_supraglacial eq 'y' then begin
  for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
    fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f8.3)'
    printf, 41, elev0[i], elev_debthick[*, i], format = fmt
  endfor
  close, 41

  for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
    fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f8.3)'
    printf, 42, elev0[i], elev_debfrac[*, i], format = fmt
  endfor
  close, 42

  for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
    fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f10.5)'
    printf, 43, elev0[i], elev_debfactor[*, i], format = fmt
  endfor
  close, 43

  for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
    fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f11.6)'
    printf, 44, elev0[i], elev_pondarea[*, i], format = fmt
  endfor
  close, 44

  if eval_mbelevsensitivity eq 'y' then begin
    for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
      fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f9.4)'
      printf, 44, elev0[i], elev_mbsens[*, i], format = fmt
    endfor
    close, 44
  endif
endif
