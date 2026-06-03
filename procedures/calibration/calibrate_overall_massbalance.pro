; *************************************************************
; calibrate_overall_massbalance
;
; Overall regional mass balance calibration (optimization loop).
;
; Reads the per-glacier calibration results, computes the
; area-weighted regional mean mass balance, and adjusts c_prec
; until it matches the target within cal_crit tolerance.
; *************************************************************

compile_opt idl2

close,3 & close,4

if catchment_selection ne '' then cc='_'+catchment_selection else cc=''
fn=dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'
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
