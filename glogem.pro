; supporting procedure for plotting
pro PSCAL, mode, xscm,yscm, xlb=xlb, xrb=xrb, ylb=ylb, yub=yub, $
           cm2n=cm2n, name=name, win=win, rsc=rsc
  xlb=.1 & ylb=.1 & xrb=.1 & yub=.1 & pdim=[21.0,29.7] & lplts=28.3  & orient='p'
  if yscm gt lplts and float(yscm)/xscm le sqrt(2) then begin
     xscm=float(lplts)*xscm/yscm &  yscm=lplts
  endif
  xoff=(pdim(0)-xscm)/2  & yoff=(pdim(1)-yscm)/2
  if xscm gt lplts/sqrt(2) then begin
     orient='l'
     if xscm gt lplts then begin
        yscm=float(lplts)*yscm/xscm &  xscm=lplts
     endif
     xoff=(pdim(0)-yscm)/2 & yoff=xscm+(pdim(1)-xscm)/2
  endif
  set_plot,'ps' & !p.font=0
  if mode eq 'eps' then encaps=1 else encaps=0
  if name ne '0' then device, filename=name+'.'+mode, encaps=encaps,/helvetica, font_size=11, /color, bits_per_pixel=8
  if orient eq 'p' then device, /portrait else device, /landscape
  device, xsize=xscm,ysize=yscm, xoffset=xoff,yoffset=yoff
  if mode ne 'x' then cm2n=[xlb/xscm,ylb/yscm,(xscm-xrb)/xscm,(yscm-yub)/yscm] else $
     cm2n=[xlb/(xscm+.5),ylb/(yscm+.5),(xscm-xrb)/(xscm+.5),(yscm-yub)/(yscm+.5)]
END  ; PSCAL

; supporting functions for plotting
function CM2NORM, x0,y0, xd,yd , xscm,yscm
  x=float(xscm) & y=float(yscm)
  RETURN, [x0/x,y0/y,(x0+xd)/x,(y0+yd)/y]
END  ; {main}

function X_S, x
  a=-1 & a=[!x.crange(0)+(!x.crange(1)-!x.crange(0))*x]
  return, a(0)
end

function Y_S, y
  a=-1 & a=[!y.crange(0)+(!y.crange(1)-!y.crange(0))*y]
  return, a(0)
end

function RMEAN, array, width, dim
  if (N_PARAMS() lt 3) then dim=0
  if (width mod 2) eq 0 then width=width+1
  w2=long(width)/2
  s=size(array) & res=array & n=s(dim+1) & ind=indgen(n)
  for i=0l,n-1 do begin
     ii=where(ind ge i-w2 and ind le i+w2) &   res(i)=mean(array(ii))
  endfor
  RETURN, res
END  ; {rmean}



; ****************************************************

; MAIN GloGEM-Code

; ****************************************************


; --------------------------------------------
; READ batch-file for individual glaciers (icetemperature-batch)

if firnice_temperature eq 'y' then begin

; read grid-file for geothermal heatflux
   fn=dir+'geothermal_flux.grid'
   header=strarr(6) & openr,1, fn & readf,1, header
   ncols=long(strmid(header(0),6,40)) & nrows=long(strmid(header(1),6,40))
   da=dblarr(ncols,nrows) & readf,1, da & close, 1
   xllcorner=double(strmid(header(2),10,40))
   yllcorner=double(strmid(header(3),10,40))
   cellsize=double(strmid(header(4),9,40))
   a=cellsize/2d & fit_xx=lindgen(ncols)*cellsize+xllcorner+a & fit_yy=lindgen(nrows)*cellsize+yllcorner+a
   firnice_geotherm_flux=rotate(da,7)/1000.
   
if firnice_batch eq 'y' then begin
   fn=dir+'icetemperature_batch.dat' & nffbl=file_lines(fn)-1 & s=strarr(nffbl) & tt=strarr(1)
   openr,1,fn & readf,1,tt & readf,1,s & close,1
   firnice_batch_data1=dblarr(3,nffbl) & firnice_batch_data2=strarr(2,nffbl)
   for i=0,nffbl-1 do begin
      a=strsplit(s(i),',',/extract) & firnice_batch_data2(0,i)=strcompress(strmid(a(4),10,5)) & firnice_batch_data2(1,i)=strcompress(a(1),/remove_all)
      firnice_batch_data1(0,i)=double(a(2)) & firnice_batch_data1(1,i)=double(strmid(a(4),7,2)) & firnice_batch_data1(2,i)=double(a(10))
   endfor
   grid_run='n'
endif   

endif

; ***************************************************
; ***************************************************
; ***************************************************

; START OF PROGRAM

; ***************************************************
; ***************************************************
; ***************************************************


; *******************************************
; LOOP OVER DIFFERENT GCMs

for gcms=first_GCM,n_elements(GCM_model)-1 do begin

if reanalysis_direct ne 'y' then tran(1)=2100
if GCM_model(gcms) eq 'BCC-CSM1-1' and tran(1) eq 2100 then tran(1)=2099
if GCM_model(gcms) eq 'HadGEM2-ES' and tran(1) eq 2100 then tran(1)=2099

if long_GCM ne '' then tran(1)=2300   ; automatically setting end-year to 2300 for long-run

; -------------------
; LOOP OVER DIFFERENT SSPs / RCPs

if rcp_batch(0) ne 0 then ne_GCM_rcp=rcp_batch(gcms) else ne_GCM_rcp=n_elements(GCM_rcp)

for rcps=0,ne_GCM_rcp-1 do begin

; -------------------
; LOOP OVER DIFFERENT Experiments

if expe_batch(0) ne 0 then ne_GCM_experiment=expe_batch(gcms) else ne_GCM_experiment=n_elements(GCM_experiment)

for experis=0,ne_GCM_experiment-1 do begin

experi_short=strmid(GCM_experiment(experis),0,2)

fn=dir+'region_batch.dat' & anz=file_lines(fn)-1
tt=strarr(anz) & region_loop_data=strarr(5,anz) & s=strarr(1)
openr,1,fn & readf,1,s & readf,1,tt & close,1
for i=0,anz-1 do begin
   a=strsplit(tt(i),' ',/extract) & for j=0,4 do region_loop_data(j,i)=a(j)
endfor

; ********************************************************
; LOOP individual glaciers in different regions specified in batch
; file (icetemperature_batch.dat)

if firnice_batch eq 'y' then firnice_batch_loop=nffbl else firnice_batch_loop=1

for ffbl=0,firnice_batch_loop-1 do begin

if firnice_batch eq 'y' then begin
; make sure that other settings are fine
   ; DEACTIVE write_file='n' in potential FULL runs
   write_file='n' & calibrate='n'  
   single_glacier=firnice_batch_data2(0,ffbl) ; define indivudal glacier to be run
   firnice_profile_ID=firnice_batch_data2(1,ffbl)   ; define temperature profile ID
   ii=where(firnice_batch_data1(1,ffbl) eq region_loop_data(1,*),ci)         ; RGI region
   region_id_loop=[double(region_loop_data(0,ii(0))),double(region_loop_data(0,ii(ci-1)))]   ; define RGI region
   firnice_profile=[firnice_batch_data1(0,ffbl)]                                             ; define elevation
   firnice_maxdepth=[firnice_batch_data1(2,ffbl)]
endif else begin
   tt=indgen(n_elements(firnice_profile))+1
   firnice_profile_ID=strarr(n_elements(firnice_profile))
   for i=0,n_elements(firnice_profile)-1 do firnice_profile_ID(i)=string(tt(i),fo='(i1)')
endelse   

; ********************************************************
; LOOP OVER ALL REGIONS

for re=0,region_id_loop(1)-region_id_loop(0) do begin

   rp_cali=0
   repeat_cali:
   DDFsnow=DDFsnow0 & DDFice=DDFice0

if region_id_loop(0) eq 0 then begin
   region=region_n(re)
   if sub_region eq '' then sub_region=region
   if clim_subregion ne '' then sub_region=clim_subregion
   if sub_region eq '' then sub_region=region_n(0)
endif else begin
; region names for ID_loop
   if calibrate eq 'y' then begin
      read_parameters='n' & calibration_phase='1'
   endif
   region=region_loop_data(4,re+region_id_loop(0)-1)
   dir_region=region_loop_data(2,re+region_id_loop(0)-1)
   clim_subregion=region_loop_data(3,re+region_id_loop(0)-1)
   if clim_subregion eq 'xxx' then clim_subregion='' 
   if clim_subregion ne '' then sub_region=clim_subregion else sub_region=''
   if sub_region eq '' then sub_region=region
endelse

count_glaciers=1
cali_calflux=0

bal_month=10          ; month to start mass balance year
if dir_region eq 'SouthernAndes' or dir_region eq 'Antarctic' or dir_region eq 'LowLatitudes' or dir_region eq 'NewZealand' then bal_month=4

if dir_region eq 'SouthernAndes' then bedrock_parabolacorr=0.35
if dir_region eq 'Greenland' then bedrock_parabolacorr=0.30

; removing preexisting t_offset file for initial calibration
if calibrate eq 'y' then begin
   if rhodv_iteration ne '' then begin
      b='_rhodv' & c=strmid(rhodv_iteration,10,1) & if double(c) ge 2 then b='_rhodv'+c
   endif else b=''
   if rp_cali eq 0 then spawn, 'rm '+dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
endif

; ------- READ CLIMATE DATA

if clim_subregion ne '' then ccl='_'+clim_subregion else ccl=''

; GCM --- CLIMATE FILE
if reanalysis_direct ne 'y' then begin

   ; READ CMIP6 Data
   if CMIP6 eq 'y' then begin
      fn=dir_clim+'/'+long_GCM+'CMIP6/'+dir_region+'/'+GCM_model(gcms)+ $
         '/'+GCM_model(gcms)+'_'+GCM_rcp(rcps)+'_'+GCM_experiment(experis)+'_'+dir_region+ccl+'.mdi'
      a=findfile(fn) & if a(0) eq '' then goto,next_GCM
      tt=strarr(1) & nyrs=dblarr(1) & nmonths=nyrs & nlons=nyrs & nlats=nyrs & nvar=dblarr(2)
      openr,1,fn & readf,1,tt & readf,1,ntime & readf,1,nlons & readf,1,nlats  & readf,1,nvar
      ntime=ntime(0) & nlats=nlats(0) & nlons=nlons(0) & nvar=nvar(0)
      gcmtime=dblarr(ntime) & gcm_lat=dblarr(nlats) & gcm_lon=dblarr(nlons)
      readf,1,gcmtime & readf,1,gcm_lon & readf,1,gcm_lat 
      gcm_elev=dblarr(nlons,nlats) & gcm_temp=dblarr(ntime,nlons,nlats) & gcm_prec=gcm_temp
      for h=0,nlons(0)-1 do begin
         a=dblarr(nlats) & readf,1,a & gcm_elev(h,*)=a
      endfor
      for i=0,ntime(0)-1 do begin
         for h=0,nlons(0)-1 do begin
            a=dblarr(nlats) & readf,1,a ;& if min(a) lt -50 then a=a+273.15
            gcm_temp(i,h,*)=a
         endfor
      endfor
      for i=0,ntime(0)-1 do begin
         for h=0,nlons(0)-1 do begin
            a=dblarr(nlats) & readf,1,a & gcm_prec(i,h,*)=a
         endfor
      endfor
      close,1
      
      gcm_year=fix(gcmtime) & gcm_mon=round((gcmtime-gcm_year)*12+0.5)
      ii=where(gcm_lon ge 180,ci) & if ci gt 0 then gcm_lon(ii)=gcm_lon(ii)-360

   endif else begin
   ; READ CMIP5 Data
      fn=dir_clim+'GCM_regions/'+dir_region+'/'+GCM_model(gcms)+ $
         '/'+GCM_model(gcms)+'_'+GCM_rcp(rcps)+'_'+GCM_experiment(experis)+'_'+dir_region+ccl+'.mdi'
      tt=strarr(1) & nyrs=dblarr(1) & nmonths=nyrs & nlons=nyrs & nlats=nyrs & nvar=nyrs
      openr,1,fn & readf,1,tt & readf,1,nyrs & readf,1,nmonths & readf,1,nlats & readf,1,nlons & readf,1,nvar
      nyrs=nyrs(0) & nmonths=nmonths(0) & nlats=nlats(0) & nlons=nlons(0) 
      gcm_year=dblarr(nyrs) & gcm_mon=dblarr(nmonths) & gcm_lat=dblarr(nlats) & gcm_lon=dblarr(nlons)
      readf,1,gcm_year & readf,1,gcm_mon & readf,1,gcm_lat & readf,1,gcm_lon
      gcm_temp=dblarr(nyrs,nmonths,nlats,nlons) & gcm_prec=gcm_temp
      for i=0,nyrs(0)-1 do begin
         for j=0,nmonths(0)-1 do begin
            for h=0,nlats(0)-1 do begin
               a=dblarr(nlons) & readf,1,a & gcm_temp(i,j,h,*)=a
            endfor
         endfor
      endfor
      for i=0,nyrs(0)-1 do begin
         for j=0,nmonths(0)-1 do begin
            for h=0,nlats(0)-1 do begin
               a=dblarr(nlons) & readf,1,a & gcm_prec(i,j,h,*)=a
            endfor
         endfor
      endfor
      close,1
      ii=where(gcm_lon ge 180,ci) & if ci gt 0 then gcm_lon(ii)=gcm_lon(ii)-360
   endelse
endif



; ---- RE_ANALYSIS - climate file
fn=dir_clim+'reanalysis/'+reanalysis+'/region/'+dir_region+'/clim'+version_past+'_'+dir_region+ccl+'.mdi'
tt=strarr(1) & ntime=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(2)
openr,1,fn & readf,1,tt & readf,1,ntime & readf,1,nlons & readf,1,nlats & readf,1,nvar
ntime=ntime(0) & nlats=nlats(0) & nlons=nlons(0) & nvar=nvar(0)
rtime=dblarr(ntime) & rlat=dblarr(nlats) & rlon=dblarr(nlons)
readf,1,rtime & readf,1,rlon & readf,1,rlat
relev=dblarr(nlons,nlats) & rtemp=dblarr(ntime,nlons,nlats) & rprec=rtemp
for h=0,nlons(0)-1 do begin
   a=dblarr(nlats) & readf,1,a & relev(h,*)=a
endfor
for i=0,ntime(0)-1 do begin
   for h=0,nlons(0)-1 do begin
      a=dblarr(nlats) & readf,1,a & rtemp(i,h,*)=a
   endfor
endfor
for i=0,ntime(0)-1 do begin
   for h=0,nlons(0)-1 do begin
      a=dblarr(nlats) & readf,1,a & rprec(i,h,*)=a
   endfor
endfor
close,1

; patch for missing reanalysis precipitation data for Antarctic_Atlantic...
if reanalysis eq 'ERA-interim' then begin
   if dir_region eq 'Antarctic' and clim_subregion eq 'Atlantic' then begin
      for i=0,ntime(0)-1 do for h=12,nlons-1 do rprec(i,h,*)=rprec(i,5,*)
   endif
endif

ryear=fix(rtime) & rmon=round((rtime-ryear)*12+0.5-(ryear-ryear(0))/1400.*12)  ; hack accounting for leap years...

if submonth_variability eq 'y' then begin

; RE_ANALYSIS - variability file
fn=dir_clim+'reanalysis/'+reanalysis+'/region/'+dir_region+'/variability_'+dir_region+ccl+'.mdi'
tt=strarr(1) & nmonths=dblarr(1) & ndays=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(1)
openr,1,fn & readf,1,tt & readf,1,nmonths & readf,1,ndays & readf,1,nlons & readf,1,nlats & readf,1,nvar
nmonths=nmonths(0) & nlats=nlats(0) & nlons=nlons(0) & nvar=nvar(0) & ndays=ndays(0)
rvmon=dblarr(nmonths) & rvday=dblarr(ndays) &  rvlat=dblarr(nlats) & rvlon=dblarr(nlons)
readf,1,rvmon & readf,1,rvday & readf,1,rvlon & readf,1,rvlat
rvariab=dblarr(nmonths,ndays,nlons,nlats)
for i=0,nmonths(0)-1 do begin
   for d=0,ndays(0)-1 do begin
      for h=0,nlons(0)-1 do begin
         a=dblarr(nlats) & readf,1,a & rvariab(i,d,h,*)=a
      endfor
   endfor
endfor
close,1

endif

; RE_ANALYSIS - temperature gradient file
fn=dir_clim+'reanalysis/'+reanalysis+'/region/'+dir_region+'/tgrad_'+dir_region+ccl+'.mdi'
tt=strarr(1) & nmonths=dblarr(1) & nlons=ntime & nlats=ntime & nvar=dblarr(1)
nmonths=nmonths(0) & nlats=nlats(0) & nlons=nlons(0) & nvar=nvar(0)
openr,1,fn & readf,1,tt & readf,1,nmonths & readf,1,nlons & readf,1,nlats & readf,1,nvar
rvmon=dblarr(nmonths) & rvlat=dblarr(nlats) & rvlon=dblarr(nlons)
readf,1,rvmon & readf,1,rvlon & readf,1,rvlat
rtg=dblarr(nmonths,nlons,nlats)
for i=0,nmonths(0)-1 do begin
   for h=0,nlons(0)-1 do begin
      a=dblarr(nlats) & readf,1,a & rtg(i,h,*)=a
   endfor
endfor
close,1

; turn longitude arrays
if clim_subregion eq 'East' then begin 
   ii=where(rlon gt 180,ci) & if ci gt 0 then rlon(ii)=rlon(ii)-360
   ii=where(rvlon gt 180,ci) & if ci gt 0 then rvlon(ii)=rvlon(ii)-360
endif else begin
   ii=where(rlon ge 180,ci) & if ci gt 0 then rlon(ii)=rlon(ii)-360
   ii=where(rvlon ge 180,ci) & if ci gt 0 then rvlon(ii)=rvlon(ii)-360
