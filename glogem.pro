; *****************************************
; *****************************************
; ****************************************************
; ****************************************************
; ****************************************************

; MAIN GloGEM-Code (modular)

; ****************************************************
; ****************************************************
; ****************************************************

compile_opt idl2

; defining where procedures are found
CD, CURRENT=base_dir ; define base directory
a = !path            ; save current path
!PATH = a + ':' + base_dir + '/procedures/read/:' + base_dir + '/procedures/write/:' + base_dir + '/procedures/processing/:' + base_dir + '/procedures/flow/:'; add path to procedures

; ******************************************************************
; saving/reading input file settings at the start of the main run
fn='input.pro' & anz=file_lines(fn) & input_file_content=strarr(anz)
openr,1,fn & readf,1,input_file_content & close,1

;*******************************************************************
; Some information to show which model we are running
if time_resolution eq 'daily' then begin
  print, '                    We are running GloGEM daily'
endif else begin
  print, '                    We are running GloGEM monthly'
endelse
if calibrate eq 'y' then begin
  print, '                    Calibration started ...'
endif else begin
  print, '                    Running for the future ...'
endelse
print, catchment_selection
print, reanalysis
;********************************************************************
; --------------------------------------------
; READ batch-file for individual glaciers (icetemperature-batch)

if firnice_temperature eq 'y' then begin
   READ_GEOTHERMAL,dir,firnice_geotherm_flux,fit_xx,fit_yy
   if firnice_batch eq 'y' then READ_FIRNICEBATCH,dir,firnice_batch_data1,firnice_batch_data2,nffbl
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

; automatically setting end of modelling period for future runs
if reanalysis_direct ne 'y' then tran[1]=2100
if long_GCM ne '' then tran[1]=2300

; -------------------
; LOOP OVER DIFFERENT RCPs/SSPs

if rcp_batch[0] ne 0 then ne_GCM_rcp=rcp_batch[gcms] else ne_GCM_rcp=n_elements(GCM_rcp)

for rcps=0,ne_GCM_rcp-1 do begin

; -------------------
; LOOP OVER DIFFERENT Experiments

if expe_batch[0] ne 0 then ne_GCM_experiment=expe_batch[gcms] else ne_GCM_experiment=n_elements(GCM_experiment)

for experis=0,ne_GCM_experiment-1 do begin

experi_short=strmid(GCM_experiment[experis],0,2)

READ_REGIONBATCH,dir,region_loop_data

; ********************************************************
; LOOP individual glaciers in different regions specified in batch
; file (icetemperature_batch.dat)

if firnice_batch eq 'y' then firnice_batch_loop=nffbl else firnice_batch_loop=1

for ffbl=0,firnice_batch_loop-1 do begin

if firnice_batch eq 'y' then begin
; make sure that other settings are fine
   ; DEACTIVE write_file='n' in potential FULL runs
   write_file='n' & calibrate='n'  
   single_glacier=firnice_batch_data2[0,ffbl] ; define indivudal glacier to be run
   firnice_profile_ID=firnice_batch_data2[1,ffbl]   ; define temperature profile ID
   ii=where(firnice_batch_data1[1,ffbl] eq region_loop_data[1,*],ci)         ; RGI region
   region_id_loop=[double(region_loop_data[0,ii[0]]),double(region_loop_data[0,ii[ci-1]])]   ; define RGI region
   firnice_profile=[firnice_batch_data1[0,ffbl]]                                             ; define elevation
   firnice_maxdepth=[firnice_batch_data1[2,ffbl]]
endif
   
; ********************************************************
; LOOP over different regions

for re=0,region_id_loop[1]-region_id_loop[0] do begin

   rp_cali=0
   repeat_cali:
   DDFsnow=DDFsnow0 & DDFice=DDFice0

if region_id_loop[0] eq 0 then begin
   region=region_n[re]
   if sub_region eq '' then sub_region=region
   if clim_subregion ne '' then sub_region=clim_subregion
   if sub_region eq '' then sub_region=region_n[0]
endif else begin
; region names for ID_loop
   if calibrate eq 'y' then begin
      read_parameters='n' & calibration_phase='1'
   endif
   region=region_loop_data[4,re+region_id_loop[0]-1]
   dir_region=region_loop_data[2,re+region_id_loop[0]-1]
   rgiregion=region_loop_data[1,re+region_id_loop[0]-1]
   clim_subregion=region_loop_data[3,re+region_id_loop[0]-1]
   if clim_subregion eq 'xxx' then clim_subregion='' 
   if clim_subregion ne '' then sub_region=clim_subregion else sub_region=''
   if sub_region eq '' then sub_region=region
endelse

count_glaciers=1
cali_calflux=0

; Define start of mass balance year
if time_resolution eq 'daily' then dd_thresholds=[121,181,274,365] else dd_thresholds=[4,7,10,12]
bal_month=dd_thresholds[2]          
if dir_region eq 'SouthernAndes' or dir_region eq 'Antarctic' or dir_region eq 'LowLatitudes' or dir_region eq 'NewZealand' then bal_month=dd_thresholds[0]

; removing preexisting t_offset file for initial calibration
if calibrate eq 'y' then begin
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
   if rp_cali eq 0 then spawn, 'rm '+dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
endif


; READING MONTHLY CLIMATE DATA (gridded format)
if time_resolution eq 'monthly' then begin

   if clim_subregion ne '' then ccl='_'+clim_subregion else ccl=''
   
  ; GCM --- CLIMATE FILE
   if reanalysis_direct ne 'y' then begin
      READ_GCMDATA_MONTHLY,dir_clim,GCM_data,dir_region,long_GCM,ccl,GCM_model,GCM_rcp,GCM_experiment,  gcms,rcps,experis,rmid,  gcm_temp,gcm_prec,gcm_year,gcm_mon,gcm_lon,gcm_lat, time_resolution
   endif

   READ_CLIMATEPAST_MONTHLY, dir_clim, dir_region, clim_subregion, reanalysis, submonth_variability, rtemp, rprec, rvariab, rtg, rlon, rlat, relev, nlons, nlats, lon0, lat0, ntime, ryear, rmon, rvlat, rvmon, rvday, rvlon, nmonths, ndays, nvar, time_resolution

endif


; attribute updated space ranges to be calculated
lat0=[9999,9999]        ; run for entire region
lon0=[0,0]        ; or specify sub-regions
if clim_subregion ne '' then begin
   lat0=[min(rvlat)-0.1,max(rvlat)]
   if clim_subregion eq 'Atlantic' then lat0[0]=-60.5
   lon0=[min(rvlon)-0.1,max(rvlon)]
endif

; -----------------------------
; read regional parameter file

if regparams_readfromfile eq 'y' then READ_regionalparams, dir,reanalysis,dir_region,clim_subregion,size_range_overwrite, c_calving,c_prec,c1_tolerance,t_offset,toff_grid,toff_grid0,p_thres,size_range,time_resolution

if catchment_selection ne '' then size_range=[0,100000.]

; -----------------------------
; read calibration data file (REGIONAL MEAN MASS BALANCE)
if calibrate eq 'y' then begin

if calibrate_glacierspecific eq 'n' then begin
   
fn=dir+'calibration.dat' & anz=file_lines(fn)-1 
openr,1,fn & readf,1,s & readf,1,tt & close,1
calimb_regname=strarr(anz) & calimb_sregname=strarr(anz) & calimb_outline=strarr(anz)
calimb_idname=dblarr(anz) &  calimb_p0=dblarr(anz) &  calimb_p1=dblarr(anz) & calimb_bn=dblarr(anz) & calimb_uc=dblarr(anz)
for i=0l,anz-1 do begin
   a=strsplit(tt[i],' ',/extract) & calimb_regname[i]=a[0] & calimb_sregname[i]=a[1] & calimb_outline[i]=a[2]
   calimb_idname[i]=double(a[4]) & calimb_p0[i]=double(a[5]) & calimb_p1[i]=double(a[6]) & calimb_bn[i]=double(a[7]) & calimb_uc[i]=double(a[8])
endfor

; *** Glacier-specific calibration file
endif else begin

   READ_GEODETICDATA,dir,dir_region,region_loop_data,calibrate_glacierspecific_period,calimb_bn,calimb_p0,calimb_p1,calimb_gid

endelse

endif


; *************************************************************

; ------------
; Loop over three calibration phases
caliphase_statistics=dblarr(4)   ; info on top and low values for c_prec

for cphl=1,double(caliphase_loop) do begin

if cphl gt 1 then calibration_phase=string(cphl,fo='(i1)')
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
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''

fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+a+cc+'.dat'
a=findfile(fn) & if a[0] eq '' then print,'!!! Parameter-File for '+sub_region+' is not available !!!'
cnc=12+double(meltmodel)
anz=file_lines(fn)-1 & da=dblarr(cnc,anz) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,da & close,1


; replace flagged values
ii=where(da[cnc-1,*] eq 1,ci) & jj=where(da[cnc-1,*] eq 0,cj)
if ci gt 0 and cj gt 0 and calibration_phase eq '1' then for i=8,9+double(meltmodel) do for j=0,cj-1 do da[i,jj[j]]=mean(da[i,ii])

; attribute variables obtained from file
cali_id=da[0,*]
if meltmodel eq '1' then begin
   cali_ddfice=da[9,*] & cali_ddfsnow=da[8,*] & cali_cprec=da[10,*] & cali_toff=da[11,*]
endif
if meltmodel eq '3' then begin
   cali_c0=da[8,*] & cali_c1=da[9,*] & cali_a_ice=da[10,*] & cali_a_snow=da[11,*]
   cali_cprec=da[12,*] & cali_toff=da[13,*]
endif

endif

