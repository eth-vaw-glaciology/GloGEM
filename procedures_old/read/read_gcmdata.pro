PRO READ_GCMDATA,dir_clim,GCMdata,dir_region,GCM_model,GCM_rcp,gcms,rcps,rmid,  tempgcm,precgcm,gcm_year,gcm_mon,gcm_day 

; find closest GCM-point
fn=dir_clim+GCMdata+'/'+dir_region+'/'+GCM_model(gcms)+'/longitudes.dat'
anz=file_lines(fn)-1 & s=strarr(1) & gcm_lon=dblarr(anz) 
openr,1,fn & readf,1,s & readf,1,gcm_lon & close,1

fn=dir_clim+GCMdata+'/'+dir_region+'/'+GCM_model(gcms)+'/latitudes.dat'
anz=file_lines(fn)-1 & s=strarr(1) & gcm_lat=dblarr(anz) 
openr,1,fn & readf,1,s & readf,1,gcm_lat & close,1

a=min(abs(gcm_lon-rmid(0)),ind) & a=min(abs(gcm_lat-rmid(1)),ind2)

gcm_mid=[gcm_lon(ind),gcm_lat(ind2)]
gxg=strcompress(string(gcm_mid(0),fo='(f7.2)'),/remove_all)
gyg=strcompress(string(gcm_mid(1),fo='(f7.2)'),/remove_all)

; read GCM time series
fn=dir_clim+GCMdata+'/'+dir_region+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)+'/'+'clim_'+gxg+'_'+gyg+'.dat'
anz=file_lines(fn)-3 & da=dblarr(6,anz) & tt=strarr(3)
openr,1,fn & readf,1,tt & readf,1,da & close,1
tempgcm=da(4,*) & precgcm=da(5,*) & gcm_year=da(0,*) & gcm_mon=da(1,*)  & gcm_day=da(2,*) 

end