endelse

; attribute updated space ranges to be calculated
lat0=[9999,9999]        ; run for entire region
lon0=[0,0]        ; or specify sub-regions
if clim_subregion ne '' then begin
   lat0=[min(rvlat)-0.1,max(rvlat)]
   if clim_subregion eq 'Atlantic' then lat0(0)=-60.5
   lon0=[min(rvlon)-0.1,max(rvlon)]
endif

; -----------------------------
; read regional parameter file

if regparams_readfromfile eq 'y' then begin
   fn=dir+'regional_parameters_'+reanalysis+'.dat' & anz=file_lines(fn)-6
   ss=strarr(6) & da=strarr(anz) & openr,1,fn & readf,1,ss & readf,1,da & close,1
   tt=strarr(anz) & tt2=strarr(anz) & cc=dblarr(anz) & dptt=cc & tott=cc & cprtt=dblarr(3,anz) & toff_gr=tt2
   for i=0l,anz-1 do begin
      a=strsplit(da(i),' ',/extract) & tt(i)=a(0)  & tt2(i)=a(1)
      cc(i)=double(a(2)) & for j=0,2 do cprtt(j,i)=double(a(3+j)) & dptt(i)=double(a(6)) & tott(i)=double(a(7)) & toff_gr(i)=a(8)
   endfor
   ii=where(dir_region eq tt,ci)
   if ci eq 1 then begin
      c_calving=cc(ii(0)) &   c_prec=cprtt(0,ii(0))
      c1_tolerance(0)=cprtt(1,ii(0)) & c1_tolerance(1)=cprtt(2,ii(0)) & dPdz=dptt(ii(0))
      t_offset=tott(ii(0)) & toff_grid=toff_gr(ii(0)) & toff_grid0=toff_gr(ii(0))
   endif else begin
      jj=where(clim_subregion eq tt2(ii))
      c_calving=cc(ii(jj(0))) &   c_prec=cprtt(0,ii(jj(0)))
      c1_tolerance(0)=cprtt(1,ii(jj(0))) & c1_tolerance(1)=cprtt(2,ii(jj(0)))
      dPdz=dptt(ii(jj(0)))  & t_offset=tott(ii(jj(0))) & toff_grid=toff_gr(ii(jj(0))) & toff_grid0=toff_gr(ii(jj(0)))
   endelse
endif

; -----------------------------
; read calibration data file (MEAN MASS BALANCE)
if calibrate eq 'y' then begin

if calibrate_glacierspecific eq 'n' then begin
   
fn=dir+'calibration.dat' & anz=file_lines(fn)-1   & s=strarr(1) & tt=strarr(anz)
openr,1,fn & readf,1,s & readf,1,tt & close,1
calimb_regname=strarr(anz) & calimb_sregname=strarr(anz) & calimb_outline=strarr(anz)
calimb_idname=dblarr(anz) &  calimb_p0=dblarr(anz) &  calimb_p1=dblarr(anz) & calimb_bn=dblarr(anz) & calimb_uc=dblarr(anz)
for i=0l,anz-1 do begin
   a=strsplit(tt(i),' ',/extract) & calimb_regname(i)=a(0) & calimb_sregname(i)=a(1) & calimb_outline(i)=a(2)
   calimb_idname(i)=double(a(4)) & calimb_p0(i)=double(a(5)) & calimb_p1(i)=double(a(6)) & calimb_bn(i)=double(a(7)) & calimb_uc(i)=double(a(8))
endfor

; *** Glacier-specific calibration file
endif else begin


ii=where(dir_region eq region_loop_data(2,*))
fn=dir+'geodetic/aggregated_'+calibrate_glacierspecific_period+'/'+strcompress(region_loop_data(1,ii(0)),/remove_all)+'_mb_glspec.dat'
anz=file_lines(fn)-3 &  anz=anz(0) & calimb_gid=strarr(anz) & tt=strarr(anz) & calimb_idname=dblarr(anz)+9
a=strsplit(calibrate_glacierspecific_period,'_',/extract)
calimb_p0=dblarr(anz)+double(a(0)) &  calimb_p1=dblarr(anz)+double(a(1))-1 & tt2=dblarr(6,anz) & b=strarr(anz) & s=strarr(3)
openr,1,fn & readf,1,s & readf,1,b & close,1
for i=0l,anz-1 do begin
   a=strsplit(b(i),' ',/extract) & tt(i)=a(0) & for j=0,5 do tt2(j,i)=double(a(1+j)) 
endfor
for i=0l,anz-1 do calimb_gid(i)=strmid(tt(i),9,5) & calimb_bn=tt2(3,*)
; filtering geodetic mass balances - replace strange values with regional mean IF area smaller than 20 km2 (trusting large glaciers)
ii=where(tt2(5,*) eq 1,ci) & jj=where(tt2(5,*) eq 2,cj) & if cj eq 0 then calimb_bn(ii(ci-1))=total(tt2(0,ii)*calimb_bn(ii))/total(tt2(0,ii)) 
; excluding values beyond 2 standard deviations
a=stdev(calimb_bn(ii))
jj=where(calimb_bn(ii) lt mean(calimb_bn(ii))-2*a and tt2(0,ii) lt 20,cj) & if cj gt 0 then calimb_bn(ii(jj))=calimb_bn(anz-1)  
jj=where(calimb_bn(ii) gt mean(calimb_bn(ii))+2*a and tt2(0,ii) lt 20,cj) & if cj gt 0 then calimb_bn(ii(jj))=calimb_bn(anz-1)  

; recomputing mass changes when iterating for density of volume change
if rhodv_iteration ne '' then begin
   ii=where(region eq region_loop_data(4,*))
   fn='/home/mhuss/papers/paper_density_global/results/overview_iteration'+$
      string(double(strmid(rhodv_iteration,10,1))-1,fo='(i1)')+'/rgi'+region_loop_data(1,ii(0))+'_'+region+'_grid.dat'
   anz=file_lines(fn)-1 & da=dblarr(anz+1,anz) & tt=strarr(1) & openr,1,fn & readf,1,tt & readf,1,da & close,1 & ref_rhodv=da(anz,0)
   fn='/home/mhuss/papers/paper_density_global/results/overview_iteration'+$
     string(double(strmid(rhodv_iteration,10,1))-1,fo='(i1)')+'/rgi'+region_loop_data(1,ii(0))+'_'+region+'.dat'
   anz=file_lines(fn)-1 & da=dblarr(11,anz) & openr,1,fn & readf,1,tt & readf,1,da & close,1 

   ; updating mass balances
   for i=0l,n_elements(calimb_gid)-1 do begin
      ii=where(double(calimb_gid(i)) eq da(0,*),ci)
      if ci gt 0 then begin
         ; updating with glacier-specific rho_dv, if results within reasonable tresholds
         tt=calimb_bn(i)/850.*da(10,ii(0))
         ; using regional average in case the change is too important
         if abs(tt-calimb_bn(i)) gt 0.2 then tt=calimb_bn(i)/850.*ref_rhodv   ; how to set this threshold?
      endif else begin
         ; updating with regional average rho_dv
         tt=calimb_bn(i)/850.*ref_rhodv
      endelse
      calimb_bn(i)=tt
   endfor
endif

endelse

endif


; *************************************************************

; ------------
; Loop over three calibration phases
caliphase_statistics=dblarr(4)   ; info on top and low values for c_prec

for cphl=1,double(caliphase_loop) do begin
   
;if cphl gt 1 then calibration_phase=string(cphl,fo='(i1)')         ; like this in previous version, but why?? not working anymore in this version
calibration_phase=string(cphl,fo='(i1)')
if calibration_phase eq '2' or calibration_phase eq '3' then read_parameters='y'

; -------------------------------------
; determine calibration periods and target
if calibrate eq 'y' then begin

   if calibrate_glacierspecific eq 'n' then begin

      ii=where(calimb_regname eq dir_region and calimb_sregname eq sub_region and calimb_idname eq calperiod_ID,ci)
      if ci eq 0 then print, '!!! No calibration data available for this region / period !!!'
      target=calimb_bn(ii(0)) & target_uc=calimb_uc(ii(0)) & cran=[calimb_p0(ii(0)),calimb_p1(ii(0))]

      ; *** glacier-specific calibration
   endif else begin
      target_spec=calimb_bn & cran=[min(calimb_p0),max(calimb_p1)]
   endelse

endif

; --------------------------------------------------
; read parameter for individual regions from file

if read_parameters eq 'y' then begin

if calibration_phase eq '2' or calibration_phase eq '3' then a='' else a='_final_'+reanalysis
if rhodv_iteration ne '' then b='_rhodv' else b=''
fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+a+b+'.dat'
a=findfile(fn) & if a(0) eq '' then print,'!!! Parameter-File for '+sub_region+' is not available !!!'
cnc=12+double(meltmodel)
anz=file_lines(fn)-1 & da=dblarr(cnc,anz) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,da & close,1


; replace flagged values
ii=where(da(cnc-1,*) eq 1,ci) & jj=where(da(cnc-1,*) eq 0,cj)
if ci gt 0 and cj gt 0 and calibration_phase eq '1' then for i=8,9+double(meltmodel) do for j=0,cj-1 do da(i,jj(j))=mean(da(i,ii))

; attribute variables
cali_id=da(0,*)
if meltmodel eq '1' then begin
   cali_ddfice=da(9,*) & cali_ddfsnow=da(8,*) & cali_cprec=da(10,*) & cali_toff=da(11,*)
endif
if meltmodel eq '2' then begin
   cali_fm=da(8,*) & cali_rice=da(9,*) & cali_rsnow=da(10,*) & cali_cprec=da(11,*) & cali_toff=da(12,*)
endif
if meltmodel eq '3' then begin
   cali_c0=da(8,*) & cali_c1=da(9,*) & cali_a_ice=da(10,*) & cali_a_snow=da(11,*)
   cali_cprec=da(12,*) & cali_toff=da(13,*)
endif

endif

; including gridded T-offsets in calibration
if toff_grid eq 'y' and calibration_phase eq '1' and calibrate eq 'y' then begin
   if rhodv_iteration ne '' then begin
      b='_rhodv' & c=strmid(rhodv_iteration,10,1) & if double(c) ge 2 then b='_rhodv'+c
   endif else b=''
   fn=dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
   a=findfile(fn)
   if a(0) ne '' then begin
      anz=file_lines(fn) & da=dblarr(5,anz)  & openr,1,fn & readf,1,da & close,1
      toff_data=dblarr(anz) & cali_id_toff=da(0,*)
      for i=1,max(da(3,*)) do begin
         for j=1,max(da(4,*)) do begin
            ii=where(da(3,*) eq i and da(4,*) eq j,ci) & if ci gt 0 then toff_data(ii)=mean(da(1,ii))
         endfor
      endfor
   endif else toff_grid='n'
endif

; make sure parameters are double-precision
DDFsnow=double(DDFsnow) & DDFice=double(DDFice)
Fm=double(Fm) & r_ice=double(r_ice)/1000.*24. & r_snow=double(r_snow)/1000.*24.
C0=double(C0) & C1=double(C1)
c_prec=double(c_prec)

; --------------------------------------------
; read batch file

fn=dir_data+'../files/thick_'+region+'.dat' & anz=file_lines(fn)-1 & s=strarr(1) & st=strarr(anz)
openr,1,fn & readf,1,s & readf,1,st & close,1
tti=strarr(anz) & id=tti & tt=dblarr(19,anz)
for i=0l,anz-1 do begin
   a=strsplit(st(i),' ',/extract) & tti(i)=a(0) & for j=0,18 do tt(j,i)=double(a(j+1))
endfor
hmed=tt(8,*) & hmin=tt(6,*) & survey_year=tt(18,*) & volume_ini=tt(3,*) & xy=tt(0:1,*) & a_gl=tt(2,*)
lat_gl=xy(1,*) & lon_gl=xy(0,*) & tt=a_gl
for i=0l,anz-1 do id(i)=strsplit(tti(i),';',/extract)

; checking whether survey-year is known and filling up with average if necessary
ii=where(survey_year ne noval,ci) & jj=where(survey_year eq noval,cj)
if ci gt 0 and cj gt 0 then survey_year(jj)=mean(survey_year(ii))

years=tran(1)-tran(0)+1

nout=fix(years/outst)+1
nouty=indgen(nout)*outst

; restrict number of evaluated glaciers to those with WGMS data
if valiglaciers_only eq 'y' then begin
   fn=dir+'seasonal/validate_final2020/validate_WGMS_'+dir_region+'.dat' & an=file_lines(fn)-1 & ss=strarr(2,an)
   for i=0l,anz-1 do begin
      a=double(id(i))-double(ss(1,*)) & if min(abs(a)) ne 0 then a_gl(i)=-1. ; setting area to negative, so that it will not be computed
   endfor
endif

; attribute dimensions of region to be calculated automatically
if lat0(0) eq 9999 then begin
   lat0=[min(lat_gl)-0.1,max(lat_gl)+0.1]
   lon0=[min(lon_gl)-0.1,max(lon_gl)+0.1]
endif

; ------------------------------
; generating folder structure
if meltmodel eq '1' then mtt='' else mtt='_m3'

if tran(1) le 2023 then b='/PAST'+version_past+mtt

c=findfile(dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms))
if c(0) eq '' then begin
   spawn,'mkdir '+dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms) & spawn,'chmod a+rx '+dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms)
endif
c=findfile(dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps))
if c(0) eq '' then begin
   spawn,'mkdir '+dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
   spawn,'chmod a+rx '+dirres+dir_region+'/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
endif
if plot eq 'y' then begin
   c=findfile(dirres+dir_region+'/plots')
   if c(0) eq '' then spawn,'mkdir '+dirres+dir_region+'/plots/'
endif

; ------------------------------
; open result files
if calibrate ne 'y' and write_file eq 'y' then begin
   if reanalysis_direct eq 'y' then a='PAST'+version_past else a=GCM_model(gcms)+'/'+GCM_rcp(rcps)
   if single_glacier ne '' then a='SINGLE'

   if meltmodel eq '3' then plf='_m3' else plf='' 
   if meltmodel eq '1' and calperiod_ID eq 8 then  plf='_debris' 
   subpath='/files'+plf+'/'+a+'/'

   if meltmodel eq '1' then mtt='' else mtt='_m3'
   if meltmodel eq '1' and calperiod_ID eq 8 then  mtt='_debris' 

   if past_out eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/'
   if past_out eq 'y' and hindcast_dynamic eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/dyn/'

   openw,6,dirres+dir_region+subpath+long_GCM+sub_region+'.dat'
   printf,6,'ID    lat  lon    Area0    Volume0  dA(%)  dV(%)'

   if tran(1) lt 2021 then meteo_period=[2000,2019] else meteo_period=[2080,2099]
   openw,61,dirres+dir_region+subpath+long_GCM+sub_region+'_meteo.dat'
   printf,61,'Periods: 1980-1999 to '+string(meteo_period(0),fo='(i4)')+'-'+string(meteo_period(1),fo='(i4)')
   printf,61,'ID    lat  lon    Area0    dTannual  dTsum3 dTsum6(degC)  dPann(%)'

   y=indgen(years)+tran(0)
   for fid=10,10+n_elements(where(outf_names ne ''))-1 do begin
      openw,string(fid,fo='(i2)'),dirres+dir_region+subpath+long_GCM+sub_region+'_'+outf_names(fid-10)+'_'+experi_short+'.dat'
      printf,string(fid,fo='(i2)'),'ID  '+string(y,fo='('+strcompress(string(years),/remove_all)+'i6)')
   endfor

   openw,5,dirres+dir_region+subpath+long_GCM+sub_region+'_bias.dat'
   printf,5,'Lat  Lon(rea) dtemp  dprec  dvariab'

   openw,7,dirres+dir_region+subpath+long_GCM+sub_region+'_SLE_volbz.dat'
   printf,7,'Year  vol_<0masl(km3)'

   openw,33,dirres+dir_region+subpath+long_GCM+sub_region+'_calving_flux.dat'
   printf,33,'ID  frontal ablation (Gt/a)'

endif

; ******************************
; CALIBRATION LOOP - for overall calibration on entire region

cal0max=0
if calibrate eq 'y' and calibrate_individual ne 'y' then cal0max=20

for cal0=0,cal0max do begin

; settings for calibration file
if calibrate eq 'y' then begin
   plot='n' & tran=cran & write_file='n' & glacier_retreat='n'
   if rhodv_iteration ne '' then b='_rhodv' else b=''
   years=tran(1)-tran(0)+1
   openw,3,dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
   case meltmodel of
      '1': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    DDFsnow  DDFice   Cprec   T_off  Flag'
      '2': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    Fm       r_ice    r_snow   Cprec   T_off  Flag'
      '3': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    C0       C1       a_ice    a_snow   Cprec  T_off  Flag'
   endcase
   
   if calibrate_glacierspecific eq 'y' then begin
      openw,50,dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_overview_glspec'+b+'.dat'
      printf,50,'ID      Y0    Y1    Target    Ba         Bw     Area     ELA   AAR    DDFsnow  DDFice   Cprec   T_off  Flag'
   endif   

   openw,4,dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
endif

vol_bz=dblarr(years)    ; define array for storing ice volume below sea level

if tran(1) gt 2020 then rhodv_iteration=''           ; default, no rhodv-iteration

; ******************************
; LOOPs over grids

if grid_run eq 'n' then begin
   ngx=1 & ngy=1
   lat=lat0 & lon=lon0
endif else begin
   ngx=fix((lon0(1)-lon0(0))/grid_step)+1 & ngy=fix((lat0(1)-lat0(0))/grid_step)+1
;   ds_grid=dblarr(nout,ngx,ngy) & 	im_grid=dblarr(nout,ngx,ngy)
;   ar_grid=dblarr(nout,ngx,ngy) & 	vo_grid=dblarr(nout,ngx,ngy)
endelse

for gx=0,ngx-1 do begin

for gy=0,ngy-1 do begin

