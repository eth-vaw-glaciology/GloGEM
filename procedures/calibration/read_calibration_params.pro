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
   cc='_'+catchment_selection 
endif else begin 
   cc=''
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
