; *************************************************************
; read_calibration_targets
;
; Read calibration targets (mass balance data).
;
; For regional calibration: reads calibration.dat with regional
; mean mass balance targets. For glacier-specific calibration:
; reads geodetic mass balance data via read_geodeticdata.pro.
; *************************************************************

compile_opt idl2

if calibrate_glacierspecific eq 'n' then begin

   fn=dir+'calibration.dat' & anz=file_lines(fn)-1
   openr,1,fn & readf,1,s & readf,1,tt & close,1
   calimb_regname=strarr(anz) & calimb_sregname=strarr(anz) & calimb_outline=strarr(anz)
   calimb_idname=dblarr(anz) & calimb_p0=dblarr(anz) & calimb_p1=dblarr(anz) & calimb_bn=dblarr(anz) & calimb_uc=dblarr(anz)
   for i=0l,anz-1 do begin
      a=strsplit(tt[i],' ',/extract) & calimb_regname[i]=a[0] & calimb_sregname[i]=a[1] & calimb_outline[i]=a[2]
      calimb_idname[i]=double(a[4]) & calimb_p0[i]=double(a[5]) & calimb_p1[i]=double(a[6]) & calimb_bn[i]=double(a[7]) & calimb_uc[i]=double(a[8])
   endfor

endif else begin

   @procedures/read/read_geodeticdata.pro

endelse