if grid_run eq 'y' then begin
   lon=[lon0(0)+gx*grid_step,lon0(0)+gx*grid_step+grid_step]
   lat=[lat0(0)+gy*grid_step,lat0(0)+gy*grid_step+grid_step]
endif

; ---------------------------
; select glacier subsample to be calculated
if lat(0) ne -99 and size_range(0) ne -99 then gg=where(xy(1,*) gt lat(0) and xy(1,*) lt lat(1) and xy(0,*) gt lon(0) and xy(0,*) lt lon(1) and a_gl gt size_range(0) and a_gl lt size_range(1) and volume_ini gt 0,cg)

; get a sample corresponding to all glaciers in the cell irrespective
; of size (for matching same reanalysis cell as for the overall calibration)
if lat(0) ne -99 and size_range(0) ne -99 then kk=where(xy(1,*) gt lat(0) and xy(1,*) lt lat(1) and xy(0,*) gt lon(0) and xy(0,*) lt lon(1) and volume_ini gt 0)

if lat(0) ne -99 and size_range(0) eq -99 then gg=where(xy(1,*) gt lat(0) and xy(1,*) lt lat(1) and xy(0,*) gt lon(0) and xy(0,*) lt lon(1) and volume_ini gt 0,cg)
if lat(0) eq -99 and size_range(0) ne -99 then gg=where(a_gl gt size_range(0) and a_gl lt size_range(1) and volume_ini gt 0,cg)
if single_glacier ne '' then gg=where(id eq single_glacier and volume_ini gt 0,cg)

; storage arrays
stor_im=dblarr(nout) & stor_dv=stor_im & stor_ar=stor_im & stor_vo=stor_im

; ******************************************
; climate series - generate individual series for every evaluation cell!

if cg gt 0 then begin

if calibrate eq 'n' then a=GCM_model(gcms)+'/'+GCM_rcp(rcps) else a='CALI - '+reanalysis
if total(a_gl(gg)) gt 10. and gx mod 2 eq 0 and gy mod 2 eq 0 then $
  print, dir_region+' '+clim_subregion+' ('+a+'): '+string(mean(lat),fo='(f5.1)')+'/'+string(mean(lon),fo='(f6.1)')+$
  ', '+string(total(a_gl(gg)),fo='(i5)')+'km2 ('+string(cg,fo='(i4)')+')'

; select / interpolate climate series from closest grid point
latitudes=lat_gl(gg) & longitudes=lon_gl(gg)
gmid=[mean(latitudes),mean(longitudes)]

; find corresponding grid cell of reanalysis-file
dtt=dblarr(2,nlons(0))
for i=0,nlons(0)-1 do begin
   a=min(sqrt((rlat-gmid(0))^2+(rlon(i)-gmid(1))^2),ind) & dtt(0,i)=a & dtt(1,i)=ind
endfor
a=min(dtt(0,*),ind2)
rmid=[rlat(ind),rlon(ind2)]

; ------------------------------
; meteo time series directly from re-analysis data (past)
if reanalysis_direct eq 'y' then begin

temp=dblarr((years+1)*12) & prec=temp & cyear=temp & cmon=temp & n=0l
for i=0,years do begin
   for m=1,12 do begin
      bb=where(rlat eq rmid(0)) & cc=where(rlon eq rmid(1)) & hh=where(ryear eq i+tran(0)-1 and rmon eq m,ci)
      cyear(n)=i+tran(0)-1 & cmon(n)=m
      if ci gt 0 then begin
         temp(n)=rtemp(hh(0),cc(0),bb(0))
         prec(n)=rprec(hh(0),cc(0),bb(0))
      endif
      n=n+1
   endfor
   if i eq 0 then hclim=relev(cc(0),bb(0))
endfor
if meltmodel ne '1' then begin
   mrad=dblarr(12) & mtt=indgen(12)
   for i=0,11 do begin
      hh=where(rmon eq i+1) & mrad(i)=rrad(hh(0),cc(0),bb(0))
   endfor
endif


; ---------------------------------
; ---------------------------------
; meteo time series downscaled from GCMs or whatever (future)
endif else begin

; find closest GCM-point
dtt=dblarr(2,n_elements(gcm_lon))
for i=0,n_elements(gcm_lon)-1 do begin
   a=min(sqrt((gcm_lat-rmid(0))^2+(gcm_lon(i)-rmid(1))^2),ind) & dtt(0,i)=a & dtt(1,i)=ind
endfor
a=min(dtt(0,*),ind2)
gcm_mid=[gcm_lat(ind),gcm_lon(ind2)]

; calculate monthly bias in the past
bias=dblarr(3,12)    ; (0) temp, (1) prec, (2) tvar

ii=where(gcm_lat eq gcm_mid(0))
jj=where(gcm_lon eq gcm_mid(1))
hh=where(gcm_year ge rea_eval(0) and gcm_year le rea_eval(1))

bb=where(rlat eq rmid(0))
cc=where(rlon eq rmid(1))

for m=1,12 do begin

   dd=where(ryear ge rea_eval(0) and ryear le rea_eval(1) and rmon eq m)

   if CMIP6 eq 'n' then begin
      kk=where(gcm_mon eq m)
      bias(0,m-1)=mean(gcm_temp(hh,kk(0),ii(0),jj(0)))-mean(rtemp(dd,cc(0),bb(0)))
      bias(1,m-1)=mean(gcm_prec(hh,kk(0),ii(0),jj(0)))/mean(rprec(dd,cc(0),bb(0)))
      if variability_bias eq 'y' then bias(2,m-1)=stdev(rtemp(dd,cc(0),bb(0)))/stdev(gcm_temp(hh,kk(0),ii(0),jj(0)))
   endif else begin
      kk=where(gcm_year ge rea_eval(0) and gcm_year le rea_eval(1) and gcm_mon eq m)      
      bias(0,m-1)=mean(gcm_temp(kk,jj(0),ii(0)))-mean(rtemp(dd,cc(0),bb(0)))
      bias(1,m-1)=mean(gcm_prec(kk,jj(0),ii(0)))/mean(rprec(dd,cc(0),bb(0)))
      if variability_bias eq 'y' then bias(2,m-1)=stdev(rtemp(dd,cc(0),bb(0)))/stdev(gcm_temp(kk,jj(0),ii(0)))
   endelse

   hclim=relev(cc(0),bb(0))

endfor

; optionally restrict temperature bias to a minimum value - if extreme 
; biases occur in Arctic regions air temperatures can suddenly become maximal
; during winter time
if min_tempbias ne noval then begin
   dd=where(bias(0,*) lt min_tempbias,cd)
   if cd gt 0 then bias(0,dd)=min_tempbias
endif

; optionally restrict precipitation bias to a minimum value - if GCM yields (almost) no precipitation on average the bias will become very small resulting in extreme precipitation rates (several 100 m!) if some prec is present
if min_precbias ne noval then begin
   dd=where(bias(1,*) lt min_precbias,cd)
   if cd gt 0 then bias(1,dd)=min_precbias
endif

; write Bias-file
if write_file eq 'y' then printf,5,rmid,bias(0,*),bias(1,*),bias(2,*),fo='(2f9.3,36f8.3)'

if meltmodel ne '1' then begin
   mrad=dblarr(12) & mtt=indgen(12)+1
   for i=1,12 do begin
      hh=where(mtt eq i) & mrad(i-1)=rrad(hh(0),cc(0),bb(0))
   endfor
endif

; time series with Bias-corrected GCM-data
temp=dblarr((years+1)*12) & prec=temp & rad=temp & cyear=temp & cmon=temp & n=0l
for i=0,years do begin
; use re-analysis data as long as available! After (AND before) use GCM data
   if i+tran(0) le max(ryear) and i+tran(0) gt min(ryear) then begin   
      for m=1,12 do begin
         bb=where(rlat eq rmid(0)) & cc=where(rlon eq rmid(1)) & hh=where(ryear eq i+tran(0)-1 and rmon eq m,ci)
         cyear(n)=i+tran(0)-1 & cmon(n)=m
         if ci gt 0 then begin
            temp(n)=rtemp(hh(0),cc(0),bb(0))
            prec(n)=rprec(hh(0),cc(0),bb(0))
         endif else stop        
         if meltmodel ne '1' then rad(n)=mrad(m-1)         
         n=n+1
      endfor
   endif else begin
; use projections only for unmeasured future   
      hh=where(gcm_year eq i+tran(0)-1)
      for m=1,12 do begin
         cyear(n)=i+tran(0)-1 & cmon(n)=m
         
         if CMIP6 eq 'n' then begin
            kk=where(gcm_mon eq m)
            temp(n)=gcm_temp(hh(0),kk(0),ii(0),jj(0))-bias(0,m-1)
            prec(n)=gcm_prec(hh(0),kk(0),ii(0),jj(0))/bias(1,m-1)
         endif else begin
            kk=where(gcm_year eq i+tran(0)-1 and gcm_mon eq m,ck)
            ; hack for GCMs only extending to 2099 / 2298
            if ck eq 0 then kk=where(gcm_year eq i+tran(0)-2 and gcm_mon eq m,ck)
            if ck eq 0 then kk=where(gcm_year eq i+tran(0)-3 and gcm_mon eq m,ck)
            temp(n)=gcm_temp(kk(0),jj(0),ii(0))-bias(0,m-1)
            prec(n)=gcm_prec(kk(0),jj(0),ii(0))/bias(1,m-1)
         endelse         

         if meltmodel ne '1' then rad(n)=mrad(m-1)
         
         n=n+1
      endfor
   endelse
   
endfor

; --------------------
; adapt temperature variability of GCM to re-analysis
if variability_bias eq 'y' then begin

   ; smoothed monthly temperature time series
   tm_smooth=dblarr(12,years+1)
   for i=0,years do for m=0,11 do tm_smooth(m,i)=temp(12*i+m)
   for m=0,11 do begin
      tt=dblarr(years+1) & for i=0,years do tt(i)=tm_smooth(m,i)
      tm_smooth(m,*)=rmean(rmean(tt,5),25)
   endfor
   for i=0,years do for m=0,11 do temp(12*i+m)=tm_smooth(m,i)+(temp(12*i+m)-tm_smooth(m,i))*bias(2,m)

endif

endelse

; ----------------------------------------
; determine local monthly gradients from reanalysis-data using a regression
dtdz=dblarr(12) & mtt=indgen(12)+1
for m=1,12 do begin
   hh=where(mtt eq m)
   dtdz(m-1)=rtg(hh(0),cc(0),bb(0))
endfor

; determine sub-monthly T-variability from reanalysis data
if submonth_variability eq 'y' then begin

variab=dblarr(12,31)
vf=dblarr(12)+1 & vf(0:2)=0.5 & vf(10:11)=0.5
for m=1,12 do begin
   hh=where(mtt eq m)
   variab(m-1,*)=rvariab(hh(0),*,cc(0),bb(0))*vf(m-1)
endfor

endif

endif

; *****************************************************
; MAIN LOOP over all glaciers


for g=0l,cg-1 do begin

; ******************************
; CALIBRATION LOOP - for single-glacier calibration

cal1max=0
if calibrate_individual eq 'y' then begin
   cal1max=15
   if rhodv_iteration ne '' then  cal1max=25
endif

for cal1=0,cal1max do begin


; ---------------------
; read hypsometry-file
fn=dir_data+'/'+region+'/'+id(gg(g))+'.dat' & a=findfile(fn)

if a(0) ne '' then begin

nb=file_lines(fn)-5
s=strarr(5) & da=dblarr(12,nb)
openr,1,fn & readf,1,s & readf,1,da & close,1

; performing a check on consensus thickness data and replace with
; HF2012(updated) if needed
if min(da(1,*)) lt -300 or abs(a_gl(gg(g))-total(da(3,*)))*100./a_gl(gg(g)) gt 50 then begin
   fn=dir_data_alt+'/'+region+'/'+id(gg(g))+'.dat' & a=findfile(fn)
   nb=file_lines(fn)-5 & s=strarr(5) & da=dblarr(12,nb)
   openr,1,fn & readf,1,s & readf,1,da & close,1
endif
   
; add bands at glacier tongue
if advance eq 'y' and nb gt 3 then begin
    adv_addband=adv_addband0
   if adv_calving lt 0 then adv_hmin=adv_calving else adv_hmin=10.
   if hmin(gg(g))-adv_addband*10. lt adv_hmin then adv_addband=fix((hmin(gg(g))-adv_hmin)/10)
   adv_addband=max([0,adv_addband])
   nb0=nb & nb=nb+adv_addband & tt=da & da=dblarr(12,nb) & da(*,nb-nb0:nb-1)=tt(*,0:nb0-1)
   for i=nb-nb0-1,0,-1 do da(1,i)=da(1,i+1)-10.
endif

; find geothermal heat flux for glacier
if firnice_temperature eq 'y' then begin
   a=min(abs(latitudes(g)-fit_yy),indy) &  a=min(abs(longitudes(g)-fit_xx),indx)
   geothermal_flux=firnice_geotherm_flux(indx,indy)
endif

; define variables
area=da(3,*) & elev=da(1,*)+5 & thick=da(4,*) & width=da(5,*) & slope=da(7,*)
ii=where(area gt 0 and thick eq 0,ci) & if ci gt 0 then thick(ii)=3. ; prevent division by 0 due to error in thick-file
bed_elev=elev-thick & step=elev(1)-elev(0) & e0=elev(0) & elev0=elev
; correcting unrealistic values in lowest band
if bed_elev(0) lt 0 and thick(0) gt thick(1)+2. then begin
   thick(0)=thick(1)+2. & bed_elev=elev-thick
endif
; bedrock profile corrected for Parabola-shape
bed_elev_p=bed_elev-bedrock_parabolacorr*thick
for i=0,nb-1 do if width(i) gt (crit_ccorrdist/2.) then bed_elev_p(i)=bed_elev(i)-thick(i)*bedrock_parabolacorr*(crit_ccorrdist/2.)/width(i)


ii=where(thick gt 0,ci) & if calibrate eq 'y' and ci eq 0 then thick=thick+1.
gl=dblarr(nb)+noval &  if ci gt 0 then gl(ii)=elev(ii)
length=dblarr(nb) & for i=0,nb-1 do length(i)=(max(da(6,*))-da(6,i))/1000.
thick_ini=thick & area_ini=area & width_ini=width
area_iniconst=area   ; will not be affected by glacier advance!
volume0=total(thick_ini*area_ini)/1000.
tgs_cum=dblarr(nb)   ; array for storing local air temperatures

; ------------------------------
; prepare output for mass balance in elevation bands
if write_mb_elevationbands eq 'y' then begin

   if meltmodel eq '1' then mtt='' else mtt='_m3'
   b='/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
   if reanalysis_direct eq 'y' then b='/PAST'+mtt
   c=findfile(dirres+dir_region+b+'/mb_elevation'+rhodv_iteration)
   if c(0) eq '' then begin
      spawn,'mkdir '+dirres+dir_region+b+'/mb_elevation'+rhodv_iteration & spawn,'chmod a+rx '+dirres+dir_region+b+'/mb_elevation'+rhodv_iteration
   endif

   openw,8,dirres+dir_region+b+'/mb_elevation'+rhodv_iteration+'/belev_'+id(gg(g))+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran(0),fo='(i4)')+'  '
   printf,8,'Elev  '+a+a
   elev_bmb=dblarr(years,nb)+snoval & elev_bwb=elev_bmb 

   ; elevation-specified refreezing files 
   c=findfile(dirres+dir_region+b+'/refr_elevation'+rhodv_iteration)
   if c(0) eq '' then begin
      spawn,'mkdir '+dirres+dir_region+b+'/refr_elevation'+rhodv_iteration & spawn,'chmod a+rx '+dirres+dir_region+b+'/refr_elevation'+rhodv_iteration
   endif
   openw,40,dirres+dir_region+b+'/refr_elevation'+rhodv_iteration+'/refrelev_'+id(gg(g))+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran(0),fo='(i4)')+'  '
   printf,40,'Elev  '+a &  elev_refr=dblarr(years,nb)+snoval 

   if debris_supraglacial eq 'y' then begin
   ; elevation-specified debris files 
      c=findfile(dirres+dir_region+b+'/debris_elevation')
      if c(0) eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/debris_elevation' & spawn,'chmod a+rx '+dirres+dir_region+b+'/debris_elevation'
      endif
      openw,41,dirres+dir_region+b+'/debris_elevation/debthick_'+id(gg(g))+'.dat'
      a='' & for i=0,years-1 do a=a+string(i+tran(0),fo='(i4)')+'  '
      printf,41,'Elev  '+a &  elev_debthick=dblarr(years,nb)+snoval 

      openw,42,dirres+dir_region+b+'/debris_elevation/debfrac_'+id(gg(g))+'.dat'
      printf,42,'Elev  '+a &  elev_debfrac=dblarr(years,nb)+snoval 

      openw,43,dirres+dir_region+b+'/debris_elevation/debfactor_'+id(gg(g))+'.dat'
      printf,43,'Elev  '+a &  elev_debfactor=dblarr(years,nb)+snoval 

      ;openw,44,dirres+dir_region+b+'/debris_elevation/pondarea_'+id(gg(g))+'.dat'
      ;printf,44,'Elev  '+a &  elev_pondarea=dblarr(years,nb)+snoval 

      if eval_mbelevsensitivity eq 'y' then begin
         openw,44,dirres+dir_region+b+'/debris_elevation/mbsensitivity_'+id(gg(g))+'.dat'
         printf,44,'Elev  '+a &  elev_mbsens=dblarr(years,nb)+snoval &  elev_mbsensall=dblarr(count_mbelevsens_v0+1,years,nb)+snoval 
      endif
   endif
endif

