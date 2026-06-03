; *************************************************************
; glogem
;
; Orchestrate the GloGEM glacier mass balance model from model
; initialisation through to results output.
;
; Loads settings and user configuration, then drives nested loops over
; GCMs, emission scenarios, experiments, regions, and individual
; glaciers. Within each glacier the code reads climate and hypsometry
; data, applies bias correction and downscaling, runs the monthly or
; daily mass balance model (accumulation, melt, refreezing, glacier
; retreat, calving), and writes all selected output files to disk.
; *************************************************************

; MAIN GloGEM-Code (modular)

compile_opt idl2

; defining where procedures are found
CD, CURRENT=base_dir ; define base directory
a = !path            ; save current path
!PATH = a + ':' + base_dir + '/functions/:' + base_dir + '/procedures/read/:' + base_dir + '/procedures/write/:' + base_dir + '/procedures/processing/:' ; add path to procedures and functions

; load all model settings (and user overrides from ~/.glogem/config.pro)
@procedures/initialise/settings.pro

; read settings.pro as text for copying into the output folder
fn='procedures/initialise/settings.pro' & anz=file_lines(fn) & input_file_content=strarr(anz)
openr,1,fn & readf,1,input_file_content & close,1

; open log file to capture all console output
spawn, 'mkdir -p ' + base_dir + '/logs'
a=systime() & b=strsplit(a,' ',/extract)
log_timestamp=string(b[4],fo='(a4)')+'_'+string(b[1],fo='(a3)')+string(b[2],fo='(a2)')+'_'+strjoin(strsplit(b[3],':',/extract),'h')+'m'
log_file=base_dir+'/logs/glogem_'+log_timestamp+'.log'
journal, log_file

; Some information to show which model we are running
print, '  '
print, 'Welcome, happy you run GloGEM :)'
print, 'All the instructions and settings for this run are shown below and saved in a logfile'
print, 'Log file: '+log_file
print, '  '
if time_resolution eq 'daily' then begin
  print, 'We are running GloGEM daily'
endif else begin
  print, 'We are running GloGEM monthly'
endelse
if calibrate eq 'y' then begin
  print, 'Calibration started ...'
endif else begin
  print, 'Running for the future ...'
endelse
if catchment_selection ne '' then begin
   print, 'Catchment selection: '+catchment_selection
end
print, 'Reanalysis product selected: '+reanalysis
print, '  '

; READ batch-file for individual glaciers (icetemperature-batch)

if firnice_temperature eq 'y' then begin
  @procedures/read/read_geothermal.pro
  if firnice_batch eq 'y' then begin
    @procedures/read/read_firnicebatch.pro
  endif
endif

; === START OF PROGRAM

tic ; to check how long the program runs

; === LOOP OVER DIFFERENT GCMs

