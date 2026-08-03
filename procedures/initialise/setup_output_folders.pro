; *************************************************************
; setup_output_folders
;
; Set up the output folder structure for the current model run.
;
; Determines the output subdirectory path (b): a timestamped
; folder for future runs, or /PAST... if tran[1] is in the past.
; Then creates all required subdirectories under dirres+dir_region.
; *************************************************************

compile_opt idl2

if meltmodel eq '1' then mtt='' else mtt='_m3'
if meltmodel eq '1' and calperiod_ID eq 8 then mtt='_debris'

a = systime()
b = strsplit(a, ' ', /extract)
date_str = strjoin(b, '_')
tt = double(b[4]) - 1

b = '/' + date_str + '/'

if tran[1] le tt then b='/PAST'+version_past+mtt

bd = dirres + time_resolution + '/' + dir_region

; Core folder structure
core_dirs = [ $
   bd, $
   bd + '/calibration', $
   bd + '/PAST' + version_past + mtt, $
   bd + '/PAST' + version_past + mtt + '/PAST_original', $
   bd + '/files' + mtt, $
   bd + '/files' + mtt + '/files_original', $
   bd + '/files' + mtt + '/files_original/SINGLE', $
   bd + '/files' + mtt + '/files_original/' + GCM_model[gcms], $
   bd + '/files' + mtt + '/files_original/' + GCM_model[gcms] + '/' + GCM_rcp[rcps] ]
file_mkdir, core_dirs
file_chmod, core_dirs, /a_read, /a_execute

; NetCDF folder structure (only created when write_netcdf is enabled)
if write_netcdf eq 'y' then begin
    netcdf_dirs = [ $
       bd + '/PAST' + version_past + mtt + '/PAST_netcdf', $
       bd + '/files' + mtt + '/files_netcdf', $
       bd + '/files' + mtt + '/files_netcdf/full' ]
    file_mkdir, netcdf_dirs
    file_chmod, netcdf_dirs, /a_read, /a_execute
    if netcdf_split eq 'y' then begin
        file_mkdir, bd + '/files' + mtt + '/files_netcdf/split'
        file_chmod, bd + '/files' + mtt + '/files_netcdf/split', /a_read, /a_execute
    endif
endif
