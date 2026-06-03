; *************************************************************
; determine_calibration_target
;
; Determine calibration period and mass balance target.
;
; For regional calibration: looks up target MB (bn), uncertainty
; (uc), and calibration period (cran) from the loaded calibration
; data matching the current region and calperiod_ID.
; For glacier-specific calibration: assigns all geodetic MB values
; as targets and sets cran from the full period range.
; *************************************************************

compile_opt idl2

if calibrate_glacierspecific eq 'n' then begin
   ii=where(calimb_regname eq dir_region and calimb_sregname eq sub_region and calimb_idname eq calperiod_ID,ci)
   if ci eq 0 then print, '!!! No calibration data available for this region / period !!!'
   target=calimb_bn[ii[0]] & target_uc=calimb_uc[ii[0]] & cran=[calimb_p0[ii[0]],calimb_p1[ii[0]]]
endif else begin
   target_spec=calimb_bn & cran=[min(calimb_p0),max(calimb_p1)]
endelse
