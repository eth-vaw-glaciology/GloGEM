; *************************************************************
; select_cprec_glacier
;
; Before the runs of one glacier, with calibrate_snowline or
; calibrate_cprec_file: whether, and how often, it is run.
;
; Snowline scan: only glaciers with observed snow lines in the
; modelled period are run, until their final run at the minimum is
; done; cal1max = -1 skips the runs.
; Fixed c_prec: in phase 1 a listed glacier is run once, and its c_prec
; is not handed on to the next glacier as the start of its phase-1 fit.
; *************************************************************

compile_opt idl2

if calibrate_snowline eq 'y' then begin
  snowcal_g = gg[g]
  if snowcal_id[snowcal_g] eq '' then begin
    snowcal_id[snowcal_g] = id[gg[g]]
    snowcal_k = where(calisnow_gid eq id[gg[g]], snowcal_n)
    if snowcal_n gt 0 then begin
      snowcal_day = 365l * (long(year_obs[snowcal_k]) - long(tran[0]) + 1) + long(doy_obs[snowcal_k]) - long(bal_month)
      snowcal_k = where(snowcal_day ge 0 and snowcal_day lt 365l * years, snowcal_n)
    endif
    snowcal_nobs[snowcal_g] = snowcal_n
    if ~file_test(dir_data + '/' + region + '/' + id[gg[g]] + '.dat') then snowcal_n = 0
    if snowcal_n eq 0 then snowcal_flag[snowcal_g] = -1
  endif else if snowcal_id[snowcal_g] ne id[gg[g]] then $
    message, 'snowline calibration: the glacier order changed between passes'
  snowcal_ran = snowcal_flag[snowcal_g] eq 0 or snowcal_flag[snowcal_g] eq 1
  if ~snowcal_ran then begin
    cal1max = -1
    ; read after the glacier loop body; set here in case no glacier has run yet
    flux_calv = dblarr(years) & ar_gl = 0.d
    if n_elements(nb) eq 0 then nb = 0l
    if n_elements(step) eq 0 then step = 10.d
    if n_elements(volume0) eq 0 then volume0 = 0.d
  endif
endif

if calibrate_cprec_file ne '' then begin
  if n_elements(cpf_cprec_saved) gt 0 then begin
    c_prec = cpf_cprec_saved & cpf_cprec_saved = !null
  endif
  cpf_k = where(cpf_id eq id[gg[g]], cpf_n)
  cprec_fixed = cpf_n gt 0
  if cprec_fixed and calibration_phase eq '1' then begin
    cpf_cprec_saved = c_prec
    cal1max = 0
  endif
endif
