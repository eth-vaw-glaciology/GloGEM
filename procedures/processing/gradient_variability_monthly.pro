; *************************************************************
; gradient_variability_monthly
;
; Extract monthly vertical temperature gradients and sub-monthly
; temperature variability from the reanalysis gridded data.
;
; For the nearest reanalysis grid point (identified by indices cc and
; bb), the procedure reads the pre-computed monthly lapse rates
; (dtdz, in K per 100 m) from the rtg array and, if sub-monthly
; variability is enabled, reads the daily within-month anomaly
; patterns (rvariab) for use in the temperature-index mass balance
; model. A seasonal weighting factor (vf) reduces variability in
; winter months.
; *************************************************************

compile_opt idl2

; ----------------------------------------
; determine local monthly gradients from reanalysis-data using a regression
dtdz=dblarr(12)
mtt=indgen(12)+1
for m=1,12 do begin
   hh=where(mtt eq m)
   dtdz[m-1]=rtg[hh[0],cc[0],bb[0]]
endfor

; determine sub-monthly T-variability from reanalysis data
if submonth_variability eq 'y' then begin

variab=dblarr(12,31)
vf=dblarr(12)+1 & vf[0:2]=0.5 & vf[10:11]=0.5
for m=1,12 do begin
   hh=where(mtt eq m)
   variab[m-1,*]=rvariab[hh[0],*,cc[0],bb[0]]*vf[m-1]
endfor

endif