; including gridded T-offsets in calibration
if toff_grid eq 'y' and calibration_phase eq '1' and calibrate eq 'y' then begin
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
   fn=dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
   a=findfile(fn)
   if a[0] ne '' then begin
      anz=file_lines(fn) & da=dblarr(5,anz)  & openr,1,fn & readf,1,da & close,1
      toff_data=dblarr(anz) & cali_id_toff=da[0,*]
      for i=1,max(da[3,*]) do begin
         for j=1,max(da[4,*]) do begin
            ii = where((da[3,*] eq i) AND (da[4,*] eq j), ci)
            if ci gt 0 then toff_data[ii] = mean(da[1,ii])
         endfor
      endfor
   endif else toff_grid='n'
endif

; make sure parameters are double-precision
DDFsnow=double(DDFsnow) & DDFice=double(DDFice)
C0=double(C0) & C1=double(C1)
c_prec=double(c_prec)

; --------------------------------------------
; read batch file for all glaciers to be considered 
; (taken from ice thickness data set)

fn=dir_data+'../files/thick_'+region+'.dat' & anz=file_lines(fn)-1 & s=strarr(1) & st=strarr(anz)
openr,1,fn & readf,1,s & readf,1,st & close,1
tti=strarr(anz)
id=tti 
tt=dblarr(19,anz)
for i=0l,anz-1 do begin
   a = strsplit(st[i], ' ', /extract)
   tti[i] = a[0]
   for j=0,18 do tt[j,i] = double(a[j+1])
endfor
hmed = tt[8,*]
hmin = tt[6,*]
survey_year = tt[18,*]
volume_ini=tt[3,*]
xy = tt[0:1,*]
a_gl = tt[2,*]
lat_gl = xy[1,*]
lon_gl = xy[0,*]
tt = a_gl
for i=0l,anz-1 do id[i] = strsplit(tti[i], ';', /extract)

; checking whether survey-year/inventory-year is known and filling up with average if necessary
ii = where(survey_year ne noval, ci)
jj = where(survey_year eq noval, cj)
if (ci gt 0) and (cj gt 0) then survey_year[jj] = mean(survey_year[ii])

nout=fix(years/outst)+1
nouty=indgen(nout)*outst

; restrict number of evaluated glaciers to those with WGMS data
if valiglaciers_only eq 'y' then begin
   fn=dir+validation_dataset+dir_region+'.dat' & an=file_lines(fn)-1 & ss=strarr(2,an)
   for i=0l,anz-1 do begin
      a=double(id[i])-double(ss[1,*])
      if min(abs(a)) ne 0 then begin
         a_gl[i] = -1. ; setting area to negative, so that it will not be computed
      endif
   endfor
endif

; attribute dimensions of region to be calculated automatically
if lat0[0] eq 9999 then begin
   lat0=[min(lat_gl)-0.1,max(lat_gl)+0.1]
   lon0=[min(lon_gl)-0.1,max(lon_gl)+0.1]
endif

; ------------------------------
; generating folder structure
if meltmodel eq '1' then mtt='' else mtt='_m3'

; Get the current date and time
a = systime()
b = strsplit(a, ' ', /extract)
date_str = strjoin(b, '_')
tt = double(b[4]) - 1

; Construct the directory path
b = '/' + date_str + '/'
;PRINT, b

if tran[1] le tt then b='/PAST'+version_past+mtt

; Use FILE_TEST and FILE_MKDIR instead of findfile and spawn
if ~FILE_TEST(dirres+dir_region, /DIRECTORY) then begin
   FILE_MKDIR, dirres+dir_region
   FILE_MKDIR, dirres+dir_region+'/calibration'  ; calibration folder
   FILE_MKDIR, dirres+dir_region+'/files'+mtt    ; result files
   FILE_MKDIR, dirres+dir_region+'/PAST'+mtt     ; past files
endif

if ~FILE_TEST(dirres+dir_region+'/files/SINGLE', /DIRECTORY) then begin
   FILE_MKDIR, dirres+dir_region+'/files/SINGLE'
endif

if ~FILE_TEST(dirres+dir_region+'/files'+mtt+'/'+GCM_model[gcms], /DIRECTORY) then begin
   FILE_MKDIR, dirres+dir_region+'/files'+mtt+'/'+GCM_model[gcms]
endif

if ~FILE_TEST(dirres+dir_region+'/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps], /DIRECTORY) then begin
   FILE_MKDIR, dirres+dir_region+'/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
endif

; ------------------------------
; open result files
if calibrate ne 'y' and write_file eq 'y' then begin
   if reanalysis_direct eq 'y' then a='PAST'+version_past else a=GCM_model[gcms]+'/'+GCM_rcp[rcps]
   if single_glacier ne '' then a='SINGLE'

   if meltmodel eq '3' then plf='_m3' else plf='' 
   if meltmodel eq '1' and calperiod_ID eq 8 then  plf='_debris' else plf='' 
   subpath='/files'+plf+'/'+a+'/'

   if meltmodel eq '1' then mtt='' else mtt='_m3'
   if meltmodel eq '1' and calperiod_ID eq 8 then  mtt='_debris' else mtt=''  

   if past_out eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/'
   if past_out eq 'y' and hindcast_dynamic eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/dyn/'

   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
   
   openw,6,dirres+dir_region+subpath+long_GCM+sub_region+cc+'.dat'
   printf,6,'ID    lat  lon    Area0    Volume0  dA(%)  dV(%)'

   y=indgen(years)+tran[0]
   for fid=10,10+n_elements(where(outf_names ne ''))-1 do begin
      openw,string(fid,fo='(i2)'),dirres+dir_region+subpath+long_GCM+sub_region+'_'+outf_names[fid-10]+'_'+experi_short+cc+'.dat'
      if fid lt 23 then printf,string(fid,fo='(i2)'),'ID  '+string(y,fo='('+strcompress(string(years),/remove_all)+'i6)') $
        else printf,string(fid,fo='(i2)'),'ID  hydr.year  Area(km2) day 274 275 ... 1 2 3 ... 273 (unit: mm/day) '
   endfor

   openw,5,dirres+dir_region+subpath+long_GCM+sub_region+cc+'_bias.dat'
   printf,5,'Lat  Lon(rea) dtemp  dprec  dvariab'

   openw,7,dirres+dir_region+subpath+long_GCM+sub_region+cc+'_SLE_volbz.dat'
   printf,7,'Year  vol_<0masl(km3)'

   openw,33,dirres+dir_region+subpath+long_GCM+sub_region+cc+'_calving_flux.dat'
   printf,33,'ID  frontal ablation (Gt/a)'

endif

; selecting a specific subset of glaciers from a list
if catchment_selection ne '' then begin
   if rgiregion lt 10 then a='0'+string(rgiregion,fo='(i1)') else a=string(rgiregion,fo='(i2)')
   fn=dir+'catchments/RGI'+a+'_'+catchment_selection+'.dat' & an=file_lines(fn)-1 & s=strarr(an) & tt=strarr(1)
   openr,1,fn & readf,1,tt & readf,1,s & close,1 & ss=strmid(s,9,5)

   ; running through full batch file and marking all glaciers to be computed and then reduce array
   n=n_elements(id) & tt=dblarr(n)
   for i=0l,n-1 do begin
      ii=where(id[i] eq ss,ci) & if ci gt 0 then tt[i]=1
   endfor
   ii=where(tt eq 1,ci)
   if ci gt 0 then begin
      hmed = hmed[ii] & hmin = hmin[ii] & survey_year = survey_year[ii] & volume_ini = volume_ini[ii]
      xy = xy[*, ii] & a_gl = a_gl[ii] & id = id[ii]
   endif
   lat_gl=xy[1,*] & lon_gl=xy[0,*]
   
endif


; ******************************
; CALIBRATION LOOP - for overall calibration on entire region

cal0max=0
if calibrate eq 'y' and calibrate_individual ne 'y' then cal0max=20

for cal0=0,cal0max do begin

; settings for calibration file
if calibrate eq 'y' then begin
   plot='n' & tran=cran & write_file='n' & glacier_retreat='n'
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
   years=tran[1]-tran[0]+1
   openw,3,dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
   case meltmodel of
      '1': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    DDFsnow  DDFice   Cprec   T_off  Flag'
      '3': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    C0       C1       a_ice    a_snow   Cprec  T_off  Flag'
   endcase
   
   if calibrate_glacierspecific eq 'y' then begin
      openw,50,dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+cc+'_overview_glspec.dat'
      printf,50,'ID      Y0    Y1    Target    Ba         Bw     Area     ELA   AAR    DDFsnow  DDFice   Cprec   T_off  Flag'
   endif   

   openw,4,dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
endif

vol_bz=dblarr(years)    ; define array for storing ice volume below sea level

; ******************************
; LOOPs over grids

; determine the range of glaciers that are covered in region
lon0=[fix(min(lon_gl)/grid_step)*grid_step-grid_step/2.,fix(max(lon_gl)/grid_step)*grid_step+grid_step/2.+2*grid_step]
lat0=[fix(min(lat_gl)/grid_step)*grid_step-grid_step/2.,fix(max(lat_gl)/grid_step)*grid_step+grid_step/2.+2*grid_step]

if single_glacier ne '' then begin
   gg=where(id eq single_glacier,cg)
   if cg gt 0 then begin
      lon0=[fix(min(lon_gl[gg])/grid_step)*grid_step-grid_step/2.,fix(max(lon_gl[gg])/grid_step)*grid_step+grid_step/2.]
      lat0=[fix(min(lat_gl[gg])/grid_step)*grid_step-grid_step/2.,fix(max(lat_gl[gg])/grid_step)*grid_step+grid_step/2.]
   endif
endif

if grid_run eq 'n' then begin
   ngx=1 & ngy=1
   lat=lat0 & lon=lon0
endif else begin
   ngx=fix((lon0[1]-lon0[0])/grid_step) & ngy=fix((lat0[1]-lat0[0])/grid_step)
   if ngx lt 1 then ngx=1 & if ngy lt 1 then ngy=1
endelse

for gx=0,ngx-1 do begin

for gy=0,ngy-1 do begin

if grid_run eq 'y' then begin
   lon=[lon0[0]+gx*grid_step,lon0[0]+gx*grid_step+grid_step]
   lat=[lat0[0]+gy*grid_step,lat0[0]+gy*grid_step+grid_step]
endif


; ---------------------------
; select glacier subsample to be calculated
if lat[0] ne -99 and size_range[0] ne -99 then gg=where(xy[1,*] gt lat[0] and xy[1,*] lt lat[1] and xy[0,*] gt lon[0] and xy[0,*] lt lon[1] and a_gl gt size_range[0] and a_gl lt size_range[1] and volume_ini gt 0,cg)
if lat[0] ne -99 and size_range[0] eq -99 then gg=where(xy[1,*] gt lat[0] and xy[1,*] lt lat[1] and xy[0,*] gt lon[0] and xy[0,*] lt lon[1] and volume_ini gt 0,cg)
if lat[0] eq -99 and size_range[0] ne -99 then gg=where(a_gl gt size_range[0] and a_gl lt size_range[1] and volume_ini gt 0,cg)
if single_glacier ne '' then gg=where(id eq single_glacier and volume_ini gt 0,cg)

latitudes=lat_gl[gg] & longitudes=lon_gl[gg]

; storage arrays
stor_im=dblarr(nout) & stor_dv=stor_im & stor_ar=stor_im & stor_vo=stor_im

; ******************************************
; climate series - read individual series for every evaluation cell!

if cg gt 0 then begin

if calibrate eq 'n' then a=GCM_model[gcms]+'/'+GCM_rcp[rcps] else a='CALI - '+reanalysis
if total(a_gl[gg]) gt 10. and gx mod 2 eq 0 and gy mod 2 eq 0 then $
  print, dir_region+' '+clim_subregion+' ('+a+'): '+string(mean(lat),fo='(f5.1)')+'/'+string(mean(lon),fo='(f6.1)')+$
  ', '+string(total(a_gl[gg]),fo='(i5)')+'km2 ('+string(cg,fo='(i4)')+')'


; SPLIT between DAILY climate data and MONTHLY climate data
; (not yet in procedures for monthly...)
if time_resolution eq 'daily' then begin

; select reanalysis series from closest grid point
rmid=[mean(lon),mean(lat)]
gxs=strcompress(string(rmid[0],fo='(f7.2)'),/remove_all)
gys=strcompress(string(rmid[1],fo='(f7.2)'),/remove_all)

; ------------------------------
; meteo time series read from re-analysis data (pas±t)

READ_CLIMATEPAST_DAILY,dir_clim,dir_region,reanalysis,gxs,gys, tempre,precre,p_thres,ryear,rday,rmon,dtdz,prec_orig,cyear,cday,temp,prec,hclim, time_resolution

; ---------------------------------
; ---------------------------------
; meteo time series downscaled from GCMs or whatever (future)
if reanalysis_direct eq 'n' then begin

   READ_GCMDATA_DAILY,dir_clim,GCM_data,dir_region,GCM_model,GCM_rcp,gcms,rcps, rmid,  tempgcm,precgcm,gcm_year,gcm_mon,gcm_day, time_resolution 

   DOWNSCALE_GCMDATA_DAILY,gcm_year,gcm_mon,gcm_day,ryear,rmon,rday,m,rea_eval,rmid,years,tran,tempgcm,tempre,precgcm,precre,prec_orig,min_tempbias,min_precbias,write_file,meltmodel,variability_bias_longterm,p_thres, temp,prec,rad,cyear,cday,cmon

endif

endif    ; daily time resolution

; ----- MONTHLY

if time_resolution eq 'monthly' then begin

   gmid=[mean(latitudes),mean(longitudes)]

   DOWNSCALE_GCMDATA_MONTHLY,gcm_year,gcm_mon,ryear,rmon,m,rea_eval,rmid,gmid,gcm_lat,gcm_lon,rlat,rlon,relev,years,tran,rtemp,rprec,rrad,gcm_temp,gcm_prec,min_tempbias,min_precbias,write_file,meltmodel,reanalysis_direct,variability_bias,p_thres, temp,prec,rad,cyear,cmon,nlons,nlats,hclim,cc,bb

   GRADIENT_VARIABILITY_MONTHLY, cc,bb,rtg,dtdz,submonth_variability,rvariab,variab
   
endif

endif                               ; is there a glacier in the cell?


; *****************************************************
; MAIN LOOP over all glaciers

for g=0l,cg-1 do begin

; ******************************
; CALIBRATION LOOP - for single-glacier calibration

cal1max=0
if calibrate_individual eq 'y' then begin
   cal1max=15
endif

for cal1=0,cal1max do begin


; ---------------------
; read hypsometry-file
fn=dir_data+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)