; prepare output of ice temperature model
if firnice_temperature eq 'y' then begin

   if meltmodel eq '1' then mtt='' else mtt='_m3'
   b='/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
   if reanalysis_direct eq 'y' then b='/PAST'+mtt

   if firnice_write(0) eq 'y' then begin
      c=findfile(dirres+dir_region+b+'/firnice_temperature')
      if c(0) eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+dir_region+b+'/firnice_temperature'
      endif
      openw,45,dirres+dir_region+b+'/firnice_temperature/temp_1m_'+id(gg(g))+'.dat'
      a='' & for i=0,years-1 do a=a+string(i+tran(0),fo='(i4)')+'  '
      printf,45,'Elev  '+a 
      elev_firnicetemp=dblarr(4,years,nb)+snoval ; all layers

      openw,46,dirres+dir_region+b+'/firnice_temperature/temp_10m_'+id(gg(g))+'.dat'
      printf,46,'Elev  '+a 

      openw,47,dirres+dir_region+b+'/firnice_temperature/temp_50m_'+id(gg(g))+'.dat'
      printf,47,'Elev  '+a 

      openw,48,dirres+dir_region+b+'/firnice_temperature/temp_bedrock_'+id(gg(g))+'.dat'
      printf,48,'Elev  '+a 

   endif

   if firnice_write(1) eq 'y' then begin
      c=findfile(dirres+dir_region+b+'/firnice_temperature')
      if c(0) eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+dir_region+b+'/firnice_temperature'
      endif

      ; determining elevations to be outputted
      firnice_profile_ind=dblarr(2,n_elements(firnice_profile)) ; index / abs elev.
      if firnice_profile(0) lt 1 then begin  ; relative elev
         for i=0,n_elements(firnice_profile)-1 do begin
            firnice_profile_ind(0,i)=fix(firnice_profile(i)*nb) & firnice_profile_ind(1,i)=elev0(firnice_profile_ind(0,i))
         endfor
      endif else begin  ; abs elev
         for i=0,n_elements(firnice_profile)-1 do begin
            a=min(abs(elev0-firnice_profile(i)),ind)
            firnice_profile_ind(0,i)=ind & firnice_profile_ind(1,i)=elev0(firnice_profile_ind(0,i))
         endfor
      endelse
      
      for j=0,n_elements(firnice_profile)-1 do begin
         openw,51+j,dirres+dir_region+b+'/firnice_temperature/temp_ID'+firnice_profile_ID(j)+'_'+id(gg(g))+'.dat'
         printf,51+j,'Point elevation  '+string(firnice_profile_ind(1,j),fo='(i4)')+' masl: Depth in m'
         a='' & for i=1,total(fit_layers)-1 do a=a+string(fit_dz(1,i),fo='(i4)')+'  '
         printf,51+j,'Year  Month '+a 
      endfor
   endif

endif

;prepare output for hypsometry-evolution file
if write_hypsometry_files eq 'y' then begin
   b='/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
   if reanalysis_direct eq 'y' then b='/PAST'
   c=findfile(dirres+dir_region+b+'/hypsometry')

   if c(0) eq '' then spawn,'mkdir '+dirres+dir_region+b+'/hypsometry' & if b(0) eq '' then spawn,'chmod a+rx '+dirres+dir_region+b+'/hypsometry'
   openw,9,dirres+dir_region+b+'/hypsometry/hypso_'+id(gg(g))+'.dat'
   openw,34,dirres+dir_region+b+'/hypsometry/volume_'+id(gg(g))+'.dat'
   openw,35,dirres+dir_region+b+'/hypsometry/temp_'+id(gg(g))+'.dat'

   ctt=0 & h=strarr(1)
   for i=tran(0),tran(1) do begin
      if i mod 10 eq 0 then begin
         ctt=ctt+1 & h=h+string(i,fo='(i4)')+'        '
      endif
   endfor
   hypso_file=dblarr(4,ctt,nb)+snoval &  printf,9,h &  printf,34,h &  printf,35,h & chypso=0
endif 

; -----------------------------
; initialise some variables for the advance scheme
if advance eq 'y' and nb gt 3 then begin
    jj=where(area_ini ne 0,cj)
    tt=max([0,fix(cj*adv_terminusfraction)-1]) ; determine indices for terminus region
	; define amplification of 'hypothetical' initial areas in front of glacier
    adv_iniamplification=dblarr(nb)+1
    for i=jj(0)-1,0,-1 do adv_iniamplification(i)=1+((jj(0)-i)/(adv_addband/2.))^3.
	; define some more variables
    adv_iniar=mean(area_ini(jj(0:tt))) & adv_inithi=mean(thick_ini(jj(0:tt)))  & adv_iniwid=mean(width_ini(jj(0:tt)))
    if cj ne nb then width(where(width eq 0))=mean(width(jj(0:tt)))
    dl=(length(jj(0))-length(jj(tt)))/(tt+1)
    for i=jj(0)-1,0,-1 do length(i)=length(i+1)+dl
endif

; -------------------
; potential radiation time series
if meltmodel eq '2' or meltmodel eq '3' then begin

   sw_rad=dblarr(nb,12) & z=dblarr(12) & phi0=dblarr(12) & aspect=da(8,*)

   ; smooth aspect/slope -  prevent discontinuities in surface mb - does it work?
   ii=where(aspect ne 0,ci)
   if ci gt 0 then begin
      tt=dblarr(ci) & for i=0,ci-1 do tt(i)=aspect(ii(i)) & tt2=rmean(rmean(tt,11),3) & for i=0,ci-1 do aspect(ii(i))=round(tt2(i))
      tt=dblarr(ci) & for i=0,ci-1 do tt(i)=slope(ii(i)) & & tt2=rmean(rmean(tt,11),3) & for i=0,ci-1 do slope(ii(i))=tt2(i)
   endif
   ii=where(aspect eq 0,ci) & if ci gt 0 then aspect(ii)=1

   if dir_region eq 'LowLatitudes' then begin    ; check if sun perpendicular and correct
      if min(abs(latitudes(g)-decl_sun),ind) lt 0.05 then begin
         if decl_sun(ind)-latitudes(g) lt 0 then a=0.05 else a=-0.05
      endif else a=0.
   endif else a=0.
   for i=0,11 do z(i)=acos(sin((latitudes(g)+a)/180.*3.14159)*sin(decl_sun(i)/180.*3.14159)+ $
     cos((latitudes(g)+a)/180.*3.14159)*cos(decl_sun(i)/180.*3.14159))*180./3.14159
   for i=0,11 do phi0(i)=cos(z(i)/180.*3.14159)
   ii=where(phi0 lt 0.01,ci) & if ci gt 0 then phi0(ii)=0.01   ; prevent division by zero and inversion of pattern
   for j=0,nb-1 do for i=0,11 do sw_rad(j,i)=mrad(i)*(cos(slope(j)/180.*3.14159)*cos(z(i)/180.*3.14159)+ $
      sin(slope(j)/180.*3.14159)*sin(z(i)/180.*3.14159)*cos((180-asp_class(aspect(j)-1))/180.*3.14159))/phi0(i)
	ii=where(sw_rad lt 0,ci) & if ci gt 0 then sw_rad(ii)=0

endif

; ---------------------
; read files for supraglacial debris

if debris_supraglacial eq 'y' then begin
   fn=dir_data+'../debris/'+region+'/debris_'+id(gg(g))+'.dat' & a=findfile(fn)

   if a(0) ne '' then begin
      anz=file_lines(fn)-5 & s=strarr(5) & da=dblarr(8,anz)
      openr,1,fn & readf,1,s & readf,1,da & close,1

      ; adding more bands in front of glacier in case that advance is allowed
      if advance eq 'y' and nb gt 3 then begin
         nb0=nb-adv_addband &  tt=da & da=dblarr(8,nb) & da(*,nb-nb0:nb-1)=tt(*,0:nb0-1)
      endif else adv_addband=0

      debris_thick=da(5,*) & debris_frac=da(4,*)
      debris_mf=da(6,*) & debris_ponddens=da(7,*)
   endif else begin             ; debris file not present; setting debris to zero everywhere
      debris_thick=dblarr(nb) & debris_frac=dblarr(nb) & debris_mf=dblarr(nb)+1 & debris_ponddens=dblarr(nb)
   endelse
   debris_thick0=debris_thick
   if debris_pond_enhancementfactor eq 0 then debris_ponddens=dblarr(nb)  ; setting pond density to zero for default value
   ii=where(debris_frac eq 0,ci) & if ci gt 0 then debris_ponddens(ii)=0  ; no ponds possible without debris coverage

   ; read debris melt-reduction file (Ostrem-curve)
   fn=dir_data+'../debris/'+region+'/factor_'+id(gg(g))+'.dat' & a=findfile(fn)
   if a(0) ne '' then begin
      anz=file_lines(fn)-3 & s=strarr(3) & da=dblarr(3,anz)
      openr,1,fn & readf,1,s & readf,1,da & close,1
      debris_type_th=da(1,*) & debris_type_red=da(2,*) 
   endif 
endif

; ---------------------
; attribute specific parameter values

if read_parameters eq 'y' and cal1 eq 0 then begin

   a=min(abs(double(id(gg(g)))-cali_id),ind)

	case meltmodel of
      '1': Begin
         DDFice=cali_ddfice(ind) & DDFsnow=cali_ddfsnow(ind) & C_prec=cali_cprec(ind)
         t_offset=cali_toff(ind)
      	end
      '2': begin
         Fm=cali_fm(ind) & r_ice=cali_rice(ind) & r_snow=cali_rsnow(ind) & C_prec=cali_cprec(ind)
         t_offset=cali_toff(ind)
      	end
      '3': begin
         C0=cali_c0(ind) & C1=cali_c1(ind) & alb_ice=cali_a_ice(ind) & alb_snow=cali_a_snow(ind)
         C_prec=cali_cprec(ind) & t_offset=cali_toff(ind)
		end
      endcase

endif

if toff_grid eq 'y' and calibrate eq 'y' and calibration_phase ne '3' then begin
   a=min(abs(double(id(gg(g)))-cali_id_toff),ind)
   t_offset=toff_data(ind)
endif

; ---------------------
; define arrays
gls=dblarr(nout,nb) & cnp=0
areas=dblarr(years) & volumes=areas
flux_calv=areas

sur=dblarr(nb) & sno=sur & snostor=sur
firn=sur & ff=where(elev gt hmed(gg(g)),ci) & if ci gt 0 then firn(ff)=1
baly=dblarr(years,nb)
if nb gt elev_range_p/step and plot eq 'y' then begin
   accy=baly & mely=baly & refry=baly
endif
if outf_names(14) ne '' then begin
   balmo=dblarr(years*12)+snoval & melmo=balmo & accmo=balmo & refrmo=balmo & discharge_gl=balmo & precmo=balmo
endif
mb=dblarr(years)+snoval & wb=mb
smelt=dblarr(years) & imelt=smelt & accum=smelt & rain=smelt & refre=smelt
ela=dblarr(years)+snoval & dbdz=ela & btongue=ela & aar=ela & hmin_g=ela
discharge=dblarr(years*12) & area_cat=total(area)

if adv_lookup eq 'y' then adv_lookup_data=dblarr(3,nb,years)

; ********************************************
; MAIN LOOP over years

if hindcast_dynamic eq 'y' then glacier_retreat='n'   
if find_startyear eq 'y' then glacier_retreat='n'   
if find_startyear eq 'n' then glacier_retreat='n'     ; unsure if well solved... static/dynamic runs (=> glogemflow) just separated by find_startyear

ccmon=0l

te_rf=dblarr(nb,rf_layers) & tl_rf=te_rf 

; firn/ice temperature, lowermost layer: bottom of ice if thick > domain
; initialise with long-term annual mean air temperature to get efficient spin up
tt=dblarr(nb) & ii=where(cyear lt 2020,ci)
for i=0,nb-1 do begin
   if ci gt 0 then a=temp(ii)+(elev(i)-hclim)*mean(dtdz)+t_offset $
     else a=temp+(elev(i)-hclim)*mean(dtdz)+t_offset
   tt(i)=mean(a)
endfor
te_fit=dblarr(nb,total(fit_layers)+1)
for i=0,nb-1 do te_fit(i,*)=tt(i) & tl_fit=te_fit 


for ye=0,years-1 do begin

if eval_mbelevsensitivity eq 'y' then begin
   count_mbelevsens=count_mbelevsens_v0 ; initialising to start value of counter

   mbelevsensitivity_again:
   elev=elev0-count_mbelevsens*50.  ; elevation step 
   count_mbelevsens=count_mbelevsens-1
endif

; define arrays
bal=dblarr(nb) & melt=bal & acc=bal & refreeze=bal
debris_red_factor=dblarr(nb)+snoval
rf_ind=dblarr(nb) & rf_cold=rf_ind
ii=where(gl ne noval,ci) & if ci gt 0 then ar_gl=total(area(ii)) else ar_gl=0
if elev(0) gt elev(1)+100 then elev(0)=elev(1)

; allow glacier area changes in hindcast period after date of RGI
if hindcast_dynamic eq 'y' then if ye+tran(0) ge survey_year(gg(g)) then glacier_retreat='y'    

; determining date for starting the retreat of each individual glacier
; depending on RGI-outline date (GLACIER-SPECIFIC!) - take care for evaluation
if find_startyear eq 'y' then if ye+tran(0) gt survey_year(gg(g)) then glacier_retreat='y' 

; glacier retreat to 'n' if local mass balance gradients are evaluated 
if eval_mbelevsensitivity eq 'y' then glacier_retreat='n' 

; different parts of hydrological year
for d=0,1 do begin

if d eq 0 then st=bal_month else st=1
if d eq 0 then en=12 else en=bal_month-1

; ****************************
; loop over months
for m=st,en do begin

psg=dblarr(nb) & mel=psg & refr=psg & corrdis=psg

; correct snow storage array
if bal_month eq 10 then if m eq 1 then sno=sno-snostor
if bal_month eq 4 then if m eq 7 then sno=sno-snostor
jj=where(sno lt 0,cj) & if cj gt 0 then sno(jj)=0

; *******************************************
; Climate data extrapolation


if ccmon eq 0 then jjclim=where(cyear eq ye-1+tran(0) and cmon eq m)
tg=temp(jjclim(0)+ccmon)+(elev-hclim)*dtdz(m-1)+t_offset

; *******************************************
; Mass balance model

; *********** accumulation

pc=prec(jjclim(0)+ccmon)*c_prec/1000.        ; correct quantity
pg=pc+pc*((elev-hclim)/10000.)*dpdz    ; extrapolate with elevation
; constrain high elevation precipitation
jj=where(gl ne noval,cj)
if cj*step gt no_incprec(1) then begin
   ii=where(elev gt elev(jj(fix(cj*no_incprec(0)))),ci) &  if ii(0) eq 0 then a=1 else a=0
   for i=0,ci-1 do pg(ii(i))=pg(ii(a)-1)-pg(ii(a)-1)*no_incprec(2)*(i/double(ci)*(1-no_incprec(0)))^no_incprec(3)
endif
; state of precipitation
ii=where(tg lt T_thres-1,ci)
if ci gt 0 then psg(ii)=pg(ii)
ii=where(tg gt T_thres-1 and tg lt T_thres+1,ci)
if ci gt 0 then psg(ii)=pg(ii)*(-(tg(ii)-T_thres-1.)/2.)
plg=pg-psg
psg=psg*snow_multiplier

if ar_gl ne 0 then accum(ye)=accum(ye)+total(psg*area)/ar_gl
if ar_gl ne 0 then rain(ye)=rain(ye)+total(plg*area)/ar_gl

ccmon=ccmon+1

; ***********  melt (positive)

; sub-monthly variability (excluded by default for energy balance model!)
if submonth_variability eq 'y' and meltmodel ne '3' then begin

a=dblarr(mon_len(m-1)) & tgs=tg
; superimpose variability / make sure no shift in mean T is introduced!
for i=0,mon_len(m-1)-1 do a(i)=tgs(0)+variab(m-1,i)-mean(variab(m-1,0:mon_len(m-1)-1))
for j=0,nb-1 do begin
   b=a+(tgs(j)-tgs(0))
   ii=where(b gt 0,ci) & if ci gt 0 then pdd=total(b(ii)) else pdd=0.
   if pdd gt 0 then tg(j)=pdd/mon_len(m-1)
endfor

endif else tgs=tg
tgs_cum=tgs_cum+tgs

; ----------
case meltmodel of

'1': BEGIN

ii=where(sur eq 1 and tg gt t_melt,ci)    ; snow
if ci gt 0 then begin
   mel(ii)=DDFsnow*tg(ii)*mon_len(m-1)/1000.
   jj=where(gl(ii) ne noval,cj)
   if cj gt 0 and ar_gl ne 0 then smelt(ye)=smelt(ye)+total(mel(ii(jj))*area(ii(jj)))/ar_gl
endif

ii=where(sur eq 2 and tg gt t_melt,ci)    ; Firn
if ci gt 0 then begin
   mel(ii)=(0.5*DDFice+0.5*DDFsnow)*tg(ii)*mon_len(m-1)/1000.
   imelt(ye)=imelt(ye)+total(mel(ii)*area(ii))/ar_gl
endif

ii=where(sur eq 0 and tg gt t_melt,ci)   ; Ice
if ci gt 0 then begin
   mel(ii)=DDFice*tg(ii)*mon_len(m-1)/1000.
   imelt(ye)=imelt(ye)+total(mel(ii)*area(ii))/ar_gl
endif

if debris_supraglacial eq 'y' then begin

ii=where(sur eq 0 and tg gt t_melt and debris_thick gt 0 and debris_frac gt 0,ci)   ;  debris-covered ice
if ci gt 0 then begin
   for i=0l,ci-1 do begin
      a=min(abs(debris_thick(ii(i))-debris_type_th),ind) ; looking for closest value (may be improved by interpolating)
      if write_mb_elevationbands eq 'y' then debris_red_factor(ii(i))=debris_type_red(ind)
      ; debris-covered ice + bare ice + area of ponds/cliffs 
      mel(ii(i))=(debris_frac(0,ii(i))-debris_ponddens(ii(i)))*debris_type_red(ind)*mel(ii(i))  +  (1.-debris_frac(0,ii(i)))*mel(ii(i))  +  debris_ponddens(ii(i))*debris_pond_enhancementfactor*mel(ii(i))
   endfor
   imelt(ye)=imelt(ye)+total(mel(ii)*area(ii))/ar_gl   ; updating array from above
