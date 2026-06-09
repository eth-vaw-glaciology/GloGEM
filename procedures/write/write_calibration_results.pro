; *************************************************************
; write_calibration_results
;
; Write glacier calibration file procedure
; *************************************************************

compile_opt idl2
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
