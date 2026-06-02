; ***************************************
; write elevation band file
; ***************************************

compile_opt idl2

ii = where(thick_ini eq 0, ci)
if ci gt 0 then elev_bmb[*, ii] = snoval
if ci gt 0 then elev_bwb[*, ii] = snoval
if ci gt 0 then elev_refr[*, ii] = snoval
for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 8, elev0[i], elev_bmb[*, i], elev_bwb[*, i], fo = '(i6,' + strcompress(string(2 * years, fo = '(i3)'), /remove_all) + 'f7.2)'
close, 8
for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 40, elev0[i], elev_refr[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f7.1)'
close, 40
if debris_supraglacial eq 'y' then begin
  for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 41, elev0[i], elev_debthick[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f8.3)'
  close, 41
  for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 42, elev0[i], elev_debfrac[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f8.3)'
  close, 42
  for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 43, elev0[i], elev_debfactor[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f10.5)'
  close, 43
  for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 44, elev0[i], elev_pondarea[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f11.6)'
  close, 44
  if eval_mbelevsensitivity eq 'y' then begin
    for i = 0, n_elements(elev_bmb[0, *]) - 1 do printf, 44, elev0[i], elev_mbsens[*, i], fo = '(i6,' + strcompress(string(years, fo = '(i3)'), /remove_all) + 'f9.4)'
    close, 44
  endif
endif