endif

endif                           ; debris

end

; ---------
'3': BEGIN

ii=where(sur eq 1,ci)    ; snow
if ci gt 0 then begin
   mel(ii)=((1.-alb_snow)*sw_rad(ii,m-1)+C0+C1*tg(ii))*3600*24.*mon_len(m-1)/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel(jj)=0
   smelt(ye)=smelt(ye)+total(mel(ii)*area(ii))/ar_gl
endif

ii=where(sur eq 2,ci)    ; Firn
if ci gt 0 then begin
   mel(ii)=((1.-alb_firn)*sw_rad(ii,m-1)+C0+C1*tg(ii))*3600*24.*mon_len(m-1)/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel(jj)=0
   imelt(ye)=imelt(ye)+total(mel(ii)*area(ii))/ar_gl
endif

ii=where(sur eq 0,ci)   ; Ice
if ci gt 0 then begin
   mel(ii)=((1.-alb_ice)*sw_rad(ii,m-1)+C0+C1*tg(ii))*3600*24.*mon_len(m-1)/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel(jj)=0
   imelt(ye)=imelt(ye)+total(mel(ii)*area(ii))/ar_gl
endif

end

ENDCASE


; ***************************************
; ***********  refreezing (positive)

if refreezing_full eq 'y' then begin

ii=where(gl ne noval,ci)
for i=0,ci-1 do begin

if mel(ii(i)) lt rf_melcrit then rf_ind(ii(i))=1 else rf_ind(ii(i))=0

if rf_ind(ii(i)) eq 1 then begin     ; start builing up cold reservoir

   for h=0,rf_dsc-1 do begin

      ; heat conduction
      for j=1,rf_layers-2 do begin

         tl_rf(ii(i),0)=tgs(ii(i))
         te_rf(ii(i),j)=tl_rf(ii(i),j)+((rf_dt*cond(j)/(cap(j))*(tl_rf(ii(i),j-1)-tl_rf(ii(i),j))/rf_dz^2.)- $
             (rf_dt*cond(j)/(cap(j))*(tl_rf(ii(i),j)-tl_rf(ii(i),j+1))/rf_dz^2.))/2. ; division by 2 to be removed?! keeping it for consistency at the moment...
         tl_rf(ii(i),*)=te_rf(ii(i),*)

      endfor
   endfor

endif else begin
; ----------------------------
; evaluating cold reservoir

; refreezing over firn surface
if firn(ii(i)) eq 1 then begin

if rf_cold(ii(i)) eq 0 then for j=1,rf_layers-2 do rf_cold(ii(i))=rf_cold(ii(i))+(-1)*tl_rf(ii(i),j)*cap(j)*rf_dz/Lh_rf
if (mel(ii(i))+plg(ii(i))) lt rf_cold(ii(i)) then refr(ii(i))=(mel(ii(i))+plg(ii(i))) else if rf_cold(ii(i)) gt 0 then refr(ii(i))=rf_cold(ii(i))
rf_cold(ii(i))=rf_cold(ii(i))-mel(ii(i))-plg(ii(i))
if rf_cold(ii(i)) lt 0 then rf_cold(ii(i))=snoval
if rf_cold(ii(i)) eq snoval then tl_rf(ii(i),*)=0  ; temperate firn if cold reservoir used

endif else begin
; refreezing over ice surface

pp=0.3   ; add a bit more as water can also refreeze directly at bare-ice surface
smax=round(sno(ii(i))/(dens_rf(0)/1000.)/rf_dz+pp) & if sno(ii(i)) gt 0 and smax eq 0 then smax=1 & if smax eq 0 then rf_cold(ii(i))=snoval
if smax gt rf_layers-1 then smax=rf_layers-1
if rf_cold(ii(i)) eq 0 then for j=1,smax do rf_cold(ii(i))=rf_cold(ii(i))+(-1)*tl_rf(ii(i),j)*cap(j)*rf_dz/Lh_rf
if (mel(ii(i))+plg(ii(i))) lt rf_cold(ii(i)) then refr(ii(i))=(mel(ii(i))+plg(ii(i))) else if rf_cold(ii(i)) gt 0 then refr(ii(i))=rf_cold(ii(i))
rf_cold(ii(i))=rf_cold(ii(i))-mel(ii(i))-plg(ii(i))
if rf_cold(ii(i)) lt 0 then rf_cold(ii(i))=snoval
if rf_cold(ii(i)) eq snoval then tl_rf(ii(i),*)=0    ; temperate firn if cold reservoir used

endelse

endelse    ; use cold reservoir

endfor

if ar_gl ne 0 then refre(ye)=refre(ye)+total(refr*area)/ar_gl

endif


; ***************************************
; ***********  firn/ice temperatures
; (separate workflow as the target and setup differs)

if firnice_temperature eq 'y' then begin

ii=where(gl ne noval,ci)
for i=0,ci-1 do begin

; generate local, and actualized arrays for layer heat capacity, condictivity and density
dens_fit=dblarr(total(fit_layers))+900  
a=fix(sno(ii(i))/(fit_dens(1)/1000.)) ; number of snow layers
if a gt 18 then a=18            ; preventing too many layers for extreme snow depth (??)
; replacing top of density profile with snow values
for j=0,a-1 do dens_fit(j)=fit_dens(j)
; replacing top of density profile with firn values for the firn area
if firn(ii(i)) eq 1 then for j=min([a,5]),17 do dens_fit(j)=fit_dens(j) ; to be verified...

cap_fit=(1-dens_fit/1000.)*cair+dens_fit/1000.*cice
cond_fit=(1-dens_fit/1000.)*kair+dens_fit/1000.*kice

a=min(abs(thick(ii(i))-fit_dz(1,*)),ind)
tt=min([ind+1,total(fit_layers)]) ; either run to bedrock, or to max of layers
if firnice_batch eq 'y' then begin
   a=min(abs(firnice_maxdepth(0)-fit_dz(1,*)),ind) ; run to actual depth of profile in batch/validation-mode
   tt=ind+1
endif

   for h=0,rf_dsc-1 do begin

      ; heat conduction
      for j=1,tt-2 do begin

         tl_fit(ii(i),0)=min([0,tgs(ii(i))]) ; temperature of topmost layer corresponding to air temperature or melting point!
         ; temperature of bottommost layer warmed up by geothermal heat flux (cumulative energy over one time step over a )
         ttgeot=tl_fit(ii(i),tt-1)+geothermal_flux*(3600*24*30.5/rf_dsc)/cice       ; /fit_dz(0,tt-1) ; unclear how to attribute a layer thickness for collecting flux (1m at the moment...)
         
         tl_fit(ii(i),tt-1)=min([ttgeot,(fit_dz(1,tt-1)*0.9/10.)*(-0.00742)])    ; cannot be higher than pressure melting point
         
         te_fit(ii(i),j)=tl_fit(ii(i),j)+((rf_dt*cond_fit(j)/(cap_fit(j))*(tl_fit(ii(i),j-1)-tl_fit(ii(i),j))/fit_dz(0,j)^2.)- $
             (rf_dt*cond_fit(j)/(cap_fit(j))*(tl_fit(ii(i),j)-tl_fit(ii(i),j+1))/fit_dz(0,j)^2.))/2. ; division by 2 to be removed?! result becomes unstable without ?!?
         tl_fit(ii(i),j)=te_fit(ii(i),j)

         ; set back any temperatures to pressure melting point
         if tl_fit(ii(i),j) gt (fit_dz(1,j)*0.9/10.)*(-0.00742) then tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742)

      endfor
   endfor

; setting all bedrock temperatures to lowermost computed layer (to avoid constant warming from beneath)
tl_fit(ii(i),tt-1:total(fit_layers))=tl_fit(ii(i),tt-2)

fit_water=mel(ii(i))+plg(ii(i))  ; liquid water available from surface (melt+rain)

; latent heat release over firn/snow surface (entirely permeable)
if firn(ii(i)) eq 1 then begin

for j=1,tt-2 do begin ; loop through all considered layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
 ;  if j eq 10 and ii(i) eq 245 then print, m,c,fit_water,tl_fit(ii(i),10)
endfor

endif else begin

; latent heat release over ice surface, incl. seasonal snow (mainly impermeable)
kk=where(dens_fit lt 900,ck)
for j=1,ck do begin ; loop through all SNOW layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
endfor

; reduce liquid water input through glacier ice by a factor proportional to local characteristics (thickness / slope ~flow speed)
f=(slope(ii(i))^2*fact_permeability(0))*(thick(ii(i))*fact_permeability(1))
if f gt 0.5 then f=0.5     ; setting maximum value for overall reduction factor - to be assessed 
if f lt 0.0001 then f=0.0001     ; setting minimum value for overall reduction factor - to be assessed 
fit_water=fit_water*f      ; reducing amount of water entering glacier ice

for j=ck+1,tt-2 do begin ; loop through all ICE layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
;   if j eq 10 and ii(i) eq 20 then print, m,c,fit_water,tl_fit(ii(i),20),f
endfor

endelse

; prepare for output
if firnice_write(0) eq 'y' then begin
         ; maximum temperature in layer during one year
   elev_firnicetemp(0,ye,ii(i))=max([elev_firnicetemp(0,ye,ii(i)),tl_fit(ii(i),2)])  ; 2m
   elev_firnicetemp(1,ye,ii(i))=max([elev_firnicetemp(1,ye,ii(i)),tl_fit(ii(i),10)]) ; 10m 
   elev_firnicetemp(2,ye,ii(i))=max([elev_firnicetemp(2,ye,ii(i)),tl_fit(ii(i),18)]) ; 50m 
   elev_firnicetemp(3,ye,ii(i))=max([elev_firnicetemp(3,ye,ii(i)),tl_fit(ii(i),30)]) ; bedrock
endif

if firnice_write(1) eq 'y' then begin
   for j=0,n_elements(firnice_profile)-1 do begin
      if ii(i) eq firnice_profile_ind(0,j) then begin
         a=tl_fit(firnice_profile_ind(0,j),1:total(fit_layers)) & a(tt-2:total(fit_layers)-1)=snoval
         printf,51+j,ye+tran(0),m,a,fo='(2i4,'+string(total(fit_layers),fo='(i2)')+'f8.3)'
      endif
   endfor
endif

endfor

endif    ; firn-ice temperature model



; ---- adapting snow reservoir
;      correcting for overestimated melt (disapperance of snow during month)
sno=sno+psg-mel;   +refreeze - should refreezing be included here?
jj=where(sno gt 0,cj) & if cj gt 0 then sur(jj)=1
jj=where(sno lt 0,cj)
if cj gt 0 then begin
   hh=where(gl(jj) eq noval,ch)
   if ch gt 0 then mel(jj(hh))=mel(jj(hh))+sno(jj(hh))
 ; correction for ice-free area in glacierized elevation bands - only relevant for calculating catchment discharge
   hh=where(gl(jj) ne noval,ch)
   if ch gt 0 then corrdis(jj(hh))=mel(jj(hh))+sno(jj(hh))  
   sno(jj)=0
endif

; ------- calculate catchment discharge
;    Melting and refreezing are the same inside and outside the
;    glacier if snow cover present; if no snow melting and refreezing
;    only refer to the ice surface => weighted average for specific discharge
difarea=area_iniconst-area & ii=where(difarea lt 0,ci) & if ci gt 0 then difarea(ii)=0
ii=where(area_iniconst gt 0,ci) & dd=0
for i=0l,ci-1 do begin
   if sur(ii(i)) eq 1 then dd=dd+mel(ii(i))*area_iniconst(ii(i))+plg(ii(i))*area_iniconst(ii(i))-refr(ii(i))*area_iniconst(ii(i))-corrdis(ii(i))*difarea(ii(i)) $
   else begin
      if area_iniconst(ii(i)) lt area(ii(i)) then a=area_iniconst(ii(i)) else a=area(ii(i))
      dd=dd+mel(ii(i))*a+plg(ii(i))*area_iniconst(ii(i))-refr(ii(i))*a
   endelse
endfor
discharge(ccmon-1)=dd/area_cat

; ---- adapting surface type
jj=where(sno eq 0 and gl ne noval,cj) & if cj gt 0 then sur(jj)=0
jj=where(sno eq 0 and gl eq noval,cj) & if cj gt 0 then sur(jj)=noval
jj=where(sno eq 0 and firn eq 1,cj) & if cj gt 0 then sur(jj)=2

; cumulate balances - store results
bal=bal+psg-mel+refr
melt=melt+mel
acc=acc+psg
refreeze=refreeze+refr

if ar_gl ne 0 then begin
   if outf_names(14) ne '' then begin
      balmo(ccmon-1)=total((psg-mel+refr)*area)/ar_gl & melmo(ccmon-1)=total(mel*area)/ar_gl
      accmo(ccmon-1)=total(psg*area)/ar_gl & refrmo(ccmon-1)=total(refr*area)/ar_gl
      discharge_gl(ccmon-1)=(total(mel*area)+total(plg*area)-total(refr*area))/ar_gl & precmo(ccmon-1)=total((psg+plg)*area)/ar_gl 

; for entire catchment
      balmo(ccmon-1)=total((psg-mel+refr)*area)/total(area_ini) & refrmo(ccmon-1)=total(refr*area)/total(area_ini)
      precmo(ccmon-1)=total((psg+plg)*area_ini)/total(area_ini)

   endif
   if bal_month eq 10 then if m eq 4 then wb(ye)=total(bal*area)/ar_gl
   if bal_month eq 4 then if m eq 10 then wb(ye)=total(bal*area)/ar_gl

   ; set bal-array to noval in case there is no glacier
   ii=where(gl eq noval,ci) & if ci gt 0 then bal(ii)=snoval

   if write_mb_elevationbands eq 'y' then begin
      if bal_month eq 10 then if m eq 4 then elev_bwb(ye,*)=bal
      if bal_month eq 4 then if m eq 10 then elev_bwb(ye,*)=bal
      if bal_month eq 10 then if m eq 9 then elev_bmb(ye,*)=bal
      if bal_month eq 4 then if m eq 3 then elev_bmb(ye,*)=bal
      if bal_month eq 10 then if m eq 9 then elev_refr(ye,*)=refreeze*1000.
      if bal_month eq 4 then if m eq 3 then elev_refr(ye,*)=refreeze*1000.
      if eval_mbelevsensitivity eq 'y' then begin
         if bal_month eq 10 then if m eq 9 then elev_mbsensall(count_mbelevsens+1,ye,*)=bal
         if bal_month eq 4 then if m eq 3 then elev_mbsensall(count_mbelevsens+1,ye,*)=bal
      endif
   endif
endif

endfor                          ; loop over months

endfor                          ; parts of hydrological year

; evaluations for mass balance sensitivity to elevation
if eval_mbelevsensitivity eq 'y' then begin
   if count_mbelevsens ge 0 then begin
      ccmon=ccmon-12  ; set back the months counter      
      goto, mbelevsensitivity_again 
   endif else begin
      bb=n_elements(elev_mbsensall(*,0,0)) & a=dblarr(1,bb) & b=dblarr(bb) & c=b
      for i=0,nb-1 do begin
         for j=0,bb-1 do a(0,j)=elev_mbsensall(j,ye,i) & for j=0,bb-1 do b(j)=j*50*(-1.) & for j=0,bb-1 do c(j)=1. ; c not needed for IDL!
         ; tt=correlate(a,b)  ; use this for IDL!
         tt=regress(a,b,c) 
         elev_mbsens(ye,i)=1./tt*100.    ; local mass balance gradient in year ye in m w.e. / 100m
      endfor
   endelse
endif


; calculate balance - store results
if ar_gl ne 0 then mb(ye)=total(bal*area)/ar_gl
baly(ye,*)=bal
if nb gt elev_range_p/step and plot eq 'y' then begin
   ii=where(gl eq noval,ci) & if ci gt 0 then melt(ii)=noval
   accy(ye,*)=acc  & mely(ye,*)=melt  & refry(ye,*)=refreeze
endif
balv=bal*area*1000000.

snostor=sno

; --------- update firn coverage
; look 5 years back and average mass balance
; => firn where average mb > 0
if ye gt 4 then begin
   balm=dblarr(nb)
   for i=0,nb-1 do balm(i)=mean(baly(ye-4:ye,i))
   firn=dblarr(nb) & ii=where(balm gt 0 and gl ne noval,ci) & if ci gt 0 then firn(ii)=1
endif


; --------------------------
; statistics (area and volume stored BEFORE surface updating - reference for calculations)
area1=total(area) & areas(ye)=area1 & volume1=total(thick*area)/1000. & volumes(ye)=volume1
area_stor=area
bb=where(bed_elev lt 0 and bed_elev gt -800. and thick gt 0,cb)
if cb gt 0 then vol_bz(ye)=vol_bz(ye)-0.001*total(bed_elev(bb)*area(bb))

; more statistics
jj=where(thick gt 0,cj)
if cj gt 0 then begin
   ht1=elev(jj(0)) 
   ii=where(bal(jj) gt 0,ci) & if ci gt 0 then aar(ye)=total(area_stor(jj(ii)))*100./area1 else aar(ye)=0
   btongue(ye)=min(bal(jj),ind) &  if ci gt 0 then ela(ye)=elev(jj(ii(0))) else ela(ye)=max(elev)
   da=(elev(jj(ind))-ela(ye)) & if abs(da) gt 20 then dbdz(ye)=btongue(ye)/da else dbdz(ye)=0.
endif else ht1=max(elev)
hmin_g(ye)=ht1

jj=where(gl eq noval,cj) & if cj gt 0 then sur(jj)=noval
; check if there is a glacier left - if not end  the loop!!!
if outf_names(n_elements(where(outf_names ne ''))-1) eq 'n' then if cj eq nb then ye=1000