if a[0] ne '' then begin

READ_HYPSOMETRYFILE,fn,gg,g,a_gl,nb,da,advance,adv_calving,adv_addband,adv_addband0,hmin, dir_data_alt,region,id

; generate hypsometric information & parameters for glogemflow
if use_flow_model eq 'y' then begin
   @procedures/flow/set_flow_model_parameters
   @procedures/flow/convert_vertical_to_horizontal_grid
   @procedures/flow/constants_counters_initialvalues_sizevariables
   @procedures/flow/initial_geometry
endif

; find geothermal heat flux for glacier
if firnice_temperature eq 'y' then begin
   a=min(abs(latitudes[g]-fit_yy),indy) &  a=min(abs(longitudes[g]-fit_xx),indx)
   geothermal_flux=firnice_geotherm_flux[indx,indy]
endif

; define variables
area=da[3,*]
elev=da[1,*]+5
thick=da[4,*]
width=da[5,*]
slope=da[7,*]

ii=where(area gt 0 and thick eq 0,ci) & if ci gt 0 then thick[ii]=3. ; prevent division by 0 due to error in thick-file
bed_elev=elev-thick & step=elev[1]-elev[0] & e0=elev[0] & elev0=elev
; correcting unrealistic values in lowest band
if bed_elev[0] lt 0 and thick[0] gt thick[1]+2. then begin
   thick[0]=thick[1]+2. & bed_elev=elev-thick
endif

; specific definition of transversal bedrock shapes for individual regions
if dir_region eq 'SouthernAndes' then bedrock_parabolacorr=0.35
if dir_region eq 'Greenland' then bedrock_parabolacorr=0.30

; bedrock profile corrected for Parabola-shape
if min(bed_elev) lt 200 then begin
   bed_elev_p=bed_elev-bedrock_parabolacorr*thick
   for i=0,nb-1 do begin
      if width[i] gt (crit_ccorrdist/2.) then bed_elev_p[i]=bed_elev[i]-thick[i]*bedrock_parabolacorr*(crit_ccorrdist/2.)/width[i]
   endfor
endif

ii=where(thick gt 0,ci) & if calibrate eq 'y' and ci eq 0 then thick=thick+1.
gl=dblarr(nb)+noval &  if ci gt 0 then gl[ii]=elev[ii]
length = dblarr(nb)
for i=0,nb-1 do begin
   length[i] = (max(da[6,*]) - da[6,i]) / 1000
endfor
thick_ini=thick & area_ini=area
area_iniconst=area   ; will not be affected by glacier advance!
volume0=total(thick_ini*area_ini)/1000.
tgs_cum=dblarr(nb)   ; array for storing local air temperatures

; ------------------------------
; prepare output for mass balance in elevation bands

if meltmodel eq '1' then mtt='' else mtt='_m3'
b='/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
if reanalysis_direct eq 'y' then b='/PAST'+mtt

if write_mb_elevationbands eq 'y' then begin

   c=findfile(dirres+dir_region+b+'/mb_elevation')
   if c[0] eq '' then begin
      spawn,'mkdir '+dirres+dir_region+b+'/mb_elevation' & spawn,'chmod a+rx '+dirres+dir_region+b+'/mb_elevation'
   endif

   openw,8,dirres+dir_region+b+'/mb_elevation/belev_'+id[gg[g]]+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
   printf,8,'Elev  '+a+a
   elev_bmb=dblarr(years,nb)+snoval & elev_bwb=elev_bmb 

   ; elevation-specified refreezing files 
   c=findfile(dirres+dir_region+b+'/refr_elevation')
   if c[0] eq '' then begin
      spawn,'mkdir '+dirres+dir_region+b+'/refr_elevation' & spawn,'chmod a+rx '+dirres+dir_region+b+'/refr_elevation'
   endif
   openw,40,dirres+dir_region+b+'/refr_elevation/refrelev_'+id[gg[g]]+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
   printf,40,'Elev  '+a &  elev_refr=dblarr(years,nb)+snoval 

   if debris_supraglacial eq 'y' then begin
   ; elevation-specified debris files 
      c=findfile(dirres+dir_region+b+'/debris_elevation')
      if c[0] eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/debris_elevation' & spawn,'chmod a+rx '+dirres+dir_region+b+'/debris_elevation'
      endif
      openw,41,dirres+dir_region+b+'/debris_elevation/debthick_'+id[gg[g]]+'.dat'
      a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
      printf,41,'Elev  '+a &  elev_debthick=dblarr(years,nb)+snoval 

      openw,42,dirres+dir_region+b+'/debris_elevation/debfrac_'+id[gg[g]]+'.dat'
      printf,42,'Elev  '+a &  elev_debfrac=dblarr(years,nb)+snoval 

      openw,43,dirres+dir_region+b+'/debris_elevation/debfactor_'+id[gg[g]]+'.dat'
      printf,43,'Elev  '+a &  elev_debfactor=dblarr(years,nb)+snoval 

      openw,44,dirres+dir_region+b+'/debris_elevation/pondarea_'+id[gg[g]]+'.dat'
      printf,44,'Elev  '+a &  elev_pondarea=dblarr(years,nb)+snoval 

      if eval_mbelevsensitivity eq 'y' then begin
         openw,44,dirres+dir_region+b+'/debris_elevation/mbsensitivity_'+id[gg[g]]+'.dat'
         printf,44,'Elev  '+a &  elev_mbsens=dblarr(years,nb)+snoval &  elev_mbsensall=dblarr(count_mbelevsens_v0+1,years,nb)+snoval 
      endif
   endif
