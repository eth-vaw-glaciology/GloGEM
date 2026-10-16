; *************************************************************
; read_fixed_cprec
;
; Read the glaciers whose c_prec is kept fixed (calibrate_cprec_file),
; at the start of phase 1. The file is a GloGEM calibration file:
; one header line, glacier ID in the first column, Cprec in column 11
; (meltmodel 1) or 13 (meltmodel 3).
; *************************************************************

compile_opt idl2

cpf_n = file_lines(calibrate_cprec_file) - 1
cpf_head = strarr(1) & cpf_lines = strarr(cpf_n)
openr, cpf_lun, calibrate_cprec_file, /get_lun
readf, cpf_lun, cpf_head
readf, cpf_lun, cpf_lines
free_lun, cpf_lun
cpf_id = strarr(cpf_n) & cpf_cprec = dblarr(cpf_n)
if meltmodel eq '3' then cpf_col = 12 else cpf_col = 10
for cpf_i = 0l, cpf_n - 1 do begin
  cpf_tok = strsplit(cpf_lines[cpf_i], ' ', /extract)
  cpf_id[cpf_i] = strmid(cpf_tok[0], strlen(cpf_tok[0]) - 5, 5) & cpf_cprec[cpf_i] = double(cpf_tok[cpf_col])
endfor
cpf_cprec_saved = !null
cpf_nmatch = 0l
for cpf_i = 0l, cpf_n - 1 do if total(id eq cpf_id[cpf_i]) gt 0 then cpf_nmatch = cpf_nmatch + 1
print, '   c_prec fixed for ' + strtrim(cpf_nmatch, 2) + ' inventory glaciers (' + strtrim(cpf_n, 2) + $
  ' in the file) from ' + calibrate_cprec_file