for gcms=first_GCM,n_elements(GCM_model)-1 do begin

  ; automatically setting end of modelling period for future runs
  if reanalysis_direct ne 'y' then tran[1]=2100
  if long_GCM ne '' then tran[1]=2300

  ; === LOOP OVER DIFFERENT RCPs/SSPs

  if rcp_batch[0] ne 0 then ne_GCM_rcp=rcp_batch[gcms] else ne_GCM_rcp=n_elements(GCM_rcp)

  for rcps=0,ne_GCM_rcp-1 do begin

    ; === LOOP OVER DIFFERENT Experiments

    if expe_batch[0] ne 0 then ne_GCM_experiment=expe_batch[gcms] else ne_GCM_experiment=n_elements(GCM_experiment)

    for experis=0,ne_GCM_experiment-1 do begin

      experi_short=strmid(GCM_experiment[experis],0,2)

      @procedures/read/read_regionbatch.pro

      ; === LOOP individual glaciers in different regions specified in batch
      ; file (icetemperature_batch.dat)

      if firnice_batch eq 'y' then firnice_batch_loop=nffbl else firnice_batch_loop=1

      for ffbl=0,firnice_batch_loop-1 do begin

        if firnice_batch eq 'y' then begin
         @procedures/initialise/setup_firnice_batch.pro
        endif

        ; === LOOP over different regions

        for re=0,region_id_loop[1]-region_id_loop[0] do begin

          rp_cali=0
          repeat_cali:
          DDFsnow=DDFsnow0 & DDFice=DDFice0

          @procedures/initialise/assign_region_parameters.pro

          count_glaciers=1
          cali_calflux=0

          ; Define start of mass balance year and clean stale t_offset
          @procedures/initialise/setup_massbalance_year.pro

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

          ; read regional parameter file

          if regparams_readfromfile eq 'y' then begin
            @procedures/read/read_regionalparams.pro
          endif

          if catchment_selection ne '' then size_range=[0,100000.]

          ; read calibration data file (REGIONAL MEAN MASS BALANCE)
          if calibrate eq 'y' then begin
            @procedures/calibration/read_calibration_targets.pro
          endif

          ; Loop over three calibration phases
          caliphase_statistics=dblarr(4)   ; info on top and low values for c_prec

          for cphl=1,double(caliphase_loop) do begin

            if cphl gt 1 then calibration_phase=string(cphl,fo='(i1)')
            if calibration_phase eq '2' or calibration_phase eq '3' then read_parameters='y'

            ; determine calibration periods and target
            if calibrate eq 'y' then begin
              @procedures/calibration/determine_calibration_target.pro
            endif

            ; generating folder structure
            @procedures/initialise/setup_output_folders.pro

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

            ; read batch file for all glaciers to be considered
            ; (taken from ice thickness data set)
            @procedures/read/read_glacier_inventory_batchfile.pro

            ; checking whether survey-year/inventory-year is known and filling up with average if necessary
            ii=where(survey_year ne noval,ci) & jj=where(survey_year eq noval,cj)
            if ci gt 0 and cj gt 0 then survey_year[jj]=mean(survey_year[ii])

            ; if find_startyear eq 'y' then tran(0)=max([1980,min(survey_year)])
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

            ; open result files
            if calibrate ne 'y' and write_file eq 'y' then begin
              @procedures/initialise/initialise_results_files.pro
            endif

            ; selecting a specific subset of glaciers from a list (catchment) within one RGI region
            if catchment_selection ne '' then begin
              @procedures/initialise/catchment_selection.pro

            endif

            ; === CALIBRATION LOOP - for overall calibration on entire region

            cal0max=0
            if calibrate eq 'y' and calibrate_individual ne 'y' then cal0max=20

            for cal0=0,cal0max do begin

              ; settings for calibration file
              if calibrate eq 'y' then begin
                @procedures/calibration/setup_calibration_files.pro
              endif

              vol_bz=dblarr(years)    ; define array for storing ice volume below sea level

              ; LOOPs over grids
              @procedures/initialise/setup_grid_loops.pro

              for gx=0,ngx-1 do begin

                for gy=0,ngy-1 do begin

                  if grid_run eq 'y' then begin
                    lon=[lon0[0]+gx*grid_step,lon0[0]+gx*grid_step+grid_step]
                    lat=[lat0[0]+gy*grid_step,lat0[0]+gy*grid_step+grid_step]
                  endif

                  ; select glacier subsample to be calculated
                  if lat[0] ne -99 and size_range[0] ne -99 then gg=where(xy[1,*] gt lat[0] and xy[1,*] lt lat[1] and xy[0,*] gt lon[0] and xy[0,*] lt lon[1] and a_gl gt size_range[0] and a_gl lt size_range[1] and volume_ini gt 0,cg)
                  if lat[0] ne -99 and size_range[0] eq -99 then gg=where(xy[1,*] gt lat[0] and xy[1,*] lt lat[1] and xy[0,*] gt lon[0] and xy[0,*] lt lon[1] and volume_ini gt 0,cg)
                  if lat[0] eq -99 and size_range[0] ne -99 then gg=where(a_gl gt size_range[0] and a_gl lt size_range[1] and volume_ini gt 0,cg)
                  if single_glacier ne '' then gg=where(id eq single_glacier and volume_ini gt 0,cg)

                  latitudes=lat_gl[gg] & longitudes=lon_gl[gg]

                  ; storage arrays
                  stor_im=dblarr(nout) & stor_dv=stor_im & stor_ar=stor_im & stor_vo=stor_im

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

                      ; meteo time series read from re-analysis data (past)

                      @procedures/read/read_climatepast_daily.pro

                      ; meteo time series downscaled from GCMs or whatever (future)
                      if reanalysis_direct eq 'n' then begin

                        @procedures/read/read_gcmdata_daily.pro
                        @procedures/processing/downscale_gcmdata_daily.pro

                      endif

                    endif    ; daily time resolution

                    ; --- MONTHLY

                    if time_resolution eq 'monthly' then begin

                      gmid=[mean(latitudes),mean(longitudes)]
                      @procedures/processing/downscale_gcmdata_monthly.pro
                      @procedures/processing/gradient_variability_monthly.pro

                    endif

                  endif                               ; is there a glacier in the cell?

                  ; === MAIN LOOP over all glaciers

                  for g=0l,cg-1 do begin

                    ; === CALIBRATION LOOP - for single-glacier calibration

                    cal1max=0
                    if calibrate_individual eq 'y' then begin
                      cal1max=15
                    endif

                    for cal1=0,cal1max do begin

                      ; read hypsometry-file
                      fn=dir_data+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)

                      if a[0] ne '' then begin

                        @procedures/read/read_hypsometryfile.pro

                        ; find geothermal heat flux for glacier
                        if firnice_temperature eq 'y' then begin
                          a=min(abs(latitudes[g]-fit_yy),indy) &  a=min(abs(longitudes[g]-fit_xx),indx)
                          geothermal_flux=firnice_geotherm_flux[indx,indy]
                        endif

                        ; define variables and process hypsometry
                        @procedures/processing/process_hypsometry_data.pro

                        ; prepare output for mass balance in elevation bands

                        if meltmodel eq '1' then mtt='' else mtt='_m3'
                        @procedures/write/prepare_output_mb_in_bins.pro
                      endif

                      ; prepare output of ice temperature model
                      if firnice_temperature eq 'y' then begin
                        @procedures/write/prepare_output_firnicetemp.pro
                      endif

                      ; prepare output for hypsometry-evolution file
                      if write_hypsometry_files eq 'y' then begin
                        @procedures/write/prepare_output_hypsoevo.pro
                      endif

                      ; initialise some variables for the advance scheme
                      if advance eq 'y' and nb gt 3 then begin
                        @procedures/initialise/initialise_advance_scheme_vars.pro
                      endif

                      ; potential radiation time series
                      if meltmodel eq '3' then begin
                        @procedures/processing/potential_solarradiation.pro
                      endif

                      ; read files for supraglacial debris

                      if debris_supraglacial eq 'y' then begin
                        @procedures/read/read_supraglacialdebris.pro
                      endif

                      ; attribute specific parameter values
                      @procedures/calibration/apply_calibration_params.pro

                      ; define arrays
                      gls=dblarr(nout,nb) & cnp=0
                      areas=dblarr(years) & volumes=areas
                      flux_calv=areas

                      sur=dblarr(nb) & sno=sur & snostor=sur
                      firn=sur & ff=where(elev gt hmed[gg[g]],ci) & if ci gt 0 then firn[ff]=1
                      baly=dblarr(years,nb)
                      ; initialising some output arrays
                      @procedures/initialise/initialise_output_arrays.pro

                      ; === MAIN LOOP over years

                      @procedures/initialise/initialise_firnicetemp_spinup.pro

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

                          ; loop over months
                          for m=st,en do begin

                            psg=dblarr(nb) & mel=psg & refr=psg & corrdis=psg & snowmel=mel & icemel=mel

                            ; correct snow storage array
                            if bal_month eq dd_thresholds[2] then if m eq 1 then sno=sno-snostor
                            if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sno=sno-snostor
                            jj=where(sno lt 0,cj) & if cj gt 0 then sno[jj]=0

                            ; Climate data extrapolation

                            if time_resolution eq 'monthly' then cdm=cmon else cdm=cday
                            if ccmon eq 0 then jjclim=where(cyear eq ye-1+tran[0] and cdm eq m)
                            tg=temp[jjclim[0]+ccmon]+(elev-hclim)*dtdz[m-1]+t_offset

                            ; === Mass balance model

                            ; --- accumulation
                            @procedures/processing/accumulation.pro

                            ; --- melt (positive)
                            ; two melt models are available: 1: temperature-index model, 3: simplified energy balance model (only for monthly time steps)
                            @procedures/processing/meltmodel.pro

                            ; --- refreezing (positive)

                            if refreezing_full eq 'y' then begin
                              @procedures/processing/refreezing_full.pro
                            endif else begin
                              if refreezing_parametrised eq 'y' then begin
                                @procedures/processing/refreezing_parametrised.pro
                              endif else begin
                                ; no refreezing
                              endelse
                            endelse

                            ; --- firn/ice temperatures
                            ; (separate workflow as the target and setup differs)

                            if firnice_temperature eq 'y' then begin
                              @procedures/processing/firnice_temperature_model.pro
                            endif    ; firn-ice temperature model

                            ; --- adapting snow reservoir
                            ; correcting for overestimated melt (disapperance of snow during month)
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

                            ; --- calculate catchment discharge
                            ; Melting and refreezing are the same inside and outside the
                            ; glacier if snow cover present; if no snow melting and refreezing
                            ; only refer to the ice surface => weighted average for specific discharge
                            @procedures/processing/calculate_catchment_discharge.pro

                            ; --- adapting surface type
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
                              @procedures/write/store_elevationband_massbalance.pro
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
                        @procedures/processing/finalize_annual_massbalance.pro

                        ; === DEBRIS MODEL
                        ; annually adapting debris cover extent and thickness
                        if debris_supraglacial eq 'y' and ar_gl gt 0 then begin

                          @procedures/processing/debris_model.pro

                        endif

                        ; glacier retreat model

                        ii=where(balv ne noval,ci)
                        if ci gt 0 then dvol=total(balv[ii]) else dvol=0
                        jj=where(balv gt 0,cj) & if cj gt 0 then av=total(balv[jj]) else av=0
                        dens=0.9 & dvol=dvol/dens

                        ; === CALVING MODEL
                        ; volume loss due to frontal ablation

                        @procedures/processing/calving_model.pro

                        if glacier_retreat eq 'y' then begin
                          @procedures/processing/glacier_retreat.pro
                        endif                           ; glacier retreat

                      endfor    ; Loop over years

                      ; === Optimization - SINGLE-GLACIER MASS BALANCE

                      if calibrate_individual eq 'y' then begin
                        @procedures/calibration/calibrate_single_glacier.pro
                      endif

                      ; setting back flags if glacier - IF NECESSARY
                      flag=0
                      if cal1 ge cal1max and calibrate eq 'y' then begin
                        @procedures/calibration/apply_calibration_constraints.pro
                      endif

                      ; write hypsometry-evolution file
                      @procedures/write/write_hypsometry_evolution_file.pro

                    endif                           ; bedrock-file available?

                  endfor                          ; CALIBRATION 1 - single glacier mass balance

                  ; write calibration file
                  if calibrate eq 'y' then begin
                    @procedures/calibration/write_calibration_results.pro
                  endif

                  cali_calflux=cali_calflux+mean(flux_calv)/1000.*ar_gl

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

                  ; write elevation band file
                  fn=dir_data+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)
                  if write_mb_elevationbands eq 'y' and a[0] ne '' then begin
                    @procedures/write/write_elevationband_file.pro
                  endif

                  ; write firn-ice temperature
                  if firnice_temperature eq 'y' then begin
                    @procedures/write/write_firnicetemp_file.pro
                  endif

                  ; plot of mass balance and profile for individual glacier!!!
                  ; only activated for monthly resolution

                  if nb gt elev_range_p/step and plot eq 'y' and time_resolution eq 'monthly' then begin
                    @procedures/write/plot_mb_and_profiles_per_glacier.pro
                  endif    ; plot

                  ; write main file and meteo file
                  if volume0 gt 0 then vv=(volume1-volume0)*100/volume0 else vv=-100
                  if write_file eq 'y' then begin
                    printf,6,id[gg[g]],latitudes[g],longitudes[g],total(area_iniconst),volume0,(area1-total(area_iniconst))*100/total(area_iniconst),vv,fo='(a,2f13.6,f10.3,f10.4,2f10.1)'
                  endif

                  count_glaciers=count_glaciers+1

                endfor   ; loop over glaciers

              endfor   ; grids y

            endfor   ; grids x

            ; === Optimization - OVERALL MASS BALANCE

            if calibrate eq 'y' and calibrate_individual ne 'y' then begin
              @procedures/calibration/calibrate_overall_massbalance.pro
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
          @procedures/calibration/calculate_calibration_stats.pro

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

        ; print statistics for calibration phases and write file for calibration phase statistics
        if calibrate eq 'y' then begin
          @procedures/calibration/write_calibration_phase_statistics.pro
        endif

        ; write file for volume below sea level
        if calibrate ne 'y' and write_file eq 'y' then begin
          @procedures/write/write_volume_below_sea_level.pro
        endif

        ; copying time-stamped settings.pro into the output folder
        if calibrate ne 'y' then begin
          @procedures/write/copy_input_to_output.pro
        endif

      endfor   ; regions

    endfor   ; firnice_batch_loop

    next_GCM:

  endfor   ; experiments

  ; zipping and removing files
  if write_hypsometry_files eq 'y' then begin
    @procedures/write/zip_and_clean_hypsometry_files.pro
  endif

endfor   ; RCPs

endfor                          ; GCMs

toc ; print runtime

if plot eq 'y' or areaplot eq 'y' then device,/close_file

journal  ; close log file

end
