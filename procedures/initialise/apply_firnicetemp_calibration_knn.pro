; *************************************************************
; apply_firnicetemp_calibration_knn
;
; Called per glacier (inside the `g` loop) after
; initialise_firnicetemp_spinup.pro has set the per-band
; firnice_perm_frac_b / firnice_dT_scale_b / firnice_z0_firn_b arrays via
; the transfer model (requires firnice_temp_calib='y'), and after any flat
; apply_firnicetemp_calibration.pro override.
;
; Looks up the current glacier (id[gg[g]]) in the pre-loaded
; firnicecaliknn_id array (read by read_firnicetemp_calibration_knn.pro).
; If a match is found, its (delta_pf, delta_ds, delta_z0) residual is ADDED
; to every band — NOT overwritten — so the per-band variation already
; produced by the transfer model (bands at different elevation/T_amplitude
; get different baseline values) is preserved, while the whole glacier is
; shifted toward its regionally nearest calibrated glenglat observation.
; Re-clips to the same physical bounds as the transfer model itself.
; *************************************************************

compile_opt idl2

if n_elements(firnicecaliknn_id) gt 0 then begin
    jj = where(firnicecaliknn_id eq id[gg[g]], n_match)
    if n_match gt 0 then begin
        firnice_perm_frac_b = (firnice_perm_frac_b + firnicecaliknn_pf_delta[jj[0]]) > 0.1d < 1.0d
        firnice_dT_scale_b  = (firnice_dT_scale_b  + firnicecaliknn_ds_delta[jj[0]]) > 0.2d < 5.0d
        firnice_z0_firn_b   = (firnice_z0_firn_b   + firnicecaliknn_z0_delta[jj[0]]) > 5.0d < 200.0d
    endif
endif
