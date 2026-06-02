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