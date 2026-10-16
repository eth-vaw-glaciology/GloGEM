; *************************************************************
; apply_cprec_override
;
; c_prec set from outside the phase-1 fit (after
; apply_calibration_params).
;
; Snowline scan: c_prec is this pass's scanned value and T_off starts
; at 0 in phases 2 and 3; at the first value, phase 2 starts from the
; default DDF.
; Fixed c_prec: the value from calibrate_cprec_file, in every phase.
; *************************************************************

compile_opt idl2

if cal1 eq 0 then begin
  if calibrate_snowline eq 'y' then begin
    if snowcal_r eq 0 and calibration_phase eq '2' then begin
      DDFsnow = double(DDFsnow0) & DDFice = double(DDFice0)
    endif
    C_prec = snowcal_cprec[gg[g], snowcal_r] & t_offset = 0.d
  endif
  if calibrate_cprec_file ne '' then if cprec_fixed then C_prec = cpf_cprec[cpf_k[0]]
endif
