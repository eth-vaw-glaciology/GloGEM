; *************************************************************
; assign_region_parameters
;
; Assign region name, dir_region, rgiregion and sub_region.
;
; For simple region loops (region_id_loop[0]=0) the name comes
; from region_n. For ID-based loops it is read from region_loop_data
; and calibration phase is reset for each new region.
; *************************************************************

compile_opt idl2

if region_id_loop[0] eq 0 then begin
  region=region_n[re]
  if sub_region eq '' then sub_region=region
  if clim_subregion ne '' then sub_region=clim_subregion
  if sub_region eq '' then sub_region=region_n[0]
endif else begin
  if calibrate eq 'y' then begin
    read_parameters='n' & calibration_phase='1'
  endif
  region=region_loop_data[4,re+region_id_loop[0]-1]
  dir_region=region_loop_data[2,re+region_id_loop[0]-1]
  rgiregion=region_loop_data[1,re+region_id_loop[0]-1]
  clim_subregion=region_loop_data[3,re+region_id_loop[0]-1]
  if clim_subregion eq 'xxx' then clim_subregion=''
  if clim_subregion ne '' then sub_region=clim_subregion else sub_region=''
  if sub_region eq '' then sub_region=region
endelse