endif

; prepare output of ice temperature model
if firnice_temperature eq 'y' then begin
   if firnice_write[0] eq 'y' then begin
      c=findfile(dirres+dir_region+b+'/firnice_temperature')
      if c[0] eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+dir_region+b+'/firnice_temperature'
      endif
      openw,45,dirres+dir_region+b+'/firnice_temperature/temp_1m_'+id[gg[g]]+'.dat'
      a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
      printf,45,'Elev  '+a 
      elev_firnicetemp=dblarr(4,years,nb)+snoval ; all layers

      openw,46,dirres+dir_region+b+'/firnice_temperature/temp_10m_'+id[gg[g]]+'.dat'
      printf,46,'Elev  '+a 

      openw,47,dirres+dir_region+b+'/firnice_temperature/temp_50m_'+id[gg[g]]+'.dat'
      printf,47,'Elev  '+a

      openw,48,dirres+dir_region+b+'/firnice_temperature/temp_bedrock_'+id[gg[g]]+'.dat'
      printf,48,'Elev  '+a
   endif
   if enable_advection eq 'y' AND advection_write eq 'y' then begin
      c=findfile(dirres+dir_region+b+'/firnice_temperature')
      IF c[0] EQ '' THEN BEGIN
         spawn,'mkdir '+dirres+dir_region+b+'/firnice_temperature' 
         spawn,'chmod a+rx '+dirres+dir_region+b+'/firnice_temperature'
      ENDIF

      openw,70,dirres+dir_region+b+'/firnice_temperature/adv_horizontal_'+id[gg[g]]+'.dat'
      a='' & FOR i=0,years-1 DO a=a+string(i+tran[0],fo='(i4)')+'  '
      printf,70,'Elev  '+a
      elev_adv_horiz=dblarr(years,nb)+snoval

      openw,71,dirres+dir_region+b+'/firnice_temperature/adv_vertical_'+id[gg[g]]+'.dat'
      printf,71,'Elev  '+a
      elev_adv_vert=dblarr(years,nb)+snoval
   endif

   if firnice_write[1] eq 'y' then begin
      c=findfile(dirres+dir_region+b+'/firnice_temperature')
      if c[0] eq '' then begin
         spawn,'mkdir '+dirres+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+dir_region+b+'/firnice_temperature'
      endif

      ; determining elevations to be outputted
      firnice_profile_ind=dblarr(2,n_elements(firnice_profile)) ; index / abs elev.
      if firnice_profile[0] lt 1 then begin  ; relative elev
           for i=0,n_elements(firnice_profile)-1 do begin
            firnice_profile_ind[0,i]=fix(firnice_profile[i]*nb)
            firnice_profile_ind[1,i]=elev0[firnice_profile_ind[0,i]]
         endfor
      endif else begin  ; abs elev
         for i=0,n_elements(firnice_profile)-1 do begin
            a=min(abs(elev0-firnice_profile[i]),ind)
            firnice_profile_ind[0,i]=ind & firnice_profile_ind[1,i]=elev0[firnice_profile_ind[0,i]]
         endfor
      endelse
      
      for j=0,n_elements(firnice_profile)-1 do begin
         openw,51+j,dirres+dir_region+b+'/firnice_temperature/temp_ID'+firnice_profile_ID[j]+'_'+id[gg[g]]+'.dat'
         printf,51+j,'Point elevation  '+string(firnice_profile_ind[1,0],fo='(i4)')+' masl: Depth in m'
         a='' & for i=1,total(fit_layers)-1 do a=a+string(fit_dz[1,i],fo='(i4)')+'  '
         printf,51+j,'Year  Month '+a 
      endfor
   endif

endif

;prepare output for hypsometry-evolution file
if write_hypsometry_files eq 'y' then begin
   b='/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
   if reanalysis_direct eq 'y' then b='/PAST'
   
   ; Use FILE_TEST instead of findfile
   dir_path = dirres+dir_region+b+'/hypsometry'
   dir_exists = FILE_TEST(dir_path, /DIRECTORY)
   
   print, b
   print, 'Directory exists:', dir_exists
   print, dir_path

   ; Create hypsometry directory if it does not exist
   if ~dir_exists then begin
      spawn, 'mkdir -p "'+dir_path+'"'
      spawn, 'chmod a+rx "'+dir_path+'"'
   endif
   openw,9,dirres+dir_region+b+'/hypsometry/hypso_'+id[gg[g]]+'.dat'
   openw,34,dirres+dir_region+b+'/hypsometry/volume_'+id[gg[g]]+'.dat'
   openw,35,dirres+dir_region+b+'/hypsometry/temp_'+id[gg[g]]+'.dat'

   ctt=0 & h=strarr(1)
   for i=tran[0],tran[1] do begin
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
    for i=jj[0]-1,0,-1 do adv_iniamplification[i]=1+((jj[0]-i)/(adv_addband/2.))^3.
	; define some more variables
    adv_iniar=mean(area_ini[jj[0:tt]]) & adv_inithi=mean(thick_ini[jj[0:tt]])
    if cj ne nb then begin
        idx = where(width eq 0, count)
        if count gt 0 then width[idx] = mean(width[jj[0:tt]])
    endif
    dl=(length[jj[0]]-length[jj[tt]])/(tt+1)
    for i=jj[0]-1,0,-1 do length[i]=length[i+1]+dl
endif

; -------------------
; potential radiation time series
if meltmodel eq '3' then begin

   POTENTIAL_SOLARRADIATION,nb,da,slope,decl_sun,latutudes,g,sw_rad

endif

; ---------------------
; read files for supraglacial debris

if debris_supraglacial eq 'y' then begin
  
Read_SUPRAGLACIALDEBRIS, debris_supraglacial, region, id, gg, g, dir_data, advance, nb, adv_addband, debris_pond_enhancementfactor, debris_thick0, debris_thick, debris_frac, debris_mf, debris_ponddens, debris_type_th, debris_type_red

endif

; ---------------------
; attribute specific parameter values

if read_parameters eq 'y' and cal1 eq 0 then begin

   a=min(abs(double(id[gg[g]])-cali_id),ind)

	case meltmodel of
      '1': Begin
         DDFice=cali_ddfice[ind] & DDFsnow=cali_ddfsnow[ind] & C_prec=cali_cprec[ind]
         t_offset=cali_toff[ind]
      	end
      '3': begin
         C0=cali_c0[ind] & C1=cali_c1[ind] & alb_ice=cali_a_ice[ind] & alb_snow=cali_a_snow[ind]
         C_prec=cali_cprec[ind] & t_offset=cali_toff[ind]
		end
      endcase

endif

if toff_grid eq 'y' and calibrate eq 'y' and calibration_phase ne '3' then begin
   a=min(abs(double(id[gg[g]])-cali_id_toff),ind)
   t_offset=toff_data[ind]
endif

; ---------------------
; define arrays
gls=dblarr(nout,nb) & cnp=0
areas=dblarr(years) & volumes=areas
flux_calv=areas

sur=dblarr(nb) & sno=sur & snostor=sur
firn=sur & ff=where(elev gt hmed[gg[g]],ci) & if ci gt 0 then firn[ff]=1
baly=dblarr(years,nb)
if nb gt elev_range_p/step and plot eq 'y' then begin
   accy=baly & mely=baly & refry=baly
endif
if time_resolution eq 'daily' then begin
   if outf_names[14] ne '' then begin
      accday=dblarr(years*365.)+snoval & rainday=accday & snowmeltday=accday & refrday=accday & discharge_gl=accday & icemeltday=accday & snowlineday=accday
   endif
   discharge=dblarr(years*365.)
endif else begin
   if outf_names[14] ne '' then begin
      balmo=dblarr(years*12)+snoval & melmo=balmo & accmo=balmo & refrmo=balmo & discharge_gl=balmo & precmo=balmo
   endif
   discharge=dblarr(years*12.)
endelse
mb=dblarr(years)+snoval & wb=mb
smelt=dblarr(years) & imelt=smelt & accum=smelt & rain=smelt & refre=smelt
ela=dblarr(years)+snoval & dbdz=ela & btongue=ela & aar=ela & hmin_g=ela
area_cat=total(area)

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
   if ci gt 0 then a=temp[ii]+(elev[i]-hclim)*mean(dtdz)+t_offset $
     else a=temp+(elev[i]-hclim)*mean(dtdz)+t_offset
   tt[i]=mean(a)
endfor
te_fit=dblarr(nb,total(fit_layers)+1)
for i=0,nb-1 do te_fit[i,*]=tt[i]
tl_fit=te_fit


for ye=0,years-1 do begin

Print,'Processing year: ', ye+tran[0], ' for glacier: ', id[gg[g]]

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
ii=where(gl ne noval,ci) & if ci gt 0 then ar_gl=total(area[ii]) else ar_gl=0
if elev[0] gt elev[1]+100 then elev[0]=elev[1]

; allow glacier area changes in hindcast period after date of RGI
if hindcast_dynamic eq 'y' then if ye+tran[0] ge survey_year[gg[g]] then glacier_retreat='y'    

; determining date for starting the retreat of each individual glacier
; depending on RGI-outline date (GLACIER-SPECIFIC!) - take care for evaluation
if find_startyear eq 'y' then if ye+tran[0] gt survey_year[gg[g]] then glacier_retreat='y' 

; glacier retreat to 'n' if local mass balance gradients are evaluated 
if eval_mbelevsensitivity eq 'y' then glacier_retreat='n' 

; different parts of hydrological year
for d=0,1 do begin

if d eq 0 then st=bal_month else st=1
if d eq 0 then en=dd_thresholds[3] else en=bal_month-1

