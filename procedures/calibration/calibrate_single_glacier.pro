; *************************************************************
; calibrate_single_glacier
;
; Single-glacier mass balance calibration (optimization loop)
;
; Adjusts c_prec (phase 1), DDFsnow/DDFice or c1 (phase 2),
; or t_offset (phase 3) until the modelled mass balance matches
; the calibration target within cal_crit tolerance.
; *************************************************************

compile_opt idl2

; determine potential variability range
if cal1 eq 0 then begin
   fc=2.-max([0,mean(wb)/4.]) & if fc lt 1.3 then fc=1.3
   ; for calperiod_ID=5 (Hugonnet, regional) use uncertainty in regional mb
   if calperiod_ID eq 5 then begin
      cal_crit=target_uc
   endif else begin
      cal_crit=0.02*double(calibration_phase)+(0.04)/(fc-1.)
   endelse
endif

; account for calving fluxes during the calibration period
c_mb=mean(mb)-min([2,mean(flux_calv)])
if calibrate_glacierspecific eq 'y' then begin
   ccj=where(calimb_gid eq id[gg[g]],ci)
   if ci eq 0 then ccj=n_elements(target_spec)-1
   if ci gt 1 then target=mean(target_spec[ccj]) $
     else target=target_spec[ccj[0]]
   n=indgen(years)+tran[0]
   pp=where(n gt calimb_p0[ccj[0]] and n le calimb_p1[ccj[0]])
   c_mb=mean(mb[pp])-min([2,mean(flux_calv[pp])])
endif

if abs(target-c_mb) gt cal_crit then begin

   if cal1 eq 0 then c_mbst=0

   ; calibration phase 1 and 2
   if calibration_phase ne '3' then begin

      if calibration_phase eq '1' then calvar=c_prec else calvar=ddfsnow
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

   ; calibration phase 3
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
