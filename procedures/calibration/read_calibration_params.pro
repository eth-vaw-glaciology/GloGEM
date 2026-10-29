; *************************************************************
; read_calibration_params
;
; Read per-glacier calibration parameters from file.
;
; Reads the calibration output file for the current region,
; calibration phase and melt model, and loads the glacier-specific
; DDF, c_prec, and t_offset values into cali_* arrays for use
; in the glacier loop.
; *************************************************************

compile_opt idl2

if calibration_phase eq '2' or calibration_phase eq '3' then begin 
   a=''
endif else begin 
   a='_final_'+reanalysis
endelse

if catchment_selection ne '' then begin
  cc = '_' + catchment_selection
  fn_test = dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+a+cc+'.dat'
  if ~file_test(fn_test) then cc = ''  ; no catchment-specific file — use region-wide calibration
endif else begin
  cc = ''
endelse

fn=dircali+'/'+time_resolution+'/'+dir_region+'/calibration/calibrate_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+a+cc+'.dat'
a=file_search(fn) & if a[0] eq '' then print,'!!! Parameter-File for '+sub_region+' is not available !!!'
cnc=12+double(meltmodel)
anz=file_lines(fn)-1 & da=dblarr(cnc,anz) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,da & close,1
; replace flagged values with regional mean
ii=where(da[cnc-1,*] eq 1,ci) & jj=where(da[cnc-1,*] eq 0,cj)
if ci gt 0 and cj gt 0 and calibration_phase eq '1' then for i=8,9+double(meltmodel) do for j=0,cj-1 do da[i,jj[j]]=mean(da[i,ii])
cali_id=da[0,*]
if meltmodel eq '1' then begin
   cali_ddfice=da[9,*] & cali_ddfsnow=da[8,*] & cali_cprec=da[10,*] & cali_toff=da[11,*]
endif
if meltmodel eq '3' then begin
   cali_c0=da[8,*] & cali_c1=da[9,*] & cali_a_ice=da[10,*] & cali_a_snow=da[11,*]
   cali_cprec=da[12,*] & cali_toff=da[13,*]
endif

; the air of the calibration (write_calibration_air.pro; no file = the 2 m air) must be the run's air,
; for the free air also its blend depth (line 2); its table (line 3) only gives a note
fn_ca = dircali+'/'+time_resolution+'/'+dir_region+'/calibration/air_temperature.txt'
cal_air = 'era5_2m' & cal_depth = '' & cal_table = ''
if file_test(fn_ca) then begin
   ca_lines = strarr(file_lines(fn_ca))
   openr, lun_ca, fn_ca, /get_lun & readf, lun_ca, ca_lines & free_lun, lun_ca
   ca_lines = strtrim(ca_lines, 2)
   cal_air = ca_lines[0]
   if n_elements(ca_lines) gt 1 then cal_depth = ca_lines[1]
   if n_elements(ca_lines) gt 2 then cal_table = ca_lines[2]
endif
run_air = air_temperature
if air_temperature eq 'freeair' then run_air = run_air + ', blend depth ' + $
   strtrim(string(freeair_blend_depth, format = '(f0.1)'), 2) + ' m'
if cal_air eq 'freeair' then cal_air = cal_air + ', blend depth ' + ((cal_depth eq '') ? 'not recorded' : cal_depth + ' m')
if cal_air ne run_air then begin
   if freeair_mixed_calibration ne 'y' then $
      message, 'air_temperature = ' + run_air + ', but the calibration in ' + dircali + ' was made with ' + $
               cal_air + " (freeair_mixed_calibration = 'y' to run it anyway)"
   print, '  [free air] note: air_temperature = ' + run_air + ' on a calibration made with ' + cal_air
endif
if air_temperature eq 'freeair' and cal_table ne '' and cal_table ne freeair_file then $
   print, '  [free air] note: the calibration used the table ' + cal_table
