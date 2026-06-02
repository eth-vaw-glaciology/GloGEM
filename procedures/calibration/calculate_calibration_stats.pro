; *************************************************************
; Calculate per-phase calibration statistics.
;
; Reads the calibration results file, evaluates flag values to
; determine what fraction of glaciers were successfully calibrated
; in each phase, and stores results in caliphase_statistics.
; *************************************************************

compile_opt idl2

if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
fn=dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
anz=file_lines(fn)-1 & if meltmodel eq '3' then a=2 else a=0
da=dblarr(13+a,anz) & tt=strarr(1) & openr,1,fn & readf,1,tt & readf,1,da & close,1
flag_eval=da[12+a,*]
for i=0l,anz-1 do begin
   if calibration_phase eq '1' then begin
      if da[10+a,i] le c1_tolerance[0]+0.005 then flag_eval[i]=2
      if da[10+a,i] ge c1_tolerance[1]-0.005 then flag_eval[i]=3
   endif else begin
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
