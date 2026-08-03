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

if CMIP6 eq 'y' then begin
   if long_GCM ne '' then a='long' else a=''
  fn=dir_clim+'/future/'+time_resolution+'/'+a+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+ $
     '/'+GCM_model[gcms]+'_'+GCM_rcp[rcps]+'_'+GCM_experiment+'_'+dir_region+ccl+'.mdi'

   a=file_search(fn) ;& if a(0) eq '' then goto,next_GCM
   tt=strarr(1) & nyrs=dblarr(1) & nmonths=nyrs & nlons=nyrs & nlats=nyrs & nvar=dblarr(2)
   openr,1,fn & readf,1,tt & readf,1,ntime & readf,1,nlons & readf,1,nlats  & readf,1,nvar
   ntime=ntime[0] & nlats=nlats[0] & nlons=nlons[0] & nvar=nvar[0]
   gcmtime=dblarr(ntime)
   gcm_lat=dblarr(nlats)
   gcm_lon=dblarr(nlons)
   readf,1,gcmtime & readf,1,gcm_lon & readf,1,gcm_lat 
   gcm_elev=dblarr(nlons,nlats)
   gcm_temp=dblarr(ntime,nlons,nlats)
   gcm_prec=gcm_temp
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
   
   gcm_year=fix(gcmtime)
   gcm_mon=round((gcmtime-gcm_year)*12+0.5)
   ii=where(gcm_lon ge 180,ci) & if ci gt 0 then gcm_lon[ii]=gcm_lon[ii]-360

endif else begin

; New system for the monthly model, but so far only available for GCMs of GMIP4
   
   mid=[mean(lon),mean(lat)]
   gxs=strcompress(string(mid[0],fo='(f7.2)'),/remove_all)
   gys=strcompress(string(mid[1],fo='(f7.2)'),/remove_all)
   fn=dir_clim+'/future/'+time_resolution+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+ '/'+GCM_rcp[rcps]+'/clim_' + gxs + '_' + gys + '.dat'
   if FILE_TEST(fn) eq 1 then begin 
      ; All good and we continue
   endif else begin
      found = 0
      radius = 0
      while found eq 0 do begin
         for q = -radius, radius do begin
         for r = -radius, radius do begin
               ; Only coordinates on this radius
               if abs(q) eq radius or abs(r) eq radius then begin
                  ; get new coordinates
                  mid = [mean(lon) + double(q)/100., mean(lat) + double(r)/100.]
                  gxs=strcompress(string(mid[0],fo='(f7.2)'),/remove_all)
                  gys=strcompress(string(mid[1],fo='(f7.2)'),/remove_all)
                  fn=dir_clim+'/future/'+time_resolution+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+ '/'+GCM_rcp[rcps]+'/clim_' + gxs + '_' + gys + '.dat'
                  if FILE_TEST(fn) eq 1 then begin
                     found = 1
                     break
                  endif
               endif
            endfor
            if found eq 1 then break
         endfor
         if found eq 1 then break
         ; Increase search window
         radius = radius + 1
         ; Stop if search window gets 100 ... (1°)
         if radius eq 100 and 'AMOC' eq 'n' then begin
               print, 'No suitable GCM grid point found within 1° radius. Please check your input coordinates.'
               STOP
         endif
      endwhile
   endelse

   anz=file_lines(fn)-3 & da=dblarr(4,anz) & tt=strarr(3)
   openr,1,fn & readf,1,tt & readf,1,da & close,1
   gcm_temp=da[2,*]
   gcm_prec=da[3,*]
   gcm_year=da[0,*]
   gcm_mon=da[1,*]
   gcm_lon = gxs
   gcm_lat = gys
   
endelse




