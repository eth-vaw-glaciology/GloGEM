; *************************************************************
; check_reanalysis
;
; Validate that a reanalysis climate file exists and contains
; plausible temperature data.
;
; Opens the specified file, reads the 6-column data array, and checks
; whether the first temperature value exceeds -80 degrees C. Returns 1
; if the file is present and the temperature passes the sanity check,
; 0 otherwise.
; *************************************************************

FUNCTION check_reanalysis, file
if FILE_TEST(file) eq 0 then begin
   result = 0
endif else begin
   anz=file_lines(file)-3
   da=dblarr(6,anz)
   tt=strarr(3)
   openr,1,file & readf,1,tt & readf,1,da & close,1
   tempre = da(4,*)
   if tempre[0] gt -80 then begin
      result = 1
   endif else begin
      result = 0
   endelse
endelse
RETURN, result
END
