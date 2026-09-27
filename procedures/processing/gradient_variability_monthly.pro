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
; determine local monthly gradients from reanalysis-data
if new eq 'n' then begin
   dtdz=dblarr(12)	   
   mtt=indgen(12)+1   
   for m=1,12 do begin	
      hh=where(mtt eq m)	
      dtdz[m-1]=rtg[hh[0],cc[0],bb[0]]
   endfor
; Determine from reanalysis grid cel
endif else begin
   ; per-point file: lapse rate per calendar month (the column repeats a monthly climatology)
   dtdz_pt=dtdz
   dtdz=dblarr(12)
   for m=1,12 do dtdz[m-1]=mean(dtdz_pt[where(rmon eq m)])
endelse

; determine sub-monthly T-variability from reanalysis data
if submonth_variability eq 'y' then begin
   ; variability grid and fields come from the region-level read in glogem.pro
   ; new path: variability grid cell nearest to the ERA5 point, longitudes compared modulo 360
   if new eq 'y' then begin
      mtt=indgen(12)+1
      dummy=min(abs(rvlat-era5_pt[1]),bb)
      dummy=min(abs(((rvlon-era5_pt[0]+540d) mod 360d)-180d),cc)
   endif

   variab=dblarr(12,31)   
   vf=dblarr(12)+1
   vf[0:2]=0.5
   vf[10:11]=0.5
   for m=1,12 do begin
      hh=where(mtt eq m)
      variab[m-1,*]=rvariab[hh[0],*,cc[0],bb[0]]*vf[m-1]
   endfor
endif