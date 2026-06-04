; *************************************************************
; prepare_output_firnicetemp
;
; Prepare output files for firnice temperature
; This procedure prepares the output files for firnice temperature. It creates the necessary directories and files,
; and writes the headers for the output data. The actual data will be written in a later step.
; *************************************************************

compile_opt idl2

if firnice_write[0] eq 'y' then begin
    c=findfile(dirres+dir_region+b+'/firnice_temperature')
    if c[0] eq '' then begin
        spawn,'mkdir '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature'
    endif
    openw,45,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/temp_1m_'+id[gg[g]]+'.dat'
    a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
    printf,45,'Elev  '+a 
    elev_firnicetemp=dblarr(4,years,nb)+snoval ; all layers

    openw,46,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/temp_10m_'+id[gg[g]]+'.dat'
    printf,46,'Elev  '+a 

    openw,47,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/temp_50m_'+id[gg[g]]+'.dat'
    printf,47,'Elev  '+a 

    openw,48,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/temp_bedrock_'+id[gg[g]]+'.dat'
    printf,48,'Elev  '+a 
endif
if enable_advection eq 'y' AND advection_write eq 'y' then begin
    c=findfile(dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature')
    IF c[0] EQ '' THEN BEGIN
        spawn,'mkdir '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature' 
        spawn,'chmod a+rx '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature'
    ENDIF

    openw,70,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/adv_horizontal_'+id[gg[g]]+'.dat'
    a='' & FOR i=0,years-1 DO a=a+string(i+tran[0],fo='(i4)')+'  '
    printf,70,'Elev  '+a
    elev_adv_horiz=dblarr(years,nb)+snoval

    openw,71,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/adv_vertical_'+id[gg[g]]+'.dat'
    printf,71,'Elev  '+a
    elev_adv_vert=dblarr(years,nb)+snoval
endif

if firnice_write[1] eq 'y' then begin
    c=findfile(dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature')
    if c[0] eq '' then begin
        spawn,'mkdir '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature' & spawn,'chmod a+rx '+dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature'
    endif

    ; determining elevations to be outputted
    firnice_profile_ind=dblarr(2,n_elements(firnice_profile)) ; index / abs elev.
    if firnice_profile[0] lt 1 then begin  ; relative elev
        for i=0,n_elements(firnice_profile)-1 do begin
        firnice_profile_ind[0,i]=fix(firnice_profile[i]*nb) & firnice_profile_ind[1,i]=elev0[firnice_profile_ind[0,i]]
        endfor
    endif else begin  ; abs elev
        for i=0,n_elements(firnice_profile)-1 do begin
        a=min(abs(elev0-firnice_profile[i]),ind)
        firnice_profile_ind[0,i]=ind & firnice_profile_ind[1,i]=elev0[firnice_profile_ind[0,i]]
        endfor
    endelse

    for j=0,n_elements(firnice_profile)-1 do begin
        openw,51+j,dirres+'/'+time_resolution+'/'+dir_region+b+'/firnice_temperature/temp_ID'+firnice_profile_ID[j]+'_'+id[gg[g]]+'.dat'
        printf,51+j,'Point elevation  '+string(firnice_profile_ind[1,0],fo='(i4)')+' masl: Depth in m'
        a='' & for i=1,total(fit_layers)-1 do a=a+string(fit_dz[1,i],fo='(i4)')+'  '
        printf,51+j,'Year  Month '+a 
    endfor
endif