if write_hypsometry_files eq 'y' then begin
   if (ye+tran(0)) mod 10 eq 0 then begin
      hypso_file(0,chypso,*)=elev & hypso_file(1,chypso,*)=area & hypso_file(2,chypso,*)=area*thick
      hypso_file(3,chypso,*)=tgs_cum/(10*12.) & tgs_cum=dblarr(nb) ; set array back
      chypso=chypso+1
   endif
endif

; store glacier geometry for previous volumes
if adv_lookup eq 'y' then begin
   adv_lookup_data(0,0,ye)=volume1   ; storing easily accessible overall volume
   adv_lookup_data(1,*,ye)=area      ; storing area distribution
   adv_lookup_data(2,*,ye)=thick     ; storing thickness distribution
endif

; *******************************
; DEBRIS MODEL
; annually adapting debris cover extent and thickness
if debris_supraglacial eq 'y' and ar_gl gt 0 then begin

; get current long-term GEOMETRIC ELA of glacier (55% acc area, 45% abl area)
; debris is only updated BELOW this theshold, actually there should be not debris above!
if ye lt 10 then begin
   a=0
   debris_seed_meters=10.    ; annual increase in elevation range, where seeding is possible
   for i=0,nb-1 do begin
      a=a+area(i) &  medelev=i & if a gt ar_gl*0.45 then i=nb
   endfor
; if ELA is computed internally for more than 10 years, use decadal average instead of median elevation
endif else begin
   a=mean(ela(ye-10:ye-1)) & b=min(abs(elev-a),ind) & medelev=ind
  ; find ELA-dependent seeding factor based on regression of ELA-changes during the last 10 years
   debris_seed_meters=mean(mb(ye-10:ye-1))*debris_seed_bands*(-1.)
endelse


; get time interval since start of dynamic model
debris_time=0
if ye+tran(0) gt survey_year(gg(g)) then debris_time=ye+tran(0)-survey_year(gg(g))


; spatial expansion of debris and ponds/cliffs over time
;    clean-ice glacier will remain clean-ice glaciers!
;    glaciers without ponds/cliff will not get any!
if debris_expansion eq 'y' and debris_time gt 0 then begin        

; debris extension
count_seed_bands=0
   for i=0,medelev do begin
      ; case 1: debris present in band but not everywhere => extension WITHIN band
      if debris_frac(i) gt 0 and debris_frac(i) lt 1 then begin
         if bal(i) lt 0 and gl(i) ne noval then debris_frac(i)=debris_frac(i)+(debris_exp_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*max([debris_frac(i),0.25])
         ; max([debris_frac(i),0.25]) to ensure that at least a minimal number of extension is present, otherwise negilgible for small debris-fractions (to be verified)
         if debris_frac(i) gt 1 then debris_frac(i)=1
      endif
      ; case 2: no debris (yet) present in band => seeding from neighbouring bands
      ;   initial debris seed is the average of surrounding bands
      ;   per year, seed can only be laid in a number of bands defined by debris_seed_bands
      if i gt 0 and i lt nb-2 and count_seed_bands le debris_seed_meters/step then begin
         if debris_frac(i) eq 0 and max(debris_frac(i-1:i+1)) gt 0 then begin
            debris_frac(i)=(debris_frac(i-1)+debris_frac(i+1))/2
            debris_thick(i)=debris_initialband 
            count_seed_bands=count_seed_bands+1
         endif
      endif   
   endfor

; extension of ponds and cliffs (to used as no global data on ponds and cliffs are available)
count_seed_bands=0
   for i=0,medelev do begin
      ; case 1: ponds present in band => growth band
      if debris_ponddens(i) gt 0 then begin
         if bal(i) lt 0 and gl(i) ne noval then debris_ponddens(i)=debris_ponddens(i)+(debris_pond_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*max([debris_ponddens(i),0.02])
         ; max([debris_ponddens(i),0.02]) min value of 0.02 to be verified
         if debris_ponddens(i) gt debris_ponddens_max then debris_ponddens(i)=debris_ponddens_max 
      endif
      ; case 2: no ponds (yet) present in band => seeding from neighbouring bands
      ;   initial pond seed is the average of surrounding bands
      ;   per year, seed can only be laid in a number of bands defined by debris_seed_bands
      if i gt 0 and i lt nb-2 and count_seed_bands le debris_seed_meters/step  then begin
         if debris_ponddens(i) eq 0 and max(debris_ponddens(i-1:i+1)) gt 0 then begin
            debris_ponddens(i)=(debris_ponddens(i-1)+debris_ponddens(i+1))/2
            count_seed_bands=count_seed_bands+1
         endif
      endif   
   endfor

endif

if debris_thickening eq 'y' and debris_time gt 0 then begin       ; thickening of debris over time
   ; only applying debris thickening IF a debris thickness is already present, i.e. not increasing a zero debris thickness!

   for i=0,medelev do begin
      ; original code
;      if debris_thick(i) gt 0 then debris_thick(i)=debris_thick0(i)+(debris_thick_gradient/100.)*debris_time*(elev(medelev)-elev(i))/1000. 

      ; Compagno et al 2021, scaled with local MB, glacier-wide MB, mean initial debris thickness
      ; if debris_frac(i) gt 0 then debris_thick(i)=debris_thick(i)+(debris_thick_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*mean(debris_thick0(0:medelev))    

      ; revised to allow more thickening on originally thin debris
      if debris_frac(i) gt 0 then begin
         kk=where(debris_thick0 gt 0,ck) & if ck gt 0 then mean_debris_t=mean(debris_thick0(kk)) else mean_debris_t=debris_initialband
      ; account for effective mass balance in debris-covered area, instead of mass balance of entire elevation band!
         debris_baleff=bal(i)/(debris_frac(i)*debris_red_factor(i)+(1-debris_frac(i)))
         debris_thick(i)=debris_thick(i)+(debris_thickening_fact/100.)*debris_baleff*mean(mb(ye-min([ye,10]):ye))*mean_debris_t     
      endif
   endfor
   ii=where(debris_thick lt 0,ci) & if ci gt 0 then debris_thick(ii)=0
   ; limit thickening to 5m to prevent unrealistic values
   ii=where(debris_thick gt 5,ci) & if ci gt 0 then debris_thick(ii)=5
endif

; prepare for output
if write_mb_elevationbands eq 'y' then begin
   for i=0,nb-1 do begin
      if gl(i) ne noval then begin
         elev_debthick(ye,i)=debris_thick(i) & elev_debfrac(ye,i)=debris_frac(i)
         elev_debfactor(ye,i)=debris_red_factor(i); & elev_pondarea(ye,i)=debris_ponddens(i)*area(i)
      endif
   endfor
endif

endif


; *******************************************
; *******************************************
; glacier retreat model

ii=where(balv ne noval,ci)
if ci gt 0 then dvol=total(balv(ii)) else dvol=0
jj=where(balv gt 0,cj) & if cj gt 0 then av=total(balv(jj)) else av=0
dens=0.9 & dvol=dvol/dens

; *******************************************
; CALVING MODEL
; -----------------------------
; volume loss due to frontal ablation

ii=where(thick gt 0,ci) & fa='n' 
if ci gt 6 then begin
   jj=where(bed_elev(ii) lt 0,cj)
   if min(bed_elev(ii(0:1))) lt 0 and cj gt 1 then fa='y'
endif
q_calv=0. & dvolsurf=dvol

if frontal_ablation eq 'y' and fa eq 'y' then begin

Hf=max([alpha_f*(length(ii(0))*1000.*length_corrfact)^0.5,-1.127*mean(bed_elev_p(ii(0:1)))])
;F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])
F=min([0,c_calving*mean(bed_elev_p(ii(0:1)))*Hf*mean(slope(ii(1:min([11,ci-1]))))])
;F=min([0,c_calving*mean(bed_elev(ii(0):ii(1)))*Hf])
;F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])

;q_front=F*mean(width(ii(0:1)))*(-1.)
frontal_width=mean(width(ii(0:1)))
ccorr_param=crit_ccorrdist/(crit_ccorrdist)^(1/ccorr_expon)
if frontal_width lt crit_ccorrdist then eff_width=frontal_width $
  else eff_width=(frontal_width)^(1/ccorr_expon)*ccorr_param
q_front=F*eff_width*(-1.)

; restricting frontal ablation to total accumulated volume to avoid
; unrealistically (climatological sense) high frontal ablation rates!!

; * implementation until Jan 2021
;if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.75
; different constraints for antarctica
;if dir_region eq 'Antarctic' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.25   
;if dir_region eq 'Greenland' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.40   
; * implementation from feb 2021 - keep threshold constant, also for future to avoid break
fcfact=1.0

tt=total(area)*max(acc)*1000000.*fcfact
; low calving losses are always possible...
if tt lt 0.2*total(area)*1000000. then tt=0.2*total(area)*1000000.
if q_front gt tt(0) then q_front=tt

q_front_spec=q_front/1000000.*dens/ar_gl
if q_front_spec lt calv_sep then f=1. else f=1-((q_front_spec-calv_sep)/q_front_spec)
dvol=dvol-(q_front*f) & q_calv=q_front-(q_front*f)
flux_calv(ye)=q_front_spec
;if single_glacier ne '' then print, 'Frontal ablation (Gt/a): ('+string(ye+tran(0),fo='(i4)')+')'+string(q_front/1000000000.,fo='(f8.4)')
;if q_front/1000000000. gt 0.1 then print, 'Frontal ablation (Gt/a): ('+id(gg(g))+')'+string(q_front/1000000000.,fo='(f8.4)')

if ye eq tran(0) then if q_front/1000000000. gt 0.0005 then printf,33, id(gg(g)),total(area),q_front/1000000000.,fo='(a,2f10.4)'

endif

; *******************************************

if glacier_retreat eq 'y' then begin

; -----------------------------
; update surface geometry

ii=where(thick gt 0 and area gt 0,ci)

; initialize dh-param if elevation range of glacier larger than 10m, else non-dyn downwasting
if ci gt 0 then begin

; normalized dh-function
dh=dblarr(nb)+noval & hr=dh & hr0=elev(ii(ci-1))-elev(ii(0))
if hr0 eq 0 then hr0=10  ; avoid division by 0 when only one band is present
for i=0,ci-1 do hr(ii(i))=(elev(ii(ci-1))-elev(ii(i)))/hr0   ; elevation range
; dh function
ta=total(area)
if ta gt dh_size(1) then for i=0,ci-1 do dh(ii(i))=(hr(ii(i))-0.02)^6+0.12*(hr(ii(i))-0.02)         ; large
if ta gt dh_size(0) and ta le dh_size(1) then for i=0,ci-1 do dh(ii(i))=(hr(ii(i))-0.05)^4+0.19*(hr(ii(i))-0.05)+0.01    ; medium
if ta le dh_size(0) then for i=0,ci-1 do dh(ii(i))=(hr(ii(i))-0.30)^2+0.60*(hr(ii(i))-0.30)+0.09    ; small
jj=where(dh gt 1,cj) & if cj gt 0 then dh(jj)=1
jj=where(dh lt 0 and dh ne noval,cj) & if cj gt 0 then dh(jj)=0


; distribute volume change - dh-function
if abs(total(dh(ii)*area(ii))) gt 0 then  f=dvol/(total(dh(ii)*area(ii)*1000000)) else f=0.
delev=dblarr(nb)+noval & delev(ii)=dh(ii)*f

; make sure that this section is only activated if volume will afterwards NOT be
;   distributed by the glacier advance scheme!
rda='y' & if advance eq 'y' and dvol gt 0 and f gt adv_fcrit then rda='n'

if redistribute_vplus eq 'y' and rda eq 'y' then begin
; check for elevation changes larger than mass balance rate (only
; lower ablation area!)

if dvol lt 0 then bal_crit=-1. else bal_crit=0.
if dvol lt 0 then a=-1. else a=1.
jj=where(abs(delev(ii(0:fix(ci/6)))) gt abs(bal(ii(0:fix(ci/6)))/0.9),cj)
vplus=0
if cj gt 0 then begin
   for i=0,fix(ci/6)-1 do begin
      if abs(delev(ii(i))) gt abs(bal(ii(i))/0.9) and bal(ii(i)) lt bal_crit then begin
         vplus=vplus+balv(ii(i))*(1-((bal(ii(i))/0.9)/((-a)*delev(ii(i)))))
         delev(ii(i))=(-a)*bal(ii(i))/0.9
      endif
   endfor

; distribute removed volume over the remaining glacier
   jj=where(thick gt 5,cj)   ; critical thickness (thicknesses below are not touched!)
   if cj gt 3 then begin     ; do redistribution only if there are some elevation bands left
      at=total(area(jj))*1000000. & dhp=vplus/at
      for j=0,cj-1 do delev(jj(j))=delev(jj(j))+dhp
   endif else delev=bal/0.9              ; apply mass balance rate if glacier at minimal thickness everywhere
endif

endif

; ------------------------------
; glacier advance scheme
if advance eq 'y' and dvol gt 0 and f gt adv_fcrit then begin

; run classic advance model only when current volume is bigger than
; the initial one, i.e. in an ''unexplored'' range of geometries
   delev(ii)=dh(ii)*f           ; set back to original parameterization
   ; determine 'excess' volume
   ; defined as elevation change at 10% of the glacier's elev. range
   ; 95% for CALVING GLACIERS
   adv_delevcrit_frac=0.1
   kk=where(gl ne noval,ck) & if ck gt 0 and bed_elev(kk(0)) lt 0 then adv_delevcrit_frac=0.95
   adv_delevcrit=delev(ii(fix(ci*adv_delevcrit_frac))) 
   b=max(delev,ind) & if adv_delevcrit eq b then  adv_delevcrit=max(delev(where(delev ne b)))
   a=delev-adv_delevcrit & jj=where(a gt 0,cj)
   if cj gt 0 then v_adv=total(a(jj)*area(jj)) else v_adv=0 ; mio m3
   if cj gt 0 then delev(jj)=adv_delevcrit                         ; set delev back to maximum thickness increase

; remove tiny thickness values (unclear where they are generated...)
   jj=where(thick lt 0.01,cj) & if cj gt 0 then thick(jj)=0 & if cj gt 0 then area(jj)=0
   
	; distribute excess volume
   hh=where(area ne 0,cj) & tt=thick
   if cj gt 0 and hh(0) ne 0 then begin ; only if there is space in front of the glacier
      for i=hh(0)-1,0,-1 do begin

			; set values for 'hypothetical' initial areas and volumes
         if area_ini(i) eq 0 then area_ini(i)=adv_iniar*adv_iniamplification(i)
         if thick_ini(i) eq 0 then thick_ini(i)=adv_inithi*adv_iniamplification(i)
         if width_ini(i) eq 0 then width_ini(i)=adv_iniwid*adv_iniamplification(i)

			; calculate and distribute the 'advance volume';
			;      target ice thickness in each band will be taken from the one above
         v_adv=v_adv-adv_iniar*(tt(i+1)+adv_delevcrit)
         delev(i)=tt(i+1)+adv_delevcrit & tt(i)=tt(i+1)
         if v_adv lt 0 then begin
              ; correct thickness of last added elevation band for overshoot 
            delev(i)=delev(i)+v_adv/adv_iniar
            goto, endsearch
         endif
      endfor
   endif else begin
	; distribute excess volume EQUALLY if there is no space left for an advance...
      if ye gt 0 then att=areas(ye-1) else att=areas(ye)
      if fa ne 'y' then delev(where(delev ne noval))=delev(where(delev ne noval))+v_adv/att $
        ;  different approach for calving glaciers - put all to lowest elevation band, where it will be removed below sea level
      else delev(0)=v_adv/area(0)
   endelse
   endsearch:
   ii=where(delev ne noval)

endif else begin    ; if advance no second iteration of delev!!! does not seem to be working ...

; --------------------------------------------------
; !! calculate elevation band area change !!
darea=dblarr(nb) & vcorr=0. & tt=thick+delev
for i=0,ci-1 do if tt(ii(i)) ge 0 then	darea(ii(i))=area_ini(ii(i))*(tt(ii(i))/thick_ini(ii(i)))^(1./expon)-area(ii(i))
for i=0,ci-1 do vcorr=vcorr+darea(ii(i))/2.*delev(ii(i))  ;  [mio m3]   ; cumulate volume to be corrected
; redistribute additional volume using dh-parameterization
if abs(total(dh(ii)*area(ii))) gt 0 and finite(vcorr) then begin
   fcorr=vcorr/(total(dh(ii)*area(ii)))
   delev(ii)=delev(ii)-dh(ii)*fcorr
endif

endelse

; apply surface elevation change
thick(ii)=thick(ii)+delev(ii)    ; thickness

; set bedrock elevation for new elevation bands (important for calving glaciers)
jj=where(bed_elev eq elev and thick gt 0 and elev eq elev0,cj) & if cj gt 0 then bed_elev(jj)=elev(jj)-thick(jj)
; hack for artificially putting new bands into the ocean if the glacier is already calving
if fa eq 'y' and cj gt 0 then bed_elev(jj)=bed_elev(jj)+min(bed_elev)  
for i=0,cj-1 do if width(jj(i)) gt (crit_ccorrdist/2.) then bed_elev_p(jj(i))=bed_elev(jj(i))-thick(jj(i))*bedrock_parabolacorr*(crit_ccorrdist/2.)/width(jj(i))

jj=where(thick le 0,cj)
if cj gt 0 then begin
   vol_lost=total(thick(jj)*area(jj))
   if vol_lost lt 0 then begin
      if abs(total(dh(ii)*area(ii))) gt 0 then  fcorr=vol_lost/(total(dh(ii)*area(ii))) else fcorr=0.
      thick(ii)=thick(ii)+dh(ii)*fcorr
      jj=where(thick le 0,cj)
   endif  
   thick(jj)=0 & area(jj)=0 & elev(jj)=bed_elev(jj)     ; set to zero if no glacier left
endif

