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
!PATH = a + ':' + base_dir + '/procedures/read/:' + base_dir + '/procedures/write/:' + base_dir + '/procedures/processing/:' ; add path to procedures

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
   @procedures/read/read_geothermal.pro
   if firnice_batch eq 'y' then begin
      @procedures/read/read_firnicebatch.pro
   endif
endif

; ***************************************************
; ***************************************************
; ***************************************************

; START OF PROGRAM

; ***************************************************
; ***************************************************
; ***************************************************

tic

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

@procedures/read/read_regionbatch.pro

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
   if rp_cali eq 0 then SPAWN, 'rm -f ' + dircali+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+STRING(calperiod_ID,FORMAT='(I1)')+'_'+sub_region+cc+'.dat'
endif


; READING MONTHLY CLIMATE DATA (gridded format)
if time_resolution eq 'monthly' then begin

   if clim_subregion ne '' then ccl='_'+clim_subregion else ccl=''

  ; GCM --- CLIMATE FILE
   if reanalysis_direct ne 'y' then begin
      @procedures/read/read_gcmdata_monthly.pro
   endif

   @procedures/read/read_climatepast_monthly.pro

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

if regparams_readfromfile eq 'y' then begin
   @procedures/read/read_regionalparams.pro
endif

if catchment_selection ne '' then size_range=[0,100000.]

; -----------------------------
; read calibration data file (REGIONAL MEAN MASS BALANCE)
if calibrate eq 'y' then begin
   @procedures/calibration/read_calibration_targets.pro
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
   @procedures/calibration/determine_calibration_target.pro
endif

; ------------------------------
; generating folder structure
@procedures/initialise/setup_output_folders.pro

; --------------------------------------------------
; read parameter for individual regions from file

if read_parameters eq 'y' then begin
   @procedures/calibration/read_calibration_params.pro
endif

; including gridded T-offsets in calibration
if toff_grid eq 'y' and calibration_phase eq '1' and calibrate eq 'y' then begin
   @procedures/calibration/read_toffset_grid.pro
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
tti=strarr(anz) & id=tti & tt=dblarr(19,anz)
for i=0l,anz-1 do begin
   a=strsplit(st[i],' ',/extract) & tti[i]=a[0] & for j=0,18 do tt[j,i]=double(a[j+1])
endfor
hmed=tt[8,*] & hmin=tt[6,*] & survey_year=tt[18,*] & volume_ini=tt[3,*] & xy=tt[0:1,*] & a_gl=tt[2,*]
lat_gl=xy[1,*] & lon_gl=xy[0,*] & tt=a_gl
for i=0l,anz-1 do id[i]=strsplit(tti[i],';',/extract)

; checking whether survey-year/inventory-year is known and filling up with average if necessary
ii=where(survey_year ne noval,ci) & jj=where(survey_year eq noval,cj)
if ci gt 0 and cj gt 0 then survey_year[jj]=mean(survey_year[ii])

;if find_startyear eq 'y' then tran(0)=max([1980,min(survey_year)])
years=tran[1]-tran[0]+1

nout=fix(years/outst)+1
nouty=indgen(nout)*outst

; restrict number of evaluated glaciers to those with WGMS data
if valiglaciers_only eq 'y' then begin
   fn=dir+validation_dataset+dir_region+'.dat' & an=file_lines(fn)-1 & ss=strarr(2,an)
   for i=0l,anz-1 do begin
      a=double(id[i])-double(ss[1,*]) & if min(abs(a)) ne 0 then a_gl[i]=-1. ; setting area to negative, so that it will not be computed
   endfor
endif

; attribute dimensions of region to be calculated automatically
if lat0[0] eq 9999 then begin
   lat0=[min(lat_gl)-0.1,max(lat_gl)+0.1]
   lon0=[min(lon_gl)-0.1,max(lon_gl)+0.1]
endif

; ------------------------------
; open result files
if calibrate ne 'y' and write_file eq 'y' then begin
   @procedures/initialise/initialise_results_files.pro
endif

; selecting a specific subset of glaciers from a list (catchment) within one RGI region
if catchment_selection ne '' then begin
   @procedures/initialise/catchment_selection.pro

