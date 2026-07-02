; *************************************************************
; write_hypsometry_evolution_file
;
; write hypsometry-evolution file
; *************************************************************

compile_opt idl2

if write_hypsometry_files eq 'y' then begin
  ; use ctt (the allocated number of decade columns, matching the header written
  ; in prepare_output_hypsoevo.pro) rather than chypso (how many were actually
  ; filled during the run) so every row prints on one line even if the final
  ; decade slot was never reached (e.g. tran[1] is exclusive, so the last
  ; decade boundary at tran[1] itself is never simulated and stays at snoval)
  for i = 0, nb - 1 do printf, 9, bed_elev[i] + thick_ini[i], hypso_file[1, *, i], fo = '(' + string(1 + ctt, fo = '(i2)') + 'f12.5)'
  close, 9
  for i = 0, nb - 1 do printf, 34, bed_elev[i] + thick_ini[i], hypso_file[2, *, i], fo = '(' + string(1 + ctt, fo = '(i2)') + 'f13.5)'
  close, 34
  for i = 0, nb - 1 do printf, 35, bed_elev[i] + thick_ini[i], hypso_file[3, *, i], fo = '(' + string(1 + ctt, fo = '(i2)') + 'f12.5)'
  close, 35
endif
