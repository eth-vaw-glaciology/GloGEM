; *************************************************************
; zip_and_clean_hypsometry_files
;
; * Zip and clean up hypsometry files
; This procedure zips the hypsometry files and removes the unzipped directories to save space.
; This is done automatically for all regions except for RGI-regions with subregions, where
; *************************************************************

compile_opt idl2

if meltmodel eq '1' then mtt='' else mtt='_m3'
b='/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
if reanalysis_direct eq 'y' then b='/PAST'
; zipping automatically,  but not for RGI-regions with subregions
if region ne 'lowlatitudes' and region ne 'antarctic' and region ne 'northasia' then begin
    hypsometry_dir = dirres+'/'+time_resolution+'/'+dir_region+b+'/hypsometry'
    spawn, 'zip -r "'+hypsometry_dir+'.zip" "'+hypsometry_dir+'"'
    file_delete, hypsometry_dir, /recursive
endif
