; *************************************************************
; copy_input_to_output
;
; Copy a time-stamped settings.pro into the output folder so
; each model run has a record of the settings used.
; *************************************************************

compile_opt idl2

a=systime() & b=strsplit(a[0],' ',/extract) & c=systime(/julian) & d=strsplit(b[3],':',/extract)
openw,4,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+'settings'+catchment_selection+'.pro'
printf,4,'Date/time outputted: '+string(c,fo='(C(CYI04,CMOI02,CDI02))')+'_'+strjoin(d[0:1],'.')
printf,4,'**********************' & printf,4,''
for i=0l,n_elements(input_file_content)-1 do printf,4,input_file_content[i],fo='(a)'
close,4

; and the run's own config (GLOGEM_CONFIG or config.pro): its overrides are not in settings.pro
if n_elements(user_config) gt 0 then if file_test(user_config) then begin
  ncfg=file_lines(user_config)
  if ncfg gt 0 then begin
    cfg_content=strarr(ncfg)
    openr,lun_cfg,user_config,/get_lun & readf,lun_cfg,cfg_content & free_lun,lun_cfg
    openw,lun_cfg,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+'config'+catchment_selection+'.pro',/get_lun
    printf,lun_cfg,'; copy of '+user_config
    for i=0l,ncfg-1 do printf,lun_cfg,cfg_content[i],fo='(a)'
    free_lun,lun_cfg
  endif
endif