endif


; ******************************
; CALIBRATION LOOP - for overall calibration on entire region

cal0max=0
if calibrate eq 'y' and calibrate_individual ne 'y' then cal0max=20

for cal0=0,cal0max do begin

; settings for calibration file
if calibrate eq 'y' then begin
   @procedures/calibration/setup_calibration_files.pro
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
; meteo time series read from re-analysis data (past)

@procedures/read/read_climatepast_daily.pro

; ---------------------------------
; ---------------------------------
; meteo time series downscaled from GCMs or whatever (future)
if reanalysis_direct eq 'n' then begin

   @procedures/read/read_gcmdata_daily.pro
   @procedures/processing/downscale_gcmdata_daily.pro

endif

endif    ; daily time resolution

; ----- MONTHLY

if time_resolution eq 'monthly' then begin

   gmid=[mean(latitudes),mean(longitudes)]
   @procedures/processing/downscale_gcmdata_monthly.pro
   @procedures/processing/gradient_variability_monthly.pro

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

@procedures/read/read_hypsometryfile.pro

; find geothermal heat flux for glacier
if firnice_temperature eq 'y' then begin
   a=min(abs(latitudes[g]-fit_yy),indy) &  a=min(abs(longitudes[g]-fit_xx),indx)
   geothermal_flux=firnice_geotherm_flux[indx,indy]
endif

; define variables
area=da[3,*] & elev=da[1,*]+5 & thick=da[4,*] & width=da[5,*] & slope=da[7,*]
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
   for i=0,nb-1 do if width[i] gt (crit_ccorrdist/2.) then bed_elev_p[i]=bed_elev[i]-thick[i]*bedrock_parabolacorr*(crit_ccorrdist/2.)/width[i]
endif

ii=where(thick gt 0,ci) & if calibrate eq 'y' and ci eq 0 then thick=thick+1.
gl=dblarr(nb)+noval &  if ci gt 0 then gl[ii]=elev[ii]
length=dblarr(nb) & for i=0,nb-1 do length[i]=(max(da[6,*])-da[6,i])/1000.
thick_ini=thick & area_ini=area
area_iniconst=area   ; will not be affected by glacier advance!
volume0=total(thick_ini*area_ini)/1000.
tgs_cum=dblarr(nb)   ; array for storing local air temperatures

; ------------------------------
; prepare output for mass balance in elevation bands

if meltmodel eq '1' then mtt='' else mtt='_m3'
   @procedures/write/prepare_output_mb_in_bins.pro
endif

; prepare output of ice temperature model
if firnice_temperature eq 'y' then begin
   @procedures/write/prepare_output_firnicetemp.pro
endif

;prepare output for hypsometry-evolution file
if write_hypsometry_files eq 'y' then begin
   @procedures/write/prepare_output_hypsoevo.pro
endif 

; -----------------------------
; initialise some variables for the advance scheme
if advance eq 'y' and nb gt 3 then begin
   @procedures/initialise/initialise_advance_scheme_vars.pro
endif

; -------------------
; potential radiation time series
if meltmodel eq '3' then begin
   @procedures/processing/potential_solarradiation.pro
endif

; ---------------------
; read files for supraglacial debris

if debris_supraglacial eq 'y' then begin
   @procedures/read/read_supraglacialdebris.pro
endif

; ---------------------
; attribute specific parameter values
@procedures/calibration/apply_calibration_params.pro

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
for i=0,nb-1 do te_fit[i,*]=tt[i] & tl_fit=te_fit 


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
@procedures/processing/accumulation.pro

; ***********  melt (positive)
; two melt models are available: 1: temperature-index model, 3: simplified energy balance model (only for monthly time steps)
@procedures/processing/meltmodel.pro


; ***************************************
; ***********  refreezing (positive)

if refreezing_full eq 'y' then begin
@procedures/processing/refreezing_full.pro
endif else begin
   if refreezing_parametrised eq 'y' then begin
      @procedures/processing/refreezing_parametrised.pro
   endif else begin
      ; no refreezing
   endelse
endelse

