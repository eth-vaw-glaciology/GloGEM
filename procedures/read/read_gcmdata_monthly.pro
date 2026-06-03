; *************************************************************
; read_gcmdata_monthly
;
; Read gridded monthly GCM temperature and precipitation fields for
; a region and scenario into memory.
;
; Opens the binary .mdi metadata file for the selected GCM, scenario,
; and experiment to obtain the grid dimensions, then reads the full
; 3-D arrays of GCM temperature (gcm_temp) and precipitation
; (gcm_prec) over all time steps, latitudes, and longitudes. Derives
; integer year and month indices from the decimal time vector and
; adjusts longitudes to the -180 to 180 convention.
; *************************************************************

compile_opt idl2

  fn=dir_clim+'/future/'+time_resolution+'/'+long_GCM+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+ $
     '/'+GCM_model[gcms]+'_'+GCM_rcp[rcps]+'_'+GCM_experiment[experis]+'_'+dir_region+ccl+'.mdi'
  a=findfile(fn) ;& if a(0) eq '' then goto,next_GCM
  tt=strarr(1) & nyrs=dblarr(1) & nmonths=nyrs & nlons=nyrs & nlats=nyrs & nvar=dblarr(2)
  openr,1,fn & readf,1,tt & readf,1,ntime & readf,1,nlons & readf,1,nlats  & readf,1,nvar
  ntime=ntime[0] & nlats=nlats[0] & nlons=nlons[0] & nvar=nvar[0]
  gcmtime=dblarr(ntime) & gcm_lat=dblarr(nlats) & gcm_lon=dblarr(nlons)
  readf,1,gcmtime & readf,1,gcm_lon & readf,1,gcm_lat
  gcm_elev=dblarr(nlons,nlats) & gcm_temp=dblarr(ntime,nlons,nlats) & gcm_prec=gcm_temp
  for h=0,nlons[0]-1 do begin
     a=dblarr(nlats) & readf,1,a & gcm_elev[h,*]=a
  endfor
  for i=0,ntime[0]-1 do begin
     for h=0,nlons[0]-1 do begin
        a=dblarr(nlats) & readf,1,a ;& if min(a) lt -50 then a=a+273.15
        gcm_temp[i,h,*]=a
     endfor
  endfor
  for i=0,ntime[0]-1 do begin
     for h=0,nlons[0]-1 do begin
        a=dblarr(nlats) & readf,1,a & gcm_prec[i,h,*]=a
     endfor
  endfor
  close,1

  gcm_year=fix(gcmtime) & gcm_mon=round((gcmtime-gcm_year)*12+0.5)
  ii=where(gcm_lon ge 180,ci) & if ci gt 0 then gcm_lon[ii]=gcm_lon[ii]-360
