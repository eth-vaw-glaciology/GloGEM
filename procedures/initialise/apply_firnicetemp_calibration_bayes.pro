; *************************************************************
; apply_firnicetemp_calibration_bayes
;
; Called per glacier (inside the `g` loop) after
; initialise_firnicetemp_spinup.pro has set the per-band
; firnice_perm_frac_b / firnice_dT_scale_b / firnice_z0_firn_b arrays via
; the transfer model (requires firnice_temp_calib='y'), and after any flat
; apply_firnicetemp_calibration.pro override.
;
; Looks up the current glacier (id[gg[g]]) in the pre-loaded
; firnicecalibayes_id array (read by read_firnicetemp_calibration_bayes.pro).
; If a match is found, its Kennedy-O'Hagan posterior (delta_pf, delta_ds,
; delta_z0) residual is ADDED to every band — NOT overwritten — so the
; per-band variation already produced by the transfer model (bands at
; different elevation/T_amplitude get different baseline values) is
; preserved, while the whole glacier is shifted toward the Bayesian
; calibration's posterior-mean correction at its own location. Re-clips to
; the same physical bounds as the transfer model itself.
;
; Same mechanism as apply_firnicetemp_calibration_knn.pro; the difference is
; entirely upstream, in how the residual file was produced (see
; read_firnicetemp_calibration_bayes.pro and
; icetemp.calibration.writeback.ResidualWriter).
; *************************************************************

compile_opt idl2

if n_elements(firnicecalibayes_id) gt 0 then begin
    jj = where(firnicecalibayes_id eq id[gg[g]], n_match)
    if n_match gt 0 then begin
        firnice_perm_frac_b = (firnice_perm_frac_b + firnicecalibayes_pf_delta[jj[0]]) > 0.1d < 1.0d
        firnice_dT_scale_b  = (firnice_dT_scale_b  + firnicecalibayes_ds_delta[jj[0]]) > 0.2d < 5.0d
        firnice_z0_firn_b   = (firnice_z0_firn_b   + firnicecalibayes_z0_delta[jj[0]]) > 5.0d < 200.0d
    endif
endif