; ***************************************
; ***********  firn/ice temperatures
; (separate workflow as the target and setup differs)

if firnice_temperature eq 'y' then begin
   @procedures/processing/firnice_temperature_model.pro
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
   @procedures/processing/store_output_variables.pro
endif



if ar_gl ne 0 then begin

   if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then wb[ye]=total(bal*area)/ar_gl
   if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then wb[ye]=total(bal*area)/ar_gl

   ; set bal-array to noval in case there is no glacier
   ii=where(gl eq noval,ci) & if ci gt 0 then bal[ii]=snoval

   if write_mb_elevationbands eq 'y' then begin
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then elev_bwb[ye,*]=bal
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then elev_bwb[ye,*]=bal
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_bmb[ye,*]=bal
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_bmb[ye,*]=bal
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_refr[ye,*]=refreeze*1000.
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_refr[ye,*]=refreeze*1000.
      if eval_mbelevsensitivity eq 'y' then begin
         if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]=bal
         if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]=bal
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

@procedures/processing/debris_model.pro


endif


; *******************************************
; *******************************************
; glacier retreat model

ii=where(balv ne noval,ci)
if ci gt 0 then dvol=total(balv[ii]) else dvol=0
jj=where(balv gt 0,cj) & if cj gt 0 then av=total(balv[jj]) else av=0
dens=0.9 & dvol=dvol/dens

; *******************************************
; CALVING MODEL
; -----------------------------
; volume loss due to frontal ablation

@procedures/processing/calving_model.pro

; *******************************************

if glacier_retreat eq 'y' then begin

   @procedures/processing/glacier_retreat.pro

endif                           ; glacier retreat


endfor    ; Loop over years


; ----------------------------------------
; ****************************************
; Optimization - SINGLE-GLACIER MASS BALANCE

if calibrate_individual eq 'y' then begin
   @procedures/calibration/calibrate_single_glacier.pro
endif

; setting back flags if glacier - IF NECESSARY
flag=0
if cal1 ge cal1max and calibrate eq 'y' then begin
   @procedures/calibration/apply_calibration_constraints.pro
endif

; ------------------------
; write hypsometry-evolution file
@procedures/write/write_hypsometry_evolution_file.pro

endif                           ; bedrock-file available?

endfor                          ; CALIBRATION 1 - single glacier mass balance

; ---------------------
; write calibration file
if calibrate eq 'y' then begin
   @procedures/write/write_calibration_results.pro
      
endif

cali_calflux=cali_calflux+mean(flux_calv)/1000.*ar_gl

; ---------------------
; Write results files
if write_file eq 'y' then begin
   ; Output for daily results
   if time_resolution eq 'daily' then begin
      @procedures/write/write_results_files_daily.pro
   endif else if time_resolution eq 'monthly' then begin
      @procedures/write/write_results_files_monthly.pro
   endif else begin
      PRINT, 'Error: temporal resolution is required.'
   endelse
endif

; ------------------------
; write elevation band file
fn=dir_data+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)
if write_mb_elevationbands eq 'y' and a[0] ne '' then begin
   @procedures/write/write_elevationband_file.pro
endif

; ------------------------
; write firn-ice temperature
if firnice_temperature eq 'y' then begin
   @procedures/write/write_firnicetemp.pro
endif

; *******************************************************
; plot of mass balance and profile for individual glacier!!!
; only activated for monthly resolution

if nb gt elev_range_p/step and plot eq 'y' and time_resolution eq 'monthly' then begin
   @procedures/write/plot_mb_and_profiles_per_glacier.pro
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

endfor                          ; calibration phases

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
if calibrate ne 'y' then begin
   @procedures/write/copy_input_to_output.pro
endif

endfor                          ; regions

; --------------------------------

endfor                                  ; firnice_batch_loop


next_GCM:

endfor                          ; experiments

; zipping and removing files
if write_hypsometry_files eq 'y' then begin
   @procedures/write/zip_and_clean_hypsometry_files.pro
endif

endfor                          ; RCPs

endfor                          ; GCMs

toc

if plot eq 'y' or areaplot eq 'y' then device,/close_file


end