; ****************************
; loop over months
for m=st,en do begin

psg=dblarr(nb) & mel=psg & refr=psg & corrdis=psg & snowmel=mel & icemel=mel

; correct snow storage array
if bal_month eq dd_thresholds[2] then if m eq 1 then sno=sno-snostor
if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sno=sno-snostor
jj=where(sno lt 0,cj) & if cj gt 0 then sno[jj]=0

; *******************************************
; Climate data extrapolation

if time_resolution eq 'monthly' then cdm=cmon else cdm=cday
if ccmon eq 0 then jjclim=where(cyear eq ye-1+tran[0] and cdm eq m)
tg=temp[jjclim[0]+ccmon]+(elev-hclim)*dtdz[m-1]+t_offset

; *******************************************
; Mass balance model

; *********** accumulation

pc=prec[jjclim[0]+ccmon]*c_prec/1000.        ; correct quantity to m w.e.
pg=pc+pc*((elev-hclim)/10000.)*dpdz    ; extrapolate with elevation
; constrain high elevation precipitation
jj=where(gl ne noval,cj)
if cj*step gt no_incprec[1] then begin
   ii=where(elev gt elev[jj[fix(cj*no_incprec[0])]],ci) &  if ii[0] eq 0 then a=1 else a=0
   for i=0,ci-1 do pg[ii[i]]=pg[ii[a]-1]-pg[ii[a]-1]*no_incprec[2]*(i/double(ci)*(1-no_incprec[0]))^no_incprec[3]
endif
; state of precipitation
ii=where(tg lt T_thres-1,ci)
if ci gt 0 then psg[ii]=pg[ii]
ii=where(tg gt T_thres-1 and tg lt T_thres+1,ci)
if ci gt 0 then psg[ii]=pg[ii]*(-(tg[ii]-T_thres-1.)/2.)
plg=pg-psg
psg=psg*snow_multiplier

if ar_gl ne 0 then accum[ye]=accum[ye]+total(psg*area)/ar_gl
if ar_gl ne 0 then rain[ye]=rain[ye]+total(plg*area)/ar_gl

ccmon=ccmon+1

; ***********  melt (positive)

; sub-monthly variability (excluded by default for daily model and energy balance model!)
if time_resolution eq 'monthly' and submonth_variability eq 'y' and meltmodel ne '3' then begin

a=dblarr(mon_len[m-1]) & tgs=tg
; superimpose variability / make sure no shift in mean T is introduced!
for i=0,mon_len[m-1]-1 do a[i]=tgs[0]+variab[m-1,i]-mean(variab[m-1,0:mon_len[m-1]-1])
for j=0,nb-1 do begin
   b=a+(tgs[j]-tgs[0])
   ii=where(b gt 0,ci) & if ci gt 0 then pdd=total(b[ii]) else pdd=0.
   if pdd gt 0 then tg[j]=pdd/mon_len[m-1]
endfor

endif else tgs=tg
tgs_cum=tgs_cum+tgs

; ----------
case meltmodel of

'1': BEGIN
ii=where(sur eq 1 and tg gt t_melt,ci)   ; snow
if ci gt 0 then begin
   mel[ii]=DDFsnow*tg[ii]*mon_len[m-1]/1000
   jj=where(gl[ii] ne noval,cj)
   if cj gt 0 and ar_gl ne 0 then smelt[ye]=smelt[ye]+total(mel[ii[jj]]*area[ii[jj]])/ar_gl
   if time_resolution eq 'daily' then snowmel[ii]=mel[ii]
endif

ii=where(sur eq 2 and tg gt t_melt,ci)    ; Firn
if ci gt 0 then begin
   mel[ii]=(0.5*DDFice+0.5*DDFsnow)*tg[ii]*mon_len[m-1]/1000.
   imelt[ye]=imelt[ye]+total(mel[ii]*area[ii])/ar_gl
   if time_resolution eq 'daily' then icemel[ii]=mel[ii]
endif

ii=where(sur eq 0 and tg gt t_melt,ci)   ; Ice
if ci gt 0 then begin
   mel[ii]=DDFice*tg[ii]*mon_len[m-1]/1000.
   imelt[ye]=imelt[ye]+total(mel[ii]*area[ii])/ar_gl
   if time_resolution eq 'daily' then icemel[ii]=mel[ii]
endif

if debris_supraglacial eq 'y' then begin

CALCULATEDEBRISMELT, debris_supraglacial, sur, tg, t_melt, debris_thick, debris_frac, debris_type_th, debris_type_red, debris_ponddens, debris_pond_enhancementfactor, mel, imelt, ye, ar_gl, area, time_resolution, icemel, write_mb_elevationbands


endif                           ; debris

end

; ---------
'3': BEGIN

ii=where(sur eq 1,ci)    ; snow
if ci gt 0 then begin
   mel[ii]=((1.-alb_snow)*sw_rad[ii,m-1]+C0+C1*tg[ii])*3600*24.*mon_len[m-1]/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel[jj]=0
   smelt[ye]=smelt[ye]+total(mel[ii]*area[ii])/ar_gl
   if time_resolution eq 'daily' then snowmel[ii]=mel[ii]
endif

ii=where(sur eq 2,ci)    ; Firn
if ci gt 0 then begin
   mel[ii]=((1.-alb_firn)*sw_rad[ii,m-1]+C0+C1*tg[ii])*3600*24.*mon_len[m-1]/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel[jj]=0
   imelt[ye]=imelt[ye]+total(mel[ii]*area[ii])/ar_gl
   if time_resolution eq 'daily' then icemel[ii]=mel[ii]
endif

ii=where(sur eq 0,ci)   ; Ice
if ci gt 0 then begin
   mel[ii]=((1.-alb_ice)*sw_rad[ii,m-1]+C0+C1*tg[ii])*3600*24.*mon_len[m-1]/1000./lhf
   jj=where(mel lt 0,cj) & if cj gt 0 then mel[jj]=0
   imelt[ye]=imelt[ye]+total(mel[ii]*area[ii])/ar_gl
   if time_resolution eq 'daily' then icemel[ii]=mel[ii]
endif

if debris_supraglacial eq 'y' then begin

ii=where(sur eq 0 and tg gt t_melt and debris_thick gt 0 and debris_frac gt 0,ci)   ;  debris-covered ice
if ci gt 0 then begin
   for i=0l,ci-1 do begin
      a=min(abs(debris_thick[ii(i)]-debris_type_th),ind) ; looking for closest value (may be improved by interpolating)
      if write_mb_elevationbands eq 'y' then debris_red_factor[ii(i)]=debris_type_red(ind)
      ; debris-covered ice + bare ice + area of ponds/cliffs
      mel[ii(i)]=(debris_frac(0,ii(i))-debris_ponddens(ii(i)))*debris_type_red(ind)*mel[ii(i)]  +  (1.-debris_frac(0,ii(i)))*mel[ii(i)]  +  debris_ponddens(ii(i))*debris_pond_enhancementfactor*mel[ii(i)]
   endfor
   imelt[ye]=imelt[ye]+total(mel[ii]*area[ii])/ar_gl ; updating array from above
   if time_resolution eq 'daily' then icemel[ii]=mel[ii]
endif

endif

end

ENDCASE

; ***************************************
; ***********  refreezing (positive)

if refreezing_full eq 'y' then begin

REFREEZING_FULL,gl,ye,mel,plg,sno,dens_rf,rf_melcrit,rf_ind,rf_dsc,rf_dz,rf_dt,rf_layers,rf_cold,lh_rf,tl_rf,te_rf,cond,cap,tgs,firn,ar_gl,refr,area,refre

endif


; ***************************************
; ***********  firn/ice temperatures
; (separate workflow as the target and setup differs)

if firnice_temperature eq 'y' then begin

   FIRNICE_TEMPERATURE_MODEL,gl,fit_layers,fit_dens,fit_dz, rf_dsc,rf_dt,Lh_rf, $
   tgs,tl_fit,te_fit,geothermal_flux, cair,cice,kair,kice, sno,mel,plg,thick,slope,firn, $
   firnice_batch,firnice_write,firnice_maxdepth, fit_water,elev_firnicetemp,firnice_profile, $
   firnice_profile_ind,ye,tran,m, firn_permeability,ice_permeability, enable_advection=enable_advection, $
   diff_coef=diff_coef, elev_adv_horiz=elev_adv_horiz, elev_adv_vert=elev_adv_vert, advection_write=advection_write

endif    ; firn-ice temperature model



; ---- adapting snow reservoir
;      correcting for overestimated melt (disapperance of snow during month)
sno=sno+psg-mel     ;   +refreeze - should refreezing be included here?
jj=where(sno gt 0,cj) & if cj gt 0 then sur[jj]=1
jj=where(sno lt 0,cj)
if cj gt 0 then begin
   hh=where(gl[jj] eq noval,ch)
   if ch gt 0 then mel[jj[hh]]=mel[jj[hh]]+sno[jj[hh]]
 ; correction for ice-free area in glacierized elevation bands - only relevant for calculating catchment discharge
   hh=where(gl[jj] ne noval,ch)
   if ch gt 0 then corrdis[jj[hh]]=mel[jj[hh]]+sno[jj[hh]]
   sno[jj]=0
endif

; ------- calculate catchment discharge
;    Melting and refreezing are the same inside and outside the
;    glacier if snow cover present; if no snow melting and refreezing
;    only refer to the ice surface => weighted average for specific discharge
difarea=area_iniconst-area & ii=where(difarea lt 0,ci) & if ci gt 0 then difarea[ii]=0
ii=where(area_iniconst gt 0,ci) & dd=0
for i=0l,ci-1 do begin
   if sur[ii[i]] eq 1 then dd=dd+mel[ii[i]]*area_iniconst[ii[i]]+plg[ii[i]]*area_iniconst[ii[i]]-refr[ii[i]]*area_iniconst[ii[i]]-corrdis[ii[i]]*difarea[ii[i]] $
   else begin
      if area_iniconst[ii[i]] lt area[ii[i]] then a=area_iniconst[ii[i]] else a=area[ii[i]]
      dd=dd+mel[ii[i]]*a+plg[ii[i]]*area_iniconst[ii[i]]-refr[ii[i]]*a
   endelse
