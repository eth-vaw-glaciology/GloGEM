; *************************************************************
; read_toffset_grid
;
; Read gridded T-offset data for calibration phase 1.
; Loads the spatially distributed temperature offset file and
; averages values per grid cell into toff_data. If the file
; does not exist, toff_grid is set to 'n' to disable this feature.
; *************************************************************

compile_opt idl2

if catchment_selection ne '' then begin
   cc='_'+catchment_selection
endif else begin
   cc=''
endelse

; Check if calibration is enabled
if calibrate eq 'y' then begin
   ; Check if a catchment selection is specified
   if catchment_selection ne '' then begin
      cc = '_' + catchment_selection
   endif else begin
      cc = ''
   endelse
   ; Check if rp_cali is 0
   if rp_cali eq 0 then begin
      ; Construct the file path
      file = dircali + time_resolution + '/' + dir_region + '/calibration/toff_m' + meltmodel + '_cID' + string(calperiod_ID, fo='(i1)') + '_' + sub_region + cc + '.dat'
      ; Check if the file exists before attempting to delete it
      if file_test(file) then begin
         file_delete, file
      endif
   endif
endif

; Filename
fn=dircali+'/'+time_resolution+'/'+dir_region+'/calibration/toff_m'+meltmodel+'_cID'+string(calperiod_ID,fo='(i1)')+'_'+sub_region+cc+'.dat'

a=findfile(fn)
if a[0] ne '' then begin
   anz=file_lines(fn) & da=dblarr(5,anz) & openr,1,fn & readf,1,da & close,1
   toff_data=dblarr(anz) & cali_id_toff=da[0,*]
   for i=1,max(da[3,*]) do begin
      for j=1,max(da[4,*]) do begin
         ii=where(da[3,*] eq i and da[4,*] eq j,ci) & if ci gt 0 then toff_data[ii]=mean(da[1,ii])
      endfor
   endfor
endif else toff_grid='n'
