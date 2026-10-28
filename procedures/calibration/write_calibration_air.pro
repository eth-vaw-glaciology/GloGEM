; *************************************************************
; write_calibration_air
;
; A calibration with air_temperature = 'freeair' writes calibration/air_temperature.txt; a 2 m
; calibration removes a stale one. No file = the 2 m air (read_calibration_params.pro).
; *************************************************************

compile_opt idl2

fn_ca = dircali + '/' + time_resolution + '/' + dir_region + '/calibration/air_temperature.txt'
if air_temperature eq 'freeair' then begin
  openw, lun_ca, fn_ca, /get_lun
  printf, lun_ca, air_temperature
  free_lun, lun_ca
endif else if file_test(fn_ca) then file_delete, fn_ca
