; ***************************************
; write hypsometry-evolution file
; ***************************************

compile_opt idl2

if write_hypsometry_files eq 'y' then begin
  for i = 0, nb - 1 do printf, 9, bed_elev[i] + thick_ini[i], hypso_file[1, *, i], fo = '(' + string(1 + chypso, fo = '(i2)') + 'f12.5)'
  close, 9
  for i = 0, nb - 1 do printf, 34, bed_elev[i] + thick_ini[i], hypso_file[2, *, i], fo = '(' + string(1 + chypso, fo = '(i2)') + 'f13.5)'
  close, 34
  for i = 0, nb - 1 do printf, 35, bed_elev[i] + thick_ini[i], hypso_file[3, *, i], fo = '(' + string(1 + chypso, fo = '(i2)') + 'f12.5)'
  close, 35
endif
