; *************************************************************
; bias_correction_delta
;
; Compute monthly temperature and precipitation bias factors between
; a GCM and the reanalysis reference using the delta method.
;
; For each calendar month the procedure calculates the additive
; temperature bias (GCM minus reanalysis mean) and the multiplicative
; precipitation bias (GCM divided by reanalysis mean) over the common
; evaluation period rea_eval. It also derives a temperature-variability
; scaling factor and optionally clamps extreme biases using the
; min_tempbias and min_precbias thresholds to prevent unrealistic
; corrections in high-latitude or data-sparse regions.
; *************************************************************

compile_opt idl2

; calculate monthly bias in the past based on delta method
bias = dblarr(3, 12)    ; (0) temp, (1) prec, (2) temperature variability in month

; computation of bias stays at monthly resolution!
hh = where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1])
for m = 1, 12 do begin
   ; for some reason reanalysis temperature appear to be completely wrong
   ; in a few years... filtering here and later
   dd = where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m and tempre gt -50)
   kk = where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)
   bias[0, m-1] = mean(tempgcm[kk]) - mean(tempre[dd])    ; monthly temperature bias
   bias[1, m-1] = mean(precgcm[kk]) / mean(prec_orig[dd])
   bias[2, m-1] = stdev(tempre[dd]) / stdev(tempgcm[kk])
endfor

; optionally restrict temperature bias to a minimum value - if extreme
; biases occur in Arctic regions air temperatures can suddenly become maximal
; during winter time
if min_tempbias ne noval then begin
   dd = where(bias[0, *] lt min_tempbias, cd)
   if cd gt 0 then bias[0, dd] = min_tempbias
endif

; optionally restrict precipitation bias to a minimum value - if GCM yields (almost) no precipitation on average the bias will become very small resulting in extreme precipitation rates (several 100 m!) if some prec is present
if min_precbias ne noval then begin
   dd = where(bias[1, *] lt min_precbias, cd)
   if cd gt 0 then bias[1, dd] = min_precbias
endif
