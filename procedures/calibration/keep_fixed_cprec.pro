; *************************************************************
; keep_fixed_cprec
;
; Phase 1 with calibrate_cprec_file: a listed glacier keeps its given
; c_prec, which its single run may have moved or bounded, and is
; flagged as calibrated.
; *************************************************************

compile_opt idl2

if cprec_fixed and calibration_phase eq '1' then begin
  C_prec = cpf_cprec[cpf_k[0]] & flag = 1
endif