endfor
discharge[ccmon-1]=dd/area_cat

; ---- adapting surface type
jj=where(sno eq 0 and gl ne noval,cj) & if cj gt 0 then sur[jj]=0
jj=where(sno eq 0 and gl eq noval,cj) & if cj gt 0 then sur[jj]=noval
jj=where(sno eq 0 and firn eq 1,cj) & if cj gt 0 then sur[jj]=2

; cumulate balances - store results
bal=bal+psg-mel+refr
melt=melt+mel
acc=acc+psg
refreeze=refreeze+refr

; storing day variables
if outf_names[14] ne '' then begin
   if ar_gl ne 0 then discharge_gl[ccmon-1]=(total(mel*area)+total(plg*area)-total(refr*area))/ar_gl
   if time_resolution eq 'monthly' then begin
      balmo[ccmon-1]=total((psg-mel+refr)*area)/ar_gl & melmo[ccmon-1]=total(mel*area)/ar_gl
      accmo[ccmon-1]=total(psg*area)/ar_gl & refrmo[ccmon-1]=total(refr*area)/ar_gl
      precmo[ccmon-1]=total((psg+plg)*area)/ar_gl
   endif else begin
; for entire catchment
      accday[ccmon-1]=total((psg)*area_ini)/total(area_ini) & refrday[ccmon-1]=total(refr*area_ini)/total(area_ini)
      rainday[ccmon-1]=total((plg)*area_ini)/total(area_ini)
      snowmeltday[ccmon-1]=total((snowmel)*area_ini)/total(area_ini) & icemeltday[ccmon-1]=total((icemel)*area)/total(area_ini)
   ; rather write out snowcover-percentage??
      jj=where(sno eq 0 and gl ne noval,cj) 
      if cj gt 0 then begin
        snowlineday[ccmon-1]=gl[jj(cj-1)]
        ; Select lowest elevation bin of the glacier if fully snow covered
      endif else begin
        ; Filter out negative values
        positive_values = gl[where(gl GE 0)]
        ; Get the minimum of positive values
        min_snowline = positive_values[0]
        snowlineday[ccmon-1]=min_snowline
      endelse


   endelse   

endif



if ar_gl ne 0 then begin

   if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then wb[ye]=total(bal*area)/ar_gl
   if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then wb[ye]+=total(bal*area)/ar_gl

   ; set bal-array to noval in case there is no glacier
   ii=where(gl eq noval,ci) & if ci gt 0 then bal[ii]=snoval

   if write_mb_elevationbands eq 'y' then begin
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then elev_bwb[ye,*]=bal
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then elev_bwb[ye,*]=bal
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_bmb[ye,*]=bal
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_bmb[ye,*]=bal
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_refr[ye,*]+=refreeze*1000.
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_refr[ye,*]+=refreeze*1000.
      if eval_mbelevsensitivity eq 'y' then begin
         if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]=bal
         if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]+=bal
      endif
   endif
endif

endfor                          ; loop over months

endfor                          ; parts of hydrological year

; evaluations for mass balance sensitivity to elevation
; Not sure anymore what this was good for... Just adding it as it was
; in the monthly model
if time_resolution eq 'monthly' and eval_mbelevsensitivity eq 'y' then begin
   if count_mbelevsens ge 0 then begin
      ccmon=ccmon-12  ; set back the months counter      
      goto, mbelevsensitivity_again 
   endif else begin
      bb=n_elements(elev_mbsensall[*,0,0]) & a=dblarr(1,bb) & b=dblarr(bb) & c=b
      for i=0,nb-1 do begin
         for j=0,bb-1 do a[0,j]=elev_mbsensall[j,ye,i] & for j=0,bb-1 do b[j]=j*50*(-1.) & for j=0,bb-1 do c[j]=1. ; c not needed for IDL!
         ; tt=correlate(a,b)  ; use this for IDL!
         tt=regress(a,b,c) 
         elev_mbsens[ye,i]=1./tt*100.    ; local mass balance gradient in year ye in m w.e. / 100m
      endfor
   endelse
endif

; calculate balance - store results
if ar_gl ne 0 then mb[ye]=total(bal*area)/ar_gl
baly[ye,*]=bal
if nb gt elev_range_p/step and plot eq 'y' then begin
   ii=where(gl eq noval,ci) & if ci gt 0 then melt[ii]=noval
   accy[ye,*]=acc  & mely[ye,*]=melt  & refry[ye,*]=refreeze
endif
balv=bal*area*1000000.

snostor=sno

; --------- update firn coverage
; look 5 years back and average mass balance
; => firn where average mb > 0
if ye gt 4 then begin
   balm=dblarr(nb)
   for i=0,nb-1 do balm[i]=mean(baly[ye-4:ye,i])
   firn=dblarr(nb) & ii=where(balm gt 0 and gl ne noval,ci) & if ci gt 0 then firn[ii]=1
endif


; --------------------------
; statistics (area and volume stored BEFORE surface updating - reference for calculations)
area1=total(area) & areas[ye]=area1 & volume1=total(thick*area)/1000. & volumes[ye]=volume1
area_stor=area
bb=where(bed_elev lt 0 and bed_elev gt -800. and thick gt 0,cb)
if cb gt 0 then vol_bz[ye]=vol_bz[ye]-0.001*total(bed_elev[bb]*area[bb])

; more statistics
jj=where(thick gt 0,cj)
if cj gt 0 then begin
   ht1=elev[jj[0]] 
   ii=where(bal[jj] gt 0,ci) & if ci gt 0 then aar[ye]=total(area_stor[jj[ii]])*100./area1 else aar[ye]=0
   btongue[ye]=min(bal[jj],ind) &  if ci gt 0 then ela[ye]=elev[jj[ii[0]]] else ela[ye]=max(elev)
   da=(elev[jj[ind]]-ela[ye]) & if abs(da) gt 20 then dbdz[ye]=btongue[ye]/da else dbdz[ye]=0.
endif else ht1=max(elev)
hmin_g[ye]=ht1

jj=where(gl eq noval,cj) & if cj gt 0 then sur[jj]=noval
; check if there is a glacier left - if not end  the loop!!!
if outf_names[n_elements(where(outf_names ne ''))-1] eq 'n' then if cj eq nb then ye=1000

if write_hypsometry_files eq 'y' then begin
   if (ye+tran[0]) mod 10 eq 0 then begin
      hypso_file[0,chypso,*]=elev & hypso_file[1,chypso,*]=area & hypso_file[2,chypso,*]=area*thick
      hypso_file[3,chypso,*]=tgs_cum/(10*12.) & tgs_cum=dblarr(nb) ; set array back
      chypso=chypso+1
   endif
endif

; store glacier geometry for previous volumes
if adv_lookup eq 'y' then begin
   adv_lookup_data[0,0,ye]=volume1   ; storing easily accessible overall volume
   adv_lookup_data[1,*,ye]=area      ; storing area distribution
   adv_lookup_data[2,*,ye]=thick     ; storing thickness distribution
endif

; *******************************
; DEBRIS MODEL
; annually adapting debris cover extent and thickness
if debris_supraglacial eq 'y' and ar_gl gt 0 then begin

DEBRIS_MODEL, ye, nb, step, gl, noval, area, ar_gl, ela, bal, mb, elev, debris_expansion, debris_seed_bands, debris_seed_meters, debris_thickening, debris_frac, debris_thick, debris_thick_gradient, debris_ponddens, debris_pond_gradient, debris_ponddens_max, tran, survey_year, write_mb_elevationbands, debris_exp_gradient, debris_initialband, debris_red_factor, debris_thick0, elev_debthick, elev_debfrac, elev_debfactor, elev_pondarea, g, gg


endif


; *******************************************
; *******************************************
; glacier evolution model

ii=where(balv ne noval,ci)
if ci gt 0 then dvol=total(balv[ii]) else dvol=0
jj=where(balv gt 0,cj) & if cj gt 0 then av=total(balv[jj]) else av=0
dens=0.9 & dvol=dvol/dens

; *******************************************
; CALVING MODEL
; -----------------------------
; volume loss due to frontal ablation

CALVING_MODEL,thick,bed_elev,bed_elev_term,bed_elev_p,dvol,frontal_ablation,front_melt,calv_amplification,width,slope,length,alpha_f,length_corrfact,crit_ccorrdist,ccorr_expon,ccorr_param,area,acc,dens,ye,tran,id,gg,g,c_calving,ar_gl,calv_sep,glacier_retreat,single_glacier,flux_calv

; *******************************************
; choose between dhdt-parameterization and flow model

if use_flow_model eq 'y' then begin
   ; flow model -> GloGEMflow (Zekollari et al., 2019)
   @procedures/flow/glogemflow

endif else begin
   ; dhdt-parameterization (Huss et al., 2010)
   GLACIER_RETREAT,ye,thick,thick_ini,elev,bed_elev,area,areas,area_ini,gl,dh_size,nb,dvol,bal,balv,advance,adv_fcrit,volume0,volume1,volumes,adv_iniar,adv_inithi,adv_iniamplification,expon,redistribute_vplus,adv_lookup,adv_lookup_data,flux_calv,dens,ar_gl
endelse    

