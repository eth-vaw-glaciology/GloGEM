; *************************************************************
; bias_correction_qm
;
; Correct GCM temperature data using quantile mapping against the
; reanalysis historical distribution.
;
; Builds monthly empirical cumulative distribution functions (CDFs)
; for the reanalysis historical period, the GCM historical overlap,
; and the GCM future period using 1001 quantile levels. The quantile
; arrays are stored in Qr_hist, Qg_hist, and Qg_fut for subsequent
; application of the quantile-mapping transfer function to future GCM
; temperatures.
; *************************************************************

compile_opt idl2

; ----- bias correction of GCM data using quantile mapping

NQ = 1001
q  = findgen(NQ)/(NQ-1.0)    ; 0..1
; allocate arrays
Qr_hist = fltarr(NQ, 12)
Qg_hist = fltarr(NQ, 12)
Qg_fut  = fltarr(NQ, 12)
for m = 1, 12 do begin
    ; --- reanalysis historical ---
    dd = where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m and tempre gt -50)
    ; --- GCM historical overlap ---
    kk = where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)
    ; --- GCM future ---
    ff = where(gcm_year gt rea_eval[1] and gcm_mon eq m)
    if (n_elements(dd) gt 20) and (n_elements(kk) gt 20) and (n_elements(ff) gt 20) then begin
        Qr_hist[*, m-1] = my_percentile(tempre[dd], q*100.0)
        Qg_hist[*, m-1] = my_percentile(tempgcm[kk], q*100.0)
        Qg_fut[*, m-1]  = my_percentile(tempgcm[ff], q*100.0)
    endif
endfor
