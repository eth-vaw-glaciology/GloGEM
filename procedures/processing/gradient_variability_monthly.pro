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
   dtdz=dtdz[1:12]
endelse

; determine sub-monthly T-variability from reanalysis data
if submonth_variability eq 'y' then begin
   if clim_subregion ne '' then ccl='_'+clim_subregion else ccl=''	

   fn=dir_clim+'reanalysis/'+ time_resolution +'/'+reanalysis+'/'+dir_region+'/clim_'+dir_region+ccl+'.mdi'
   tt=strarr(1) & ntime=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(2)
   openr,1,fn & readf,1,tt & readf,1,ntime & readf,1,nlons & readf,1,nlats & readf,1,nvar
   ntime=ntime[0]		
   nlats=nlats[0]
   nlons=nlons[0]
   nvar=nvar[0]
   rtime=dblarr(ntime)
   rlat=dblarr(nlats)
   rlon=dblarr(nlons)
   readf,1,rtime
   readf,1,rlon
   readf,1,rlat
   relev=dblarr(nlons,nlats)
   rtemp=dblarr(ntime,nlons,nlats)
   rprec=rtemp
   for h=0,nlons[0]-1 do begin
      a=dblarr(nlats)
      readf,1,a
      relev[h,*]=a
   endfor
   for i=0,ntime[0]-1 do begin
      for h=0,nlons[0]-1 do begin
         a=dblarr(nlats)
         readf,1,a
         rtemp[i,h,*]=a
      endfor
   endfor
   for i=0,ntime[0]-1 do begin
      for h=0,nlons[0]-1 do begin
         a=dblarr(nlats)
         readf,1,a
         rprec[i,h,*]=a
      endfor
   endfor
   close,1
   
   ; RE_ANALYSIS - variability file
   fn=dir_clim+'reanalysis/'+ time_resolution +'/'+reanalysis+'/'+dir_region+'/variability_'+dir_region+ccl+'.mdi'
   tt=strarr(1) & nmonths=dblarr(1) & ndays=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(1)
   openr,1,fn & readf,1,tt & readf,1,nmonths & readf,1,ndays & readf,1,nlons & readf,1,nlats & readf,1,nvar
   nmonths=nmonths[0] & nlats=nlats[0] & nlons=nlons[0] & nvar=nvar[0] & ndays=ndays[0]
   rvmon=dblarr(nmonths) & rvday=dblarr(ndays) &  rvlat=dblarr(nlats) & rvlon=dblarr(nlons)
   readf,1,rvmon & readf,1,rvday & readf,1,rvlon & readf,1,rvlat
   rvariab=dblarr(nmonths,ndays,nlons,nlats)
   for i=0,nmonths[0]-1 do begin
      for d=0,ndays[0]-1 do begin
         for h=0,nlons[0]-1 do begin
            a=dblarr(nlats) & readf,1,a & rvariab[i,d,h,*]=a
         endfor
      endfor
   endfor
   close,1

   if new eq 'y' then begin   
      bb=where(rlat eq rmid[0])
      cc=where(rlon eq rmid[1])
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