area0=area
band_volume=thick*area           ; volume per elevation band before adapting band area
ii=where(thick_ini gt 0,ci)
for i=0,ci-1 do area(ii(i))=area_ini(ii(i))*(thick(ii(i))/thick_ini(ii(i)))^(1./expon)
kk=where(bed_elev lt 0,ck)
for i=0,ck-1 do width(kk(i))=width_ini(kk(i))*(thick(kk(i))/thick_ini(kk(i)))^(1./expon)

; update the volume-conserving mean thickness!
ii=where(area0 gt 0 and area gt 0,ci)
for i=0,ci-1 do thick(ii(i))=band_volume(ii(i))/area(ii(i))
for i=0,ci-1 do elev(ii(i))=bed_elev(ii(i))+thick(ii(i))      ; surface elevation calculated with updated band thickness

; explicitely enforce mass conservation
vtt=total(area*thick)-volumes(ye)*1000. ; 10^6 m3
ii=where(thick gt 0 and dh eq noval,ci) & if ci gt 0 then dh(ii)=2 ; account for advance elevation bands not covered in dh-param
ii=where(thick gt 0,ci)
if ci gt 0 then begin
   if abs(total(dh(ii)*area(ii))) gt 0 then  fcorr=(vtt-dvol/1000000.)/(total(dh(ii)*area(ii))) else fcorr=0.
   if abs(fcorr) lt 10 then begin   ; only allowing correction if fcorr is more or less reasonable... (no idea why runaway effects occur)
      thick(ii)=thick(ii)-dh(ii)*fcorr
      jj=where(thick le 0,cj)
      if cj gt 0 then begin
         thick(jj)=0 & area(jj)=0 & elev(jj)=bed_elev(jj) ; set to zero if no glacier left
      endif
                                ; updating surface elevation again
      for i=0,ci-1 do elev(ii(i))=bed_elev(ii(i))+thick(ii(i)) ; surface elevation calculated with updated band thickness
      jj=where(thick gt 0,cj) & if cj gt 0 then gl(jj)=elev(jj)
   endif
endif

; ----- calving
; terminus break-off due to calving

; cut off elevation bands located below sea level and add mass loss to calving
ii=where(elev lt 0 and area gt 0,ci)   
if ci gt 0 then begin
   q_calv=q_calv+total(thick(ii)*area(ii))*1000000.
   flux_calv(ye)=flux_calv(ye)+q_calv/1000000.*dens/ar_gl
endif

if q_calv ne 0 then begin
   ii=where(thick ne 0,ci)
   vcum=0
   for i=0,ci-1 do begin
      vcum=vcum+thick(ii(i))*area(ii(i))*1000000.
      if vcum lt q_calv then begin
         thick(ii(i))=0 & area(ii(i))=0 & elev(ii(i))=bed_elev(ii(i))
      endif else begin
         tt=vcum-thick(ii(i))*area(ii(i))*1000000.
         thick(ii(i))=thick(ii(i))*(vcum-q_calv)/(vcum-tt)
         elev(ii(i))=bed_elev(ii(i))+thick(ii(i))
         area(ii(i))=area_ini(ii(i))*(thick(ii(i))/thick_ini(ii(i)))^(1./expon)
         goto, end_calv
      endelse
   endfor
   end_calv:
endif

ii=where(area eq 0,ci) & if ci gt 0 then gl(ii)=noval

endif else begin

; ----------------------------
; very small glaciers

; apply surface elevation change
for i=0,ci-1 do thick(ii(i))=thick(ii(i))+bal(ii(i))/0.9    ; thickness
for i=0,ci-1 do elev(ii(i))=elev(ii(i))+bal(ii(i))/0.9      ; surface elevation
for i=0,ci-1 do area(ii(i))=area_ini(ii(i))*(thick(ii(i))/thick_ini(ii(i)))^(1./expon)      ; area in elevation band
jj=where(thick lt 0,cj)
if cj gt 0 then begin
   thick(jj)=0 & area(jj)=0 & elev(jj)=bed_elev(jj) & gl(jj)=noval    ; set to zero if no glacier left
endif

endelse

; ----------------------------
; advance from look-up table

; determine geometry based on look up table of previous volumes
if adv_lookup eq 'y' and dvol gt 0 and volume1 lt volume0 then begin
   ; searching for next known target volume
   a=min(abs((volume1+dvol/1000000000.)-adv_lookup_data(0,0,*)),ind)
   for i=0,nb-1 do area(i)=adv_lookup_data(1,i,ind)

   ; correcting for error to enforce mass conservation
   vtt=adv_lookup_data(0,0,ind)-(volume1+dvol/1000000000.)
   ii=where(area gt 0,ci)
   if ci gt 0 then begin
      if abs(total(dh(ii)*area(ii))) gt 0 then fcorr=(vtt*1000.)/(total(dh(ii)*area(ii))) else fcorr=0.
      thick(ii)=adv_lookup_data(2,ii,ind)-dh(ii)*fcorr
      jj=where(thick le 0,cj)
      if cj gt 0 then begin
         thick(jj)=0 & area(jj)=0 & elev(jj)=bed_elev(jj) ; set to zero if no glacier left
      endif
      elev(ii)=bed_elev(ii)+thick(ii) ; surface elevation calculated with updated band thickness
      jj=where(thick gt 0,cj) & if cj gt 0 then gl(jj)=elev(jj)
   endif

endif

; storing of results
if ye mod 10 eq 0 then gls(cnp,*)=elev
if ye mod 10 eq 0 then cnp=cnp+1

endif                           ; glacier retreat


endfor    ; Loop over years


; ----------------------------------------
; ****************************************
; Optimization - SINGLE-GLACIER MASS BALANCE

if calibrate_individual eq 'y' then begin

; determine potential variability range
if cal1 eq 0 then begin
   fc=2.-max([0,mean(wb)/4.]) & if fc lt 1.3 then fc=1.3
   ; for calperiod_ID=5 (Hugonnet, regional) use uncertainty in regional mb
   if calperiod_ID eq 5 then begin
      cal_crit=target_uc
   endif else begin
   ; dynamic critical deviation arbitrarily... depending on accumulation rates
      cal_crit=0.02*double(calibration_phase)+(0.04)/(fc-1.)
       ; reducing critical match by half during rhodv iteration to force recalibration
      if rhodv_iteration ne '' then cal_crit=0.01*double(calibration_phase)+(0.04)/(fc-1.)
   endelse

endif

; account for calving fluxes during the calibration period !!!
; limited to a meaningful level
c_mb=mean(mb)-min([2,mean(flux_calv)])   
if calibrate_glacierspecific eq 'y' then begin
   ccj=where(calimb_gid eq id(gg(g)),ci)
   if ci eq 0 then ccj=n_elements(target_spec)-1    ; when no data present, just use last value (regional mean) 
   if ci gt 1 then target=mean(target_spec(ccj)) $    ; averaging in case several entries are available for the same RGI-ID (Caucasus) 
     else target=target_spec(ccj(0))
   n=indgen(years)+tran(0)
   pp=where(n gt calimb_p0(ccj(0)) and n le calimb_p1(ccj(0)))
   c_mb=mean(mb(pp))-min([2,mean(flux_calv(pp))])   
endif

if abs(target-c_mb) gt cal_crit then begin

if cal1 eq 0 then c_mbst=0

; -------- calibration_phase '1'+'2'
if calibration_phase ne '3' then begin

if calibration_phase eq '1' then calvar=c_prec else calvar=ddfsnow
; set calibration variable for meltmodel 3
if calibration_phase eq '2' and meltmodel eq '3' then calvar=c1

if calibration_phase eq '2' and cal1 eq 0 then fc=1./fc
if c_mb gt target then calvar=calvar*(1./fc)
if c_mb lt target then calvar=calvar*fc
if cal1 gt 0 and c_mb gt target and c_mbst lt target then begin
   calvar0=calvar*fc & di=c_mbst-c_mb & fra=(target-c_mb)/di
   df=calvar0-calvar & plf=df*fra & calvar=calvar0-plf
endif
c_mbst=c_mb

if calibration_phase eq '1' then begin
   c_prec=calvar
endif else begin
   ddfsnow=calvar & ddfice=ddfsnow*rddf_si
   if meltmodel eq '3' then c1=calvar
endelse

; -------- calibration_phase '3'
endif else begin

if c_mb gt target then t_offset=t_offset+1.
if c_mb lt target then t_offset=t_offset-1.
if cal1 gt 0 and c_mb gt target and c_mbst lt target then begin
   t_offset0=t_offset-1. & di=c_mbst-c_mb & fra=(target-c_mb)/di
   df=t_offset0-t_offset & plf=df*fra & t_offset=t_offset0-plf
endif
c_mbst=c_mb



endelse   ; calibration_phase '3'

endif else cal1=cal1max+2

endif

; setting back flags if glacier - IF NECESSARY
flag=0
if cal1 ge cal1max and calibrate eq 'y' then begin
   
if cal1 eq cal1max+2 then flag=1
if calibration_phase eq '1' then begin
   if c_prec lt c1_tolerance(0) then c_prec=c1_tolerance(0)
   if c_prec gt c1_tolerance(1) then c_prec=c1_tolerance(1)
endif else begin
   if meltmodel eq 1 then begin
      if ddfsnow lt c2_tolerance(0) then flag=0
      if ddfsnow lt c2_tolerance(0) then ddfsnow=c2_tolerance(0)
      if ddfsnow gt c2_tolerance(1) then flag=0
      if ddfsnow gt c2_tolerance(1) then ddfsnow=c2_tolerance(1)
      ddfice=ddfsnow*rddf_si
   endif
   if meltmodel eq 3 then begin
      if c1 lt c2_tolerance(0) then flag=0
      if c1 lt c2_tolerance(0) then c1=c2_tolerance(0)
      if c1 gt c2_tolerance(1) then flag=0
      if c1 gt c2_tolerance(1) then c1=c2_tolerance(1)
   endif
endelse

endif

; ------------------------
; write hypsometry-evolution file
if write_hypsometry_files eq 'y' then begin
   for i=0,nb-1 do printf,9,bed_elev(i)+thick_ini(i),hypso_file(1,*,i),fo='('+string(1+chypso,fo='(i2)')+'f12.5)'
   close,9
   for i=0,nb-1 do printf,34,bed_elev(i)+thick_ini(i),hypso_file(2,*,i),fo='('+string(1+chypso,fo='(i2)')+'f13.5)'
   close,34
   for i=0,nb-1 do printf,35,bed_elev(i)+thick_ini(i),hypso_file(3,*,i),fo='('+string(1+chypso,fo='(i2)')+'f12.5)'
   close,35
endif

endif                           ; bedrock-file available?

endfor                          ; CALIBRATION 1 - single glacier mass balance

; ---------------------
; write calibration file
if calibrate eq 'y' then begin

   ;if mean(flux_calv) gt 0 then print, '   CALI - Calving flux (m/a):'+string(mean(flux_calv),fo='(f8.2)')+'('+string(ar_gl,fo='(i6)')+')'
   if calibrate_individual eq 'n' then flag=1
   if meltmodel eq '1' then if flag eq 1 then printf,3,id(gg(g)),mean(mb),mean(wb),area1,mean(ela),mean(aar),$
     mean(dbdz)*100.,mean(btongue),DDFsnow,DDFice,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,2f7.3,f9.3,f7.2,i3)' $
    else printf,3,id(gg(g)),-99,-99,area1,mean(ela),mean(aar),$
     mean(dbdz)*100.,mean(btongue),DDFsnow,DDFice,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,2f7.3,f9.3,f7.2,i3)'
   if meltmodel eq '2' then printf,3,id(gg(g)),mean(mb),mean(wb),area1,mean(ela),mean(aar),  $
     mean(dbdz)*100.,mean(btongue),Fm,r_ice,r_snow,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,4f8.4,f7.2,i3)'
   if meltmodel eq '3' then printf,3,id(gg(g)),mean(mb),mean(wb),area1,mean(ela),mean(aar), $
   	 mean(dbdz)*100.,mean(btongue),C0,C1,alb_ice,alb_snow,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,2f8.2,3f8.4,f7.2,i3)'

   if calibrate_glacierspecific eq 'y' then begin
      printf,50,id(gg(g)),calimb_p0(ccj(0)),calimb_p1(ccj(0)),$
             target_spec(ccj(0)),mean(mb(pp)),mean(wb(pp)),area1,mean(ela(pp)),mean(aar(pp)),DDFsnow,DDFice,c_prec,$
             t_offset,flag,fo='(a,2i7,3f9.3,f11.3,i6,f6.1,2f7.3,f9.3,f7.2,i3)'
   endif else begin
      if flag eq 1 then printf,50,id(gg(g)),cran(0),cran(1),target,mean(mb),mean(wb),area1,mean(ela),mean(aar),DDFsnow,DDFice,c_prec,$
                               t_offset,flag,fo='(a,2i7,3f9.3,f11.3,i6,f6.1,2f7.3,f9.3,f7.2,i3)' $
      else printf,50,id(gg(g)),cran(0),cran(1),target,-99,-99,area1,mean(ela),mean(aar),DDFsnow,DDFice,c_prec,$
                  t_offset,flag,fo='(a,2i7,3f9.3,f11.3,i6,f6.1,2f7.3,f9.3,f7.2,i3)'
   endelse
   
   printf,4,id(gg(g)),t_offset,flag,gx,gy,fo='(a,f9.3,3i4)'
   
endif

cali_calflux=cali_calflux+mean(flux_calv)/1000.*ar_gl

; ---------------------
; write results files
if write_file eq 'y' then begin
ii=where(outf_names ne '',ci)
for i=0,ci-1 do begin
	case ii(i) of
	  0: var=areas
	  1: var=volumes
	  2: var=mb
	  3: var=wb
	  4: var=smelt
	  5: var=imelt
	  6: var=accum
	  7: var=rain
	  8: var=ela
	  9: var=aar
	 10: var=refre
         11: var=hmin_g
         12: var=flux_calv
	 13: var=discharge
	 14: var=discharge_gl
	 15: var=balmo
	 16: var=precmo
	 17: var=accmo
	 18: var=melmo
	 19: var=refrmo
	 endcase
        if ii(i) ge 13 then a=12 else a=1
	printf,string(i+10,fo='(i2)'),id(gg(g))+' '+string(var,fo='('+strcompress(string(years)*a,/remove_all)+format_of(i)+')')
endfor

endif

; ------------------------
; write elevation band file
fn=dir_data+'/'+region+'/'+id(gg(g))+'.dat' & a=findfile(fn)
if write_mb_elevationbands eq 'y' and a(0) ne '' then begin
   ii=where(thick_ini eq 0,ci) & if ci gt 0 then elev_bmb(*,ii)=snoval & if ci gt 0 then elev_bwb(*,ii)=snoval & if ci gt 0 then elev_refr(*,ii)=snoval
   for i=0,n_elements(elev_bmb(0,*))-1 do printf,8,elev0(i),elev_bmb(*,i),elev_bwb(*,i),fo='(i6,'+strcompress(string(2*years,fo='(i3)'),/remove_all)+'f7.2)'
   close,8 
   for i=0,n_elements(elev_bmb(0,*))-1 do printf,40,elev0(i),elev_refr(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f7.1)' &  close,40 
   if debris_supraglacial eq 'y' then begin
      for i=0,n_elements(elev_bmb(0,*))-1 do printf,41,elev0(i),elev_debthick(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,41 
      for i=0,n_elements(elev_bmb(0,*))-1 do printf,42,elev0(i),elev_debfrac(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,42 
      for i=0,n_elements(elev_bmb(0,*))-1 do printf,43,elev0(i),elev_debfactor(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f10.5)' &  close,43 
     ; for i=0,n_elements(elev_bmb(0,*))-1 do printf,44,elev0(i),elev_pondarea(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f11.6)' &  close,44       
      if eval_mbelevsensitivity eq 'y' then begin
         for i=0,n_elements(elev_bmb(0,*))-1 do printf,44,elev0(i),elev_mbsens(*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f9.4)'
         close,44      
      endif
   endif
endif

; ------------------------
; write firn-ice temperature
if firnice_temperature eq 'y' then begin

   if firnice_write(0) eq 'y' then begin
      for i=0,n_elements(elev_firnicetemp(0,0,*))-1 do printf,45,elev0(i),elev_firnicetemp(0,*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,45 
      for i=0,n_elements(elev_firnicetemp(0,0,*))-1 do printf,46,elev0(i),elev_firnicetemp(1,*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,46 
      for i=0,n_elements(elev_firnicetemp(0,0,*))-1 do printf,47,elev0(i),elev_firnicetemp(2,*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,47 
      for i=0,n_elements(elev_firnicetemp(0,0,*))-1 do printf,48,elev0(i),elev_firnicetemp(3,*,i),fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,48 
   endif

   if firnice_write(1) eq 'y' then begin
      for i=0,n_elements(firnice_profile)-1 do close,51+i
   endif

endif

; *******************************************************
; plot of mass balance and profile for individual glacier!!!

if nb gt elev_range_p/step and plot eq 'y' then begin

xscm=20 & yscm=28.
PSCAL,'ps',xscm,yscm,name=dirres+dir_region+'/plots/'+id(gg(g))
loadct,0 & tek_color

device,/bold

; profile
pos=cm2norm(2,17.95,12.5,10,xscm,yscm)
plot,[0],[0],xra=[0,max(length)+max(length)*0.05],yra=[min(bed_elev)-10,max(elev)+10],/xsty,/ysty,xtit='Length (km)         ',ytit='Elevation (m a.s.l.)',pos=pos

oplot,length,gls(0,*),thi=3,col=4
for i=1,cnp-2 do oplot,length,gls(i,*),col=12
oplot,length,bed_elev,thi=4

if advance eq 'y' then area_ini=area_iniconst
ab=dblarr(2,fix(nb/10)) & n=0
for i=0,nb-11,10 do begin
   ab(0,n)=total(area_ini(i:i+9)) & ab(1,n)=total(area(i:i+9))
   n=n+1
endfor
m=max(length)+max(length)*0.05 & sc=(m/4.)/max(ab(0,*)) & n=0 & e=indgen(nb)*10+e0
for i=0,fix(nb/10)-1 do begin
   polyfill,[m-ab(0,i)*sc,m,m,m-ab(0,i)*sc],[e(n),e(n),e(n+9),e(n+9)],col=15
   polyfill,[m-ab(1,i)*sc,m,m,m-ab(1,i)*sc],[e(n),e(n),e(n+9),e(n+9)],/line_fill,orient=45
   n=n+10
endfor

; statistics
xo=0.35 & yo=0.95 & ys=0.042 & ss=0.9
i=0 & xyouts,x_s(xo),y_s(yo-i*ys),'Area (t=0) (km2): '+string(total(area_ini),fo='(f13.2)')
i=1 & xyouts,x_s(xo),y_s(yo-i*ys),'Area change (%): '+string((area1-total(area_ini))*100/total(area_ini),fo='(i10)')
i=2 & xyouts,x_s(xo),y_s(yo-i*ys),'Volume (t=0) (km2): '+string(volume0,fo='(f8.2)')
i=3 & xyouts,x_s(xo),y_s(yo-i*ys),'Volume change (%): '+string((volume1-volume0)*100/volume0,fo='(i6)')
i=4 & xyouts,x_s(xo),y_s(yo-i*ys),'Terminus (t=0) (masl): '+string(e0,fo='(i4)')
i=5 & xyouts,x_s(xo),y_s(yo-i*ys),'Terminus change (m): '+string(ht1-e0,fo='(i4)')

; -----------------------------
; time series

; Mass balance
pos=cm2norm(2,8.6,12.5,8.2,xscm,yscm)
hh=where(mb gt -90,ch)

if ch gt 0 then begin
plot,[0],[0],xra=[tran(0)-1,tran(1)+1],yra=[min([wb(0:ch-1),mb(0:ch-1),-smelt(0:ch-1),-flux_calv(0:ch-1)])-0.1,max([wb,mb,-smelt])+0.1],/xsty,/ysty,ytit='Mass balance (m w.e.)',pos=pos,/noerase

t=indgen(years)+tran(0)
ii=where(mb ne snoval)
oplot,!x.crange,[0,0],lines=2
oplot,t(ii),mb(ii),thi=6,col=2
oplot,t(ii),wb(ii),thi=6,col=4
oplot,t(ii),-smelt(ii),thi=2,col=11,lines=2
oplot,t(ii),-imelt(ii),thi=2,col=12,lines=3
if max(flux_calv) gt 0 then oplot,t(ii),-flux_calv(ii),thi=6,col=0

; legende
xl=1. & xst=0.35 & yl=0.68 & if max(flux_calv) gt 0 then yst=0.32 else yst=0.26
xsym=0.025 & xsym2=0.07 & xwr=0.13 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd4=0.24 & yd5=0.3
symcor=0.013 & ss=1.15
polyfill, [x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl)], col=1
oplot,[x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst),x_s(xl)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl),y_s(yl)], col=0,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=2,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=4,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd3+symcor),y_s(yl+yst-yd3+symcor)] , col=11,thi=2,lines=2,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd4+symcor),y_s(yl+yst-yd4+symcor)] , col=12,thi=2,lines=3,/noclip
if max(flux_calv) gt 0 then oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd5+symcor),y_s(yl+yst-yd5+symcor)] , col=0,thi=6,/noclip
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Surf. bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Winter bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd3), 'Snow melt', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd4), 'Ice melt', size=ss
if max(flux_calv) gt 0 then xyouts,x_s(xl+xwr),y_s(yl+yst-yd5), 'Frontal Abl.', size=ss

