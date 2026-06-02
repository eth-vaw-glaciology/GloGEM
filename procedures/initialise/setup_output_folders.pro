; ***************************************************************
; Set up the output folder structure for the current model run.
;
; Determines the output subdirectory path (b): a timestamped
; folder for future runs, or /PAST... if tran[1] is in the past.
; Then creates all required subdirectories under dirres+dir_region.
; ***************************************************************

compile_opt idl2

if meltmodel eq '1' then mtt='' else mtt='_m3'
if meltmodel eq '1' and calperiod_ID eq 8 then mtt='_debris'

a = systime()
b = strsplit(a, ' ', /extract)
date_str = strjoin(b, '_')
tt = double(b[4]) - 1

b = '/' + date_str + '/'

if tran[1] le tt then b='/PAST'+version_past+mtt

SPAWN, 'mkdir -p ' + $
   dirres + dir_region + ' ' + $
   dirres + dir_region + '/calibration ' + $
   dirres + dir_region + '/files' + mtt + ' ' + $
   dirres + dir_region + '/PAST' + mtt + ' ' + $
   dirres + dir_region + '/files/SINGLE ' + $
   dirres + dir_region + '/files' + mtt + '/' + GCM_model[gcms] + ' ' + $
   dirres + dir_region + '/files' + mtt + '/' + GCM_model[gcms] + '/' + GCM_rcp[rcps]
SPAWN, 'chmod -R a+rx ' + dirres + dir_region