; write geometry files
if write_geometry_output eq 'y' then begin
   ; Initialize arrays on first year
   if ye eq 0 then begin
      thick_hist = dblarr(nb, years)
      elev_hist = dblarr(nb, years)
      bed_elev_hist = dblarr(nb, years)
      length_hist = dblarr(nb, years)
      year_hist = lonarr(years)
   endif

   ; Store geometry for this year (per elevation band)
   thick_hist[*, ye] = thick
   elev_hist[*, ye] = elev
   bed_elev_hist[*, ye] = bed_elev
   length_hist[*, ye] = length
   year_hist[ye] = ye + tran[0]

   ; At the end of the last year, save all geometry in one structure
   if ye eq years-1 then begin
      geometry_hist = {thick: thick_hist, elev: elev_hist, bed_elev: bed_elev_hist, length: length_hist, years: year_hist}
      save_file = dirres + dir_region + '/geometry_' + id[gg[g]] + '.sav'
      save, geometry_hist, file=save_file
   endif
endif

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
   endelse

endif

; account for calving fluxes during the calibration period !!!
; limited to a meaningful level
c_mb=mean(mb)-min([2,mean(flux_calv)])   
if calibrate_glacierspecific eq 'y' then begin
   ccj=where(calimb_gid eq id[gg[g]],ci)
   if ci eq 0 then ccj=n_elements(target_spec)-1    ; when no data present, just use last value (regional mean)
   if ci gt 1 then target=mean(target_spec[ccj]) $    ; averaging in case several entries are available for the same RGI-ID (Caucasus)
     else target=target_spec[ccj[0]]
   n=indgen(years)+tran[0]
   pp=where(n gt calimb_p0[ccj[0]] and n le calimb_p1[ccj[0]])
   c_mb=mean(mb[pp])-min([2,mean(flux_calv[pp])])
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
   if c_prec lt c1_tolerance[0] then c_prec=c1_tolerance[0]
   if c_prec gt c1_tolerance[1] then c_prec=c1_tolerance[1]
endif else begin
   if meltmodel eq 1 then begin
      if ddfsnow lt c2_tolerance[0] then flag=0
      if ddfsnow lt c2_tolerance[0] then ddfsnow=c2_tolerance[0]
      if ddfsnow gt c2_tolerance[1] then flag=0
      if ddfsnow gt c2_tolerance[1] then ddfsnow=c2_tolerance[1]
      ddfice=ddfsnow*rddf_si
   endif
   if meltmodel eq 3 then begin
      if c1 lt c2_tolerance[0] then flag=0
      if c1 lt c2_tolerance[0] then c1=c2_tolerance[0]
      if c1 gt c2_tolerance[1] then flag=0
      if c1 gt c2_tolerance[1] then c1=c2_tolerance[1]
   endif
endelse

endif

; ------------------------
; write hypsometry-evolution file
if write_hypsometry_files eq 'y' then begin
   for i=0,nb-1 do printf,9,bed_elev[i]+thick_ini[i],hypso_file[1,*,i],fo='('+string(1+chypso,fo='(i2)')+'f12.5)'
   close,9
   for i=0,nb-1 do printf,34,bed_elev[i]+thick_ini[i],hypso_file[2,*,i],fo='('+string(1+chypso,fo='(i2)')+'f13.5)'
   close,34
   for i=0,nb-1 do printf,35,bed_elev[i]+thick_ini[i],hypso_file[3,*,i],fo='('+string(1+chypso,fo='(i2)')+'f12.5)'
   close,35
endif

endif                           ; bedrock-file available?

endfor                          ; CALIBRATION 1 - single glacier mass balance

; ---------------------
; write calibration file
if calibrate eq 'y' then begin

   ;if mean(flux_calv) gt 0 then print, '   CALI - Calving flux (m/a):'+string(mean(flux_calv),fo='(f8.2)')+'('+string(ar_gl,fo='(i6)')+')'
   if calibrate_individual eq 'n' then flag=1
   if meltmodel eq '1' then printf,3,id[gg[g]],mean(mb),mean(wb),area1,mean(ela),mean(aar),$
     mean(dbdz)*100.,mean(btongue),DDFsnow,DDFice,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,2f7.3,f9.3,f7.2,i3)'
   if meltmodel eq '3' then printf,3,id[gg[g]],mean(mb),mean(wb),area1,mean(ela),mean(aar), $
   	 mean(dbdz)*100.,mean(btongue),C0,C1,alb_ice,alb_snow,c_prec,t_offset,flag,fo='(a,2f9.3,f11.3,i6,f6.1,2f9.3,2f8.2,3f8.4,f7.2,i3)'

   if calibrate_glacierspecific eq 'y' then printf,50,id[gg[g]],calimb_p0[ccj[0]],calimb_p1[ccj[0]],$
      target_spec[ccj[0]],mean(mb[pp]),mean(wb[pp]),area1,mean(ela[pp]),mean(aar[pp]),DDFsnow,DDFice,c_prec,$
      t_offset,flag,fo='(a,2i7,3f9.3,f11.3,i6,f6.1,2f7.3,f9.3,f7.2,i3)'

   printf,4,id[gg[g]],t_offset,flag,gx,gy,fo='(a,f9.3,3i4)'

endif

cali_calflux=cali_calflux+mean(flux_calv)/1000.*ar_gl

; ---------------------
; Write results files
if write_file eq 'y' then begin
   ; Output for daily results
   if time_resolution eq 'daily' then begin
      WRITE_RESULTS_FILES_DAILY, format_of, time_resolution, outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, accday, rainday, snowmeltday, icemeltday, refrday, snowlineday, id, gg, g, years, y     
   endif else if time_resolution eq 'monthly' then begin
      WRITE_RESULTS_FILES_MONTHLY, format_of, time_resolution, outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, balmo, precmo, accmo, mellmo, refrmo, id, gg, g, years, y
   endif else begin
      PRINT, 'Error: temporal resolution is required.'
   endelse
endif

