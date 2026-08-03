; *************************************************************
; read_gcmdata_daily
;
; Read daily GCM temperature and precipitation time series for the
; grid point nearest to the current glacier cluster.
;
; Locates the closest GCM longitude and latitude grid points to the
; reanalysis reference location (rmid), constructs the path to the
; daily climate file for the active GCM and scenario, and reads the
; 6-column data array containing year, month, day, and climate
; variables. The extracted arrays (tempgcm, precgcm, gcm_year,
; gcm_mon, gcm_day) are used by the downscaling procedure.
; *************************************************************

compile_opt idl2

; OLD
; find closest GCM-point
;fn=dir_clim+'/future/'+time_resolution+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+'/longitudes.dat'
;anz=file_lines(fn)-1 & s=strarr(1) & gcm_lon=dblarr(anz)
;openr,1,fn & readf,1,s & readf,1,gcm_lon & close,1
;fn=dir_clim+'/future/'+time_resolution+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+'/latitudes.dat'
;anz=file_lines(fn)-1 & s=strarr(1) & gcm_lat=dblarr(anz)
;openr,1,fn & readf,1,s & readf,1,gcm_lat & close,1
;a=min(abs(gcm_lon-rmid[0]),ind) & a=min(abs(gcm_lat-rmid[1]),ind2)
;gcm_mid=[gcm_lon[ind],gcm_lat[ind2]]
;gxg=strcompress(string(gcm_mid[0],fo='(f7.2)'),/remove_all)
;gyg=strcompress(string(gcm_mid[1],fo='(f7.2)'),/remove_all)

; NEW
gcm_mid= [rmid[0],rmid[1]]
;gxg=strcompress(string(gcm_mid(0),fo='(f7.2)'),/remove_all)
;gyg=strcompress(string(gcm_mid(1),fo='(f7.2)'),/remove_all)
gxs=strcompress(string(gcm_mid[0],fo='(f7.2)'),/remove_all)
gys=strcompress(string(gcm_mid[1],fo='(f7.2)'),/remove_all)
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
                  ; Bereken nieuwe coördinaten                                                                                                                                                                      
               mid = [mean(lon) + STRING(double(q) / 100, FORMAT='(F5.2)'), mean(lat) + STRING(double(r) / 100, FORMAT='(F5.2)')]
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
      if radius eq 100 then begin
         print, 'No suitable GCM grid point found within 1° radius. Please check your input coordinates.'
         STOP
      endif
   endwhile
endelse
; read GCM time series
;fn=dir_clim+'/future/'+time_resolution+'/'+GCM_data+'/'+dir_region+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]+'/'+'clim_'+gxg+'_'+gyg+'.dat'
anz=file_lines(fn)-3 & da=dblarr(6,anz) & tt=strarr(3)
openr,1,fn & readf,1,tt & readf,1,da & close,1
tempgcm=da[4,*] & precgcm=da[5,*] & gcm_year=da[0,*] & gcm_mon=da[1,*]  & gcm_day=da[2,*]
