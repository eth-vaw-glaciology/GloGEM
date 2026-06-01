PRO GRADIENT_VARIABILITY_MONTHLY, cc,bb,rtg,dtdz,submonth_variability,rvariab,variab
compile_opt idl2


; ----------------------------------------
; determine local monthly gradients from reanalysis-data using a regression
dtdz=dblarr(12) & mtt=indgen(12)+1
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

end
