; *************************************************************
; Open calibration output files and write headers.
;
; Sets model run flags for calibration mode (no writing, no
; retreat, no plotting), opens the per-glacier calibration
; results file and the t_offset file, and optionally opens the
; glacier-specific overview file.
; *************************************************************

compile_opt idl2

plot='n' & tran=cran & write_file='n' & glacier_retreat='n'
if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
years=tran[1]-tran[0]+1
openw,3,dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
case meltmodel of
   '1': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    DDFsnow  DDFice   Cprec   T_off  Flag'
   '3': printf,3,'ID        Ba         Bw     Area     ELA   AAR    dBdz   Bt    C0       C1       a_ice    a_snow   Cprec  T_off  Flag'
endcase

if calibrate_glacierspecific eq 'y' then begin
   openw,50,dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+cc+'_overview_glspec.dat'
   printf,50,'ID      Y0    Y1    Target    Ba         Bw     Area     ELA   AAR    DDFsnow  DDFice   Cprec   T_off  Flag'
endif

openw,4,dircali+'/'+time_resolution+'/'+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
