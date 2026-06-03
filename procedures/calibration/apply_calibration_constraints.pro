; *************************************************************
; apply_calibration_constraints
;
; Apply calibration parameter constraints and set flag.
;
; Clamps c_prec (phase 1) or DDFsnow/c1 (phase 2+) to their
; tolerance bounds. Sets flag=1 if the calibration converged
; within tolerance, flag=0 if a parameter was clamped.
; *************************************************************

compile_opt idl2

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
