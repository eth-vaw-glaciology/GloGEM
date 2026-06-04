; *************************************************************
; read_climatepast_monthly
;
; Read the gridded monthly reanalysis climate fields for a region
; into memory for subsequent downscaling and bias correction.
;
; Opens the binary .mdi metadata file to obtain grid dimensions and
; coordinate arrays, then reads gridded temperature and precipitation
; time series (rtemp, rprec) and, when sub-monthly variability is
; enabled, the daily within-month anomaly patterns (rvariab). Also
; reads the monthly vertical temperature gradient field (rtg) and
; adjusts longitude arrays to the -180 to 180 convention for
; consistency with the glacier inventory coordinates.
; *************************************************************

compile_opt idl2

   if clim_subregion ne '' then ccl='_'+clim_subregion else ccl=''

; ---- RE_ANALYSIS - climate file
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
; patch for missing reanalysis precipitation data for Antarctic_Atlantic...
if reanalysis eq 'ERA-interim' then begin
   if dir_region eq 'Antarctic' and clim_subregion eq 'Atlantic' then begin
      for i=0,ntime[0]-1 do for h=12,nlons-1 do rprec[i,h,*]=rprec[i,5,*]
   endif
endif

ryear=fix(rtime)
rmon=round((rtime-ryear)*12+0.5-(ryear-ryear[0])/1400.*12)  ; hack accounting for leap years...

; Hack to account for leap years in era5 (lower case ...)
if reanalysis eq 'era5' then begin
   rmon=round(((rtime+0.04)-ryear)*12+0.6-(ryear-ryear[0])/2800.*12)  ; hack accounting for leap years...
endif

if submonth_variability eq 'y' then begin

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

endif

; RE_ANALYSIS - temperature gradient file
fn=dir_clim+'reanalysis/'+ time_resolution +'/'+reanalysis+'/'+dir_region+'/tgrad_'+dir_region+ccl+'.mdi'
tt=strarr(1) & nmonths=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(1)
nmonths=nmonths[0] & nlats=nlats[0] & nlons=nlons[0] & nvar=nvar[0]
openr,1,fn & readf,1,tt & readf,1,nmonths & readf,1,nlons & readf,1,nlats & readf,1,nvar
rvmon=dblarr(nmonths) & rvlat=dblarr(nlats) & rvlon=dblarr(nlons)
readf,1,rvmon & readf,1,rvlon & readf,1,rvlat
rtg=dblarr(nmonths,nlons,nlats)
for i=0,nmonths[0]-1 do begin
   for h=0,nlons[0]-1 do begin
      a=dblarr(nlats) & readf,1,a & rtg[i,h,*]=a
   endfor
endfor
close,1

; turn longitude arrays
if clim_subregion eq 'East' then begin
   ii=where(rlon gt 180,ci) & if ci gt 0 then rlon[ii]=rlon[ii]-360
   ii=where(rvlon gt 180,ci) & if ci gt 0 then rvlon[ii]=rvlon[ii]-360
endif else begin
   ii=where(rlon ge 180,ci) & if ci gt 0 then rlon[ii]=rlon[ii]-360
   ii=where(rvlon ge 180,ci) & if ci gt 0 then rvlon[ii]=rvlon[ii]-360
endelse