; ------------------------
; write elevation band file
fn=dir_data+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)
if write_mb_elevationbands eq 'y' and a[0] ne '' then begin
   ii=where(thick_ini eq 0,ci) & if ci gt 0 then elev_bmb[*,ii]=snoval & if ci gt 0 then elev_bwb[*,ii]=snoval & if ci gt 0 then elev_refr[*,ii]=snoval
   for i=0,n_elements(elev_bmb[0,*])-1 do printf,8,elev0[i],elev_bmb[*,i],elev_bwb[*,i],fo='(i6,'+strcompress(string(2*years,fo='(i3)'),/remove_all)+'f7.2)'
   close,8
   for i=0,n_elements(elev_bmb[0,*])-1 do printf,40,elev0[i],elev_refr[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f7.1)' &  close,40
   if debris_supraglacial eq 'y' then begin
      for i=0,n_elements(elev_bmb[0,*])-1 do printf,41,elev0[i],elev_debthick[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,41
      for i=0,n_elements(elev_bmb[0,*])-1 do printf,42,elev0[i],elev_debfrac[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,42
      for i=0,n_elements(elev_bmb[0,*])-1 do printf,43,elev0[i],elev_debfactor[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f10.5)' &  close,43
      for i=0,n_elements(elev_bmb[0,*])-1 do printf,44,elev0[i],elev_pondarea[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f11.6)' &  close,44
      if eval_mbelevsensitivity eq 'y' then begin
         for i=0,n_elements(elev_bmb[0,*])-1 do printf,44,elev0[i],elev_mbsens[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f9.4)'
         close,44
      endif
   endif
endif

; ------------------------
; write firn-ice temperature
if firnice_temperature eq 'y' then begin

   if firnice_write(0) eq 'y' then begin
      for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,45,elev0[i],elev_firnicetemp[0,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,45
      for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,46,elev0[i],elev_firnicetemp[1,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,46
      for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,47,elev0[i],elev_firnicetemp[2,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,47
      for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,48,elev0[i],elev_firnicetemp[3,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,48
   endif

   if firnice_write[1] eq 'y' then begin
      for i=0,n_elements(firnice_profile)-1 do close,51+i
   endif

endif

; *******************************************************
; plot of mass balance and profile for individual glacier!!!
; only activated for monthly resolution
; => procedure

if nb gt elev_range_p/step and plot eq 'y' and time_resolution eq 'monthly' then begin

xscm=20 & yscm=28.
PSCAL,'ps',xscm,yscm,name=dirres+dir_region+'/plots/'+sub_region+'/'+id[gg[g]]

device,/bold

; profile
pos=cm2norm(2,17.95,12.5,10,xscm,yscm)
plot,[0],[0],xra=[0,max(length)+max(length)*0.05],yra=[min(bed_elev)-10,max(elev)+10],/xsty,/ysty,xtit='Length (km)         ',ytit='Elevation (m a.s.l.)',pos=pos

oplot,length,gls[0,*],thi=3,col=4
for i=1,cnp-2 do oplot,length,gls[i,*],col=12
oplot,length,bed_elev,thi=4

if advance eq 'y' then area_ini=area_iniconst
ab=dblarr(2,fix(nb/10)) & n=0
for i=0,nb-11,10 do begin
	ab[0,n]=total(area_ini[i:i+9]) & ab[1,n]=total(area[i:i+9])
	n=n+1
     endfor
m=max(length)+max(length)*0.05 & sc=(m/4.)/max(ab[0,*]) & n=0 & e=indgen(nb)*10+e0
for i=0,fix(nb/10)-1 do begin
	polyfill,[m-ab[0,i]*sc,m,m,m-ab[0,i]*sc],[e(n),e(n),e(n+9),e(n+9)],col=15
    polyfill,[m-ab[1,i]*sc,m,m,m-ab[1,i]*sc],[e(n),e(n),e(n+9),e(n+9)],/line_fill,orient=45
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
plot,[0],[0],xra=[tran[0]-1,tran[1]+1],yra=[min([wb[0:ch-1],mb[0:ch-1],-smelt[0:ch-1],-flux_calv[0:ch-1]])-0.1,max([wb,mb,-smelt])+0.1],/xsty,/ysty,ytit='Mass balance (m w.e.)',pos=pos,/noerase

t=indgen(years)+tran[0]
ii=where(mb ne snoval)
oplot,!x.crange,[0,0],lines=2
oplot,t[ii],mb[ii],thi=6,col=2
oplot,t[ii],wb[ii],thi=6,col=4
oplot,t[ii],-smelt[ii],thi=2,col=11,lines=2
oplot,t[ii],-imelt[ii],thi=2,col=12,lines=3
if max(flux_calv) gt 0 then oplot,t[ii],-flux_calv[ii],thi=6,col=0

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
plot,[0],[0],xra=[tran[0]-1,tran[1]+1],yra=[-0.02,max([vnorm,anorm])+0.02],/xsty,/ysty,ytit='Norm. Area / Volume (-)',pos=pos,/noerase

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
;bnp=dblarr(nb,pst)+snoval & acp=bnp & mep=acp & rfp=bnp & elp=bnp & elap=dblarr(2,pst)
for j=0,pst-1 do begin
   for h=0,nb-1 do begin
      elp[h,j]=mean(gls[j*fp:((j+1)*fp-1),h])
      a=mely[(fp*outst*j):(fp*outst*(j+1)-1),h] & ii=where(a ne noval,ci)
      if ci gt fp*outst/2. then begin
         bnp[h,j]=mean(baly(ii+(fp*outst*j),h))
         acp[h,j]=mean(accy(ii+(fp*outst*j),h))
         mep[h,j]=mean(mely(ii+(fp*outst*j),h))
         rfp[h,j]=mean(refry(ii+(fp*outst*j),h))*10.
      endif
   endfor
   elap[0,j]=mean(ela[(fp*outst*j):(fp*outst*(j+1)-1)])
   elap[1,j]=mean(aar[(fp*outst*j):(fp*outst*(j+1)-1)])
endfor

pos=cm2norm(11.45,0.7,8.5,7.2,xscm,yscm)
plot,[0],[0],xra=[min(-mep(where(mep ne snoval)))-0.1,max(acp)+0.1],yra=[min(elp)-10,max(elp)+10.],/xsty,/ysty,ytit='Elevation (m a.s.l.)',xtit='Mass balance (m w.e. a!E-1!N)',pos=pos,/noerase

oplot,[0,0],!y.crange,lines=2

lin=[0,1,2,3,0]
for j=0,pst-1 do begin
	ii=where(bnp[*,j] ne snoval,ci)
	if ci gt 0 then begin
		oplot,bnp[ii,j],elp[ii,j],thi=4,col=0,lin=lin(j)
		oplot,-mep[ii,j],elp[ii,j],thi=4,col=2,lin=lin(j)
		oplot,acp[ii,j],elp[ii,j],thi=4,col=4,lin=lin(j)
		oplot,rfp[ii,j],elp[ii,j],thi=4,col=12,lin=lin(j)
	endif
	oplot,[x_s(0),x_s(0.2)],[elap[0,j],elap[0,j]],thi=4,lin=lin(j)
	xyouts,x_s(0.21),elap[0,j],'AAR '+string(elap[1,j],fo='(i2)')+'%',size=0.65
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

endif                           ; period long enough

endif    ; plot

; -----------------------
; write main file and meteo file
if volume0 gt 0 then vv=(volume1-volume0)*100/volume0 else vv=-100
if write_file eq 'y' then begin
   printf,6,id[gg[g]],latitudes[g],longitudes[g],total(area_iniconst),volume0,(area1-total(area_iniconst))*100/total(area_iniconst),vv,fo='(a,2f13.6,f10.3,f10.4,2f10.1)'
endif

count_glaciers=count_glaciers+1

endfor   ; loop over glaciers

endfor    ; grids y

endfor                          ; grids x


; ----------------------------------------
; ****************************************
; Optimization - OVERALL MASS BALANCE

if calibrate eq 'y' and calibrate_individual ne 'y' then begin

   close,3 & close,4
   
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
   fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
anz=file_lines(fn)-1 & s=strarr(1) & dat=dblarr(13,anz)
openr,1,fn & readf,1,s & readf,1,dat & close,1

; determine potential variability range of c_prec
if cal0 eq 0 then begin
   fc=2.-max([0,mean(dat[2,*])/4.]) & if fc lt 1.3 then fc=1.3
   cal_crit=0.01+0.02/(fc-1.)
endif

c_mb=total(dat[1,*]*dat[3,*])/total(dat[3,*])
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
if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0 &  da=dblarr(13+a,anz) & tt=strarr(1) & openr,1,fn & readf,1,tt & readf,1,da & close,1
flag_eval=da[12+a,*]
for i=0l,anz-1 do begin
   if calibration_phase eq '1' then begin
      if da[10+a,i] le c1_tolerance[0]+0.005 then flag_eval[i]=2
      if da[10+a,i] ge c1_tolerance[1]-0.005 then flag_eval[i]=3
   endif  else begin
      if meltmodel eq 1 then if da[8+a,i] eq c2_tolerance[0]+0.005 or da[8+a,i] eq c2_tolerance[1]-0.005 then flag_eval[i]=0
      if meltmodel eq 3 then if da[7+a,i] eq c2_tolerance[0]+0.005 or da[7+a,i] eq c2_tolerance[1]-0.005 then flag_eval[i]=0
   endelse
endfor
ii=where(flag_eval eq 1,ci)

if cphl eq 1 then begin
   caliphase_statistics[cphl-1]=ci*100/anz
   ii=where(flag_eval eq 2,ci) & ii=where(flag_eval eq 3,cj)
   if (ci+cj) gt 0 then caliphase_statistics[3]=ci*100/(ci+cj) else caliphase_statistics[3]=0
endif
if cphl eq 2 then caliphase_statistics[cphl-1]=ci*100/anz-caliphase_statistics[cphl-2]
if cphl eq 3 then caliphase_statistics[cphl-1]=ci*100/anz-caliphase_statistics[cphl-2]-caliphase_statistics[cphl-3]

endfor                 ; calibration phases

print, 'FINISHED region !!! '+region+' !!! '+clim_subregion
if reanalysis_direct ne 'y' then print, '    calculated with GCM: '+GCM_model[gcms]+' / '+GCM_rcp[rcps]+' / '+GCM_experiment[experis]
print, '    calculated with Re-analysis data set '+reanalysis

print, '**********'

if calibrate ne 'y' then begin
; output of total calving flux for calibration purposes
   print, '--------- TOTAL CALVING FLUX (Gt/a) (period average):'
   print, string(cali_calflux,fo='(f9.4)')
endif


if calibrate eq 'y' then begin
   if catchment_selection ne '' then cc='_'+catchment_selection else cc=''

   spawn,'cp '+dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+$
 '_'+sub_region+cc+'.dat '+dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+'_final_'+reanalysis+cc+'.dat'
   print, '   ...  Overwritten calibration file ...   '+sub_region

   fn=dircali+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
   anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0 &  da=dblarr(13+a,anz) & tt=strarr(1)
   openr,1,fn & readf,1,tt & readf,1,da & close,1
   ii=where(da[12+a,*] eq 0,ci) & print, '     Not calibrated: '+string(ci*100/anz,fo='(f5.2)')+'%'

   ; evaluate statistics for calibration phases
   print, '*** Calibration phase statistics:' & a=caliphase_statistics[0]
   c=caliphase_statistics[2] & d=caliphase_statistics[3]
   print, '1: '+string(a,fo='(i3)')+'% ('+string(d,fo='(i3)')+'% at lower);   2:'+string(caliphase_statistics[1],fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%'
   openw,2,dircali+dir_region+'/calibration/caliphase_statistics_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
   printf,2, '1: '+string(a,fo='(i3)')+'%;   2:'+string(caliphase_statistics[1],fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%' & close,2

   if repeat_calibration eq 'y' then begin
      rp_cali=rp_cali+1
      if toff_grid0 eq 'y' and rp_cali eq 1 then goto, repeat_cali 
      if toff_grid0 eq 'y' and rp_cali gt 1 and rp_cali le 4 and ci*100/anz gt 0.2 then goto, repeat_cali 
   endif
endif


; --------------------------------
; write file for volume below sea level
if calibrate ne 'y' and write_file eq 'y' then begin
   for i=0,years-1 do printf,7,tran[0]+i,vol_bz[i],fo='(i4,f12.2)'
   close,7
   close,33
endif

; --------------------------------
; copying time-stamped input.pro into the output folder
;  if calibrate ne 'y' then begin
; a=systime() & b=strsplit(a[0],' ',/extract) & c=systime(/julian) & d=strsplit(b(3),':',/extract)
; openw,4,dirres+dir_region+subpath+long_GCM+'input'+catchment_selection+'.pro'
; printf,4,'Date/time outputted: '+string(c,fo='(C(CYI04,CMOI02,CDI02))')+'_'+strjoin(d(0:1),'.')
; printf,4,'**********************' & printf,4,''
; for i=0l,n_elements(input_file_content)-1 do printf,4,input_file_content(i),fo='(a)'
; close,4
; endif

endfor                          ; regions

; --------------------------------

endfor                                  ; firnice_batch_loop


next_GCM:

endfor                          ; experiments

; zipping and removing files
if write_hypsometry_files eq 'y' then begin
   if meltmodel eq '1' then mtt='' else mtt='_m3'
   b='/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
   if reanalysis_direct eq 'y' then b='/PAST'
   ; zipping automatically,  but not for RGI-regions with subregions
   if region ne 'lowlatitudes' and region ne 'antarctic' and region ne 'northasia' then begin
      parent_dir = dirres+dir_region+b
      dir_name = 'hypsometry'
      zip_path = parent_dir+'/hypsometry.zip'
      
      ; Change to parent directory and zip only the directory name
      spawn, 'cd "'+parent_dir+'" && zip -r "hypsometry.zip" "'+dir_name+'"'
      spawn, 'rm -r "'+parent_dir+'/'+dir_name+'"'
   endif
endif

endfor                          ; RCPs

endfor                          ; GCMs

if plot eq 'y' or areaplot eq 'y' then device,/close_file


end
