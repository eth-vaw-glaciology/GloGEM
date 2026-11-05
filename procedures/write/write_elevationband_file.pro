; *************************************************************
; write_elevationband_file
;
; write elevation band file
; *************************************************************

compile_opt idl2

ii = where(thick_ini eq 0, ci)
; with band_extension or band_extension_glacier the bands without ice carry their virtual balance
if ci gt 0 and band_extension ne 'y' and band_extension_glacier ne 'y' then elev_bmb[*, ii] = snoval
if ci gt 0 and band_extension ne 'y' and band_extension_glacier ne 'y' then elev_bwb[*, ii] = snoval
if ci gt 0 then elev_refr[*, ii] = snoval
; 0.001 m w.e. with band_extension or band_extension_glacier (forcing for other models), else 0.1 as before
if band_extension eq 'y' or band_extension_glacier eq 'y' then fmt_bmb = 'f9.3' else fmt_bmb = 'f7.1'
; band_extension: the extension bands below the glacier first
if band_extension eq 'y' then begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + fmt_bmb + ')'
  for i = 0, bx_n - 1 do printf, 8, bx_elev[i], elev_bmbx[*, i], format = fmt
endif
for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + fmt_bmb + ')'
  printf, 8, elev0[i], elev_bmb[*, i], format = fmt
endfor
close, 8

; band_extension: no refreezing values on the extension bands
if band_extension eq 'y' then begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f7.1)'
  for i = 0, bx_n - 1 do printf, 40, bx_elev[i], dblarr(years) + snoval, format = fmt
endif
for i = 0, n_elements(elev_bmb[0, *]) - 1 do begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f7.1)'
  printf, 40, elev0[i], elev_refr[*, i], format = fmt
endfor
close, 40

; winter balance per band [m w.e.], to the end of the winter month (store_elevationband_massbalance.pro)
get_lun, lun_bw
openw, lun_bw, dirres + '/' + time_resolution + '/' + dir_region + subpath + '/mb_elevation/bwelev_' + id[gg[g]] + '.dat'
a = '' & for i = 0, years - 1 do a = a + string(i + tran[0], fo = '(i4)') + '    '
printf, lun_bw, 'Elev  ' + a
for i = 0, n_elements(elev_bwb[0, *]) - 1 do begin
  fmt = '(i6,' + strtrim(string(years, format = '(i4)'), 2) + 'f8.3)'
  printf, lun_bw, elev0[i], elev_bwb[*, i], format = fmt
endfor
free_lun, lun_bw

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
