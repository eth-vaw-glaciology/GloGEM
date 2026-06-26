; *************************************************************
; apply_firnicetemp_calibration
;
; Called per glacier (inside the `g` loop) after
; initialise_firnicetemp_spinup.pro has set firnice_perm_frac_b and
; firnice_dT_scale_b to their defaults (or transfer-model values).
;
; Looks up the current glacier (id[gg[g]]) in the pre-loaded
; firnicecali_id array (read by read_firnicetemp_calibration.pro).
; If a match is found, ALL bands of this glacier are overridden with
; the per-glacier perm_frac and dT_scale values from the file.
;
; This override sits on top of both the scalar default AND the
; per-band transfer-model prediction — i.e. explicit calibration
; file values always win.
; *************************************************************

compile_opt idl2

if n_elements(firnicecali_id) gt 0 then begin
    jj = where(firnicecali_id eq id[gg[g]], n_match)
    if n_match gt 0 then begin
        firnice_perm_frac_b[*] = firnicecali_perm_frac[jj[0]]
        firnice_dT_scale_b[*]  = firnicecali_dT_scale[jj[0]]
    endif
endif
