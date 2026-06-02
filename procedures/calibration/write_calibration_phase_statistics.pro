; ***************************************
; Write and print calibration phase statistics
; ***************************************

compile_opt idl2
if catchment_selection ne '' then cc='_'+catchment_selection else cc=''

spawn,'cp '+dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+$
'_'+sub_region+cc+'.dat '+dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+'_final_'+reanalysis+cc+'.dat'
print, '   ...  Overwritten calibration file ...   '+sub_region

fn=dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0 &  da=dblarr(13+a,anz) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,da & close,1
ii=where(da[12+a,*] eq 0,ci) & print, '     Not calibrated: '+string(ci*100/anz,fo='(f5.2)')+'%'

; evaluate statistics for calibration phases
print, '*** Calibration phase statistics:' & a=caliphase_statistics[0]
c=caliphase_statistics[2] & d=caliphase_statistics[3]
print, '1: '+string(a,fo='(i3)')+'% ('+string(d,fo='(i3)')+'% at lower);   2:'+string(caliphase_statistics[1],fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%'
openw,2,dircali+'/'+time_resolution+'/'+dir_region+'/calibration/caliphase_statistics_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
printf,2, '1: '+string(a,fo='(i3)')+'%;   2:'+string(caliphase_statistics[1],fo='(i3)')+'%;   3:'+string(c,fo='(i3)')+'%' & close,2

if repeat_calibration eq 'y' then begin
    rp_cali=rp_cali+1
    if toff_grid0 eq 'y' and rp_cali eq 1 then goto, repeat_cali 
    if toff_grid0 eq 'y' and rp_cali gt 1 and rp_cali le 4 and ci*100/anz gt 0.2 then goto, repeat_cali 
endif