endif

; -----------------------------------
; Area - Volume Plot
anorm=areas/areas(0) & vnorm=volumes/volumes(0)

pos=cm2norm(1.2,0.7,8.3,7.2,xscm,yscm)
plot,[0],[0],xra=[tran(0)-1,tran(1)+1],yra=[-0.02,max([vnorm,anorm])+0.02],/xsty,/ysty,ytit='Norm. Area / Volume (-)',pos=pos,/noerase

oplot,t,anorm,thi=6,col=2
oplot,t,vnorm,thi=6,col=4

; legende
xl=0.03 & xst=0.42 & yl=0.03 & yst=0.14
xsym=0.0 & xsym2=0.06 & xwr=0.09 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd3=0.24
symcor=0.013 & ss=1.15
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=2,thi=6
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=4,thi=6
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Area ('+string(total(area_ini),fo='(f8.2)')+')', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Volume ('+string(volume0,fo='(f8.3)')+')', size=ss

; -----------------------------------
; Elevation distribution

; aggregate values
fp=3.
pst=fix(years/(fp*outst))
if pst ne 0 then begin

bnp=dblarr(nb,pst)+snoval & acp=bnp & mep=acp & rfp=bnp & elp=bnp & elap=dblarr(2,pst)
for j=0,pst-1 do begin
   for h=0,nb-1 do begin
      elp(h,j)=mean(gls(j*fp:((j+1)*fp-1.),h))
      a=mely((fp*outst*j):(fp*outst*(j+1)-1),h) & ii=where(a ne noval,ci)
      if ci gt fp*outst/2. then begin
         bnp(h,j)=mean(baly(ii+(fp*outst*j),h))
         acp(h,j)=mean(accy(ii+(fp*outst*j),h))
         mep(h,j)=mean(mely(ii+(fp*outst*j),h))
         rfp(h,j)=mean(refry(ii+(fp*outst*j),h))*10.
      endif
   endfor
   elap(0,j)=mean(ela((fp*outst*j):(fp*outst*(j+1)-1)))
   elap(1,j)=mean(aar((fp*outst*j):(fp*outst*(j+1)-1)))
endfor

pos=cm2norm(11.45,0.7,8.5,7.2,xscm,yscm)
plot,[0],[0],xra=[min(-mep(where(mep ne snoval)))-0.1,max(acp)+0.1],yra=[min(elp)-10,max(elp)+10.],/xsty,/ysty,ytit='Elevation (m a.s.l.)',xtit='Mass balance (m w.e. a!E-1!N)',pos=pos,/noerase

oplot,[0,0],!y.crange,lines=2

lin=[0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0]
for j=0,pst-1 do begin
   ii=where(bnp(*,j) ne snoval,ci)
   if ci gt 0 then begin
      oplot,bnp(ii,j),elp(ii,j),thi=4,col=0,lin=lin(j)
      oplot,-mep(ii,j),elp(ii,j),thi=4,col=2,lin=lin(j)
      oplot,acp(ii,j),elp(ii,j),thi=4,col=4,lin=lin(j)
      oplot,rfp(ii,j),elp(ii,j),thi=4,col=12,lin=lin(j)
   endif
   oplot,[x_s(0),x_s(0.2)],[elap(0,j),elap(0,j)],thi=4,lin=lin(j)
   xyouts,x_s(0.21),elap(0,j),'AAR '+string(elap(1,j),fo='(i2)')+'%',size=0.65
endfor

; legende
xl=.55 & xst=0.45 & yl=1. & yst=0.26
xsym=0.025 & xsym2=0.07 & xwr=0.125 & yd1=0.06 & yd2=0.12 & yd3=0.18 & yd4=0.24
symcor=0.013 & ss=1
polyfill, [x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl)], col=1
oplot,[x_s(xl),x_s(xl),x_s(xl+xst),x_s(xl+xst),x_s(xl)],[y_s(yl),y_s(yl+yst),y_s(yl+yst),y_s(yl),y_s(yl)], col=0,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd1+symcor),y_s(yl+yst-yd1+symcor)] , col=0,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd2+symcor),y_s(yl+yst-yd2+symcor)] , col=2,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd3+symcor),y_s(yl+yst-yd3+symcor)] , col=4,thi=6,/noclip
oplot,[x_s(xl+xsym),x_s(xl+xsym+xsym2)],[y_s(yl+yst-yd4+symcor),y_s(yl+yst-yd4+symcor)] , col=12,thi=6,/noclip
xyouts,x_s(xl+xwr),y_s(yl+yst-yd1), 'Surface bal.', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd2), 'Melt', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd3), 'Accumulation', size=ss
xyouts,x_s(xl+xwr),y_s(yl+yst-yd4), 'Refreeze (x10)', size=ss

device,/close_file

endif  ; period long enough

endif    ; plot

; -----------------------
; write main file and meteo file
if volume0 gt 0 then vv=(volume1-volume0)*100/volume0 else vv=-100
if write_file eq 'y' then begin
   printf,6,id(gg(g)),latitudes(g),longitudes(g),total(area_iniconst),volume0,(area1-total(area_iniconst))*100/total(area_iniconst),vv,fo='(a,2f13.6,f10.3,f10.4,2f10.1)'

; evaluating meteorological changes
   ii=where(cyear ge 1980 and cyear le 1999,ci) & jj=where(cyear ge meteo_period(0) and cyear le meteo_period(1),cj)
   if ci gt 0 and cj gt 0 then a=mean(temp(jj))-mean(temp(ii))
   if ci gt 0 and cj gt 0 then d=(mean(prec(jj))-mean(prec(ii)))*100./mean(prec(jj))
   if bal_month eq 10 then begin
      ii=where(cyear ge 1980 and cyear le 1999 and cmon ge bal_month-4 and cmon le bal_month-2,ci)
      jj=where(cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon ge bal_month-4 and cmon le bal_month-2,cj)
      if ci gt 0 and cj gt 0 then b=mean(temp(jj))-mean(temp(ii))
      ii=where(cyear ge 1980 and cyear le 1999 and cmon ge bal_month-5 and cmon le bal_month,ci)
      jj=where(cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon ge bal_month-5 and cmon le bal_month,cj)
      if ci gt 0 and cj gt 0 then c=mean(temp(jj))-mean(temp(ii))
   endif else begin
      ii=where((cyear ge 1980 and cyear le 1999 and cmon le bal_month-2) or (cyear ge 1980 and cyear le 1999 and cmon eq 12),ci)
      jj=where((cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon le bal_month-2) or (cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon eq 12),cj)
      if ci gt 0 and cj gt 0 then b=mean(temp(jj))-mean(temp(ii))
      ii=where((cyear ge 1980 and cyear le 1999 and cmon le bal_month) or (cyear ge 1980 and cyear le 1999 and cmon ge 11),ci)
      jj=where((cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon le bal_month) or (cyear ge meteo_period(0) and cyear le meteo_period(1) and cmon ge 11),cj)
      if ci gt 0 and cj gt 0 then c=mean(temp(jj))-mean(temp(ii))
   endelse
   printf,61,id(gg(g)),latitudes(g),longitudes(g),total(area_iniconst),a,b,c,d,fo='(a,2f13.6,f10.3,3f10.2,f10.1)'
endif

count_glaciers=count_glaciers+1


endfor   ; loop over glaciers


; put into grid
;if grid_run eq 'y' then begin
;   for i=0,nout-1 do begin
;      ds_grid(i,gx,gy)=stor_dv(i) &  im_grid(i,gx,gy)=stor_im(i)
;      ar_grid(i,gx,gy)=stor_ar(i) &  vo_grid(i,gx,gy)=stor_vo(i)
;   endfor
;endif


endfor    ; grids y

endfor                          ; grids x


; ----------------------------------------
; ****************************************
; Optimization - OVERALL MASS BALANCE

if calibrate eq 'y' and calibrate_individual ne 'y' then begin

   close,3 & close,4
   if rhodv_iteration ne '' then b='_rhodv' else b=''

   fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
anz=file_lines(fn)-1 & s=strarr(1) & dat=dblarr(13,anz)
openr,1,fn & readf,1,s & readf,1,dat & close,1

; determine potential variability range of c_prec
if cal0 eq 0 then begin
   fc=2.-max([0,mean(dat(2,*))/4.]) & if fc lt 1.3 then fc=1.3
   cal_crit=0.01+0.02/(fc-1.)
endif

c_mb=total(dat(1,*)*dat(3,*))/total(dat(3,*))
if abs(target-c_mb) gt cal_crit then begin

if cal0 eq 0 then c_mbst=0
if c_mb gt target then c_prec=c_prec*(1./fc)
if c_mb lt target then c_prec=c_prec*fc
if cal0 gt 0 and c_mb gt target and c_mbst lt target then begin
   c_prec0=c_prec*fc & di=c_mbst-c_mb & fra=(target-c_mb)/di
   df=c_prec0-c_prec & plf=df*fra & c_prec=c_prec0-plf
endif
c_mbst=c_mb

endif else cal0=cal0max

endif

if calibrate_individual eq 'y' then begin
   close,3 & close,4
   if calibrate_glacierspecific eq 'y' then close,50
endif

endfor                          ; CALIBRATION 0 - overall mass balance


; close result files
if write_file eq 'y' then begin

close,5 & close,6 & close,61
for fid=10,10+n_elements(where(outf_names ne ''))-1 do close,string(fid,fo='(i2)')

endif

; calculate statistics for calibration phases
if rhodv_iteration ne '' then b='_rhodv' else b=''
fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+'_final_'+reanalysis+b+'.dat'
a=findfile(fn)
if a(0) eq '' then fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0 &  da=dblarr(13+a,anz) & tt=strarr(1) & openr,1,fn & readf,1,tt & readf,1,da & close,1
flag_eval=da(12+a,*)
for i=0l,anz-1 do begin
   if calibration_phase eq '1' then begin
      if da(10+a,i) le c1_tolerance(0)+0.005 then flag_eval(i)=2
      if da(10+a,i) ge c1_tolerance(1)-0.005 then flag_eval(i)=3
   endif  else begin
      if meltmodel eq 1 then if da(8+a,i) eq c2_tolerance(0)+0.005 or da(8+a,i) eq c2_tolerance(1)-0.005 then flag_eval(i)=0 
      if meltmodel eq 3 then if da(7+a,i) eq c2_tolerance(0)+0.005 or da(7+a,i) eq c2_tolerance(1)-0.005 then flag_eval(i)=0
   endelse
endfor
ii=where(flag_eval eq 1,ci)

if cphl eq 1 then begin
   caliphase_statistics(cphl-1)=ci*100/anz
   ii=where(flag_eval eq 2,ci) & ii=where(flag_eval eq 3,cj)
   if (ci+cj) gt 0 then caliphase_statistics(3)=ci*100/(ci+cj) else caliphase_statistics(3)=0
endif
if cphl eq 2 then caliphase_statistics(cphl-1)=ci*100/anz-caliphase_statistics(cphl-2)
if cphl eq 3 then caliphase_statistics(cphl-1)=ci*100/anz-caliphase_statistics(cphl-2)-caliphase_statistics(cphl-3)

endfor                          ; calibration phases

print, 'FINISHED region !!! '+region+' !!! '+clim_subregion
if reanalysis_direct ne 'y' then print, '    calculated with GCM: '+GCM_model(gcms)+' / '+GCM_rcp(rcps)+' / '+GCM_experiment(experis)
print, '    calculated with Re-analysis data set '+reanalysis

print, '**********'

if calibrate ne 'y' then begin
; output of total calving flux for calibration purposes
   print, '--------- TOTAL CALVING FLUX (Gt/a) (period average):'
   print, string(cali_calflux,fo='(f9.4)')
endif


if calibrate eq 'y' then begin
   if rhodv_iteration ne '' then b='_rhodv' else b=''
   spawn,'cp '+dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+$
 '_'+sub_region+b+'.dat '+dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+'_final_'+reanalysis+b+'.dat'
   print, '   ...  Overwritten calibration file ...   '+sub_region

   fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
   anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0 &  da=dblarr(13+a,anz) & tt=strarr(1)
   openr,1,fn & readf,1,tt & readf,1,da & close,1
   ii=where(da(12+a,*) eq 0,ci) & print, '     Not calibrated: '+string(ci*100/anz,fo='(f5.2)')+'%'

   ; evaluate statistics for calibration phases
   print, '*** Calibration phase statistics:' & a=caliphase_statistics(0)
   c=caliphase_statistics(2) & d=caliphase_statistics(3)
   print, '1: '+string(a,fo='(i3)')+'% ('+string(d,fo='(i3)')+'% at lower);   2:'+string(caliphase_statistics(1),fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%'
   openw,2,dircali+dir_region+'/calibration/caliphase_statistics_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+b+'.dat'
   printf,2, '1: '+string(a,fo='(i3)')+'%;   2:'+string(caliphase_statistics(1),fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%' & close,2

   if repeat_calibration eq 'y' then begin
      rp_cali=rp_cali+1
      if toff_grid0 eq 'y' and rp_cali eq 1 then goto, repeat_cali 
      if toff_grid0 eq 'y' and rp_cali gt 1 and rp_cali le 4 and ci*100/anz gt 0.2 then goto, repeat_cali 
   endif
endif


; --------------------------------
; write file for volume below sea level
if calibrate ne 'y' and write_file eq 'y' then begin
   for i=0,years-1 do printf,7,tran(0)+i,vol_bz(i),fo='(i4,f12.2)'
   close,7
   close,33
endif

endfor                          ; regions

; --------------------------------

endfor                                  ; firnice_batch_loop


next_GCM:

endfor                          ; experiments

; zipping and removing files
if write_hypsometry_files eq 'y' then begin
   if meltmodel eq '1' then mtt='' else mtt='_m3'
   b='/files'+mtt+'/'+GCM_model(gcms)+'/'+GCM_rcp(rcps)
   if reanalysis_direct eq 'y' then b='/PAST'
   ; zipping automatically,  but not for RGI-regions with subregions
   if region ne 'lowlatitudes' and region ne 'antarctic' and region ne 'northasia' then begin
      spawn, 'zip -r '+dirres+dir_region+b+'/hypsometry.zip  '+dirres+dir_region+b+'/hypsometry'
      spawn, 'rm -r '+dirres+dir_region+b+'/hypsometry'
   endif
endif

endfor                          ; RCPs

endfor                          ; GCMs

if plot eq 'y' or areaplot eq 'y' then device,/close_file


end
