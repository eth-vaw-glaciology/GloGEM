; *************************************************************
; prepare_output_firnicetemp
;
; Prepare output files for firnice temperature
; This procedure prepares the output files for firnice temperature. It creates the necessary directories and files,
; and writes the headers for the output data. The actual data will be written in a later step.
; *************************************************************

compile_opt idl2

; Build the firnice_temperature subdirectory path once
firnice_dir = dirres + '/' + time_resolution + '/' + dir_region + b + '/firnice_temperature'

; Create directory — mkdir -p is silent and idempotent (no error if it already exists)
spawn, 'mkdir -p ' + firnice_dir
spawn, 'chmod a+rx ' + firnice_dir

if firnice_write[0] eq 'y' then begin
    close,45 & openw,45, firnice_dir + '/temp_1m_'      + id[gg[g]] + '.dat'
    a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
    printf,45,'Elev  '+a
    elev_firnicetemp=dblarr(4,years,nb)+snoval ; all layers

    close,46 & openw,46, firnice_dir + '/temp_10m_'     + id[gg[g]] + '.dat'
    printf,46,'Elev  '+a

    close,47 & openw,47, firnice_dir + '/temp_50m_'     + id[gg[g]] + '.dat'
    printf,47,'Elev  '+a

    close,48 & openw,48, firnice_dir + '/temp_bedrock_' + id[gg[g]] + '.dat'
    printf,48,'Elev  '+a
endif

if enable_advection eq 'y' AND advection_write eq 'y' then begin
    close,70 & openw,70, firnice_dir + '/adv_horizontal_' + id[gg[g]] + '.dat'
    a='' & FOR i=0,years-1 DO a=a+string(i+tran[0],fo='(i4)')+'  '
    printf,70,'Elev  '+a
    elev_adv_horiz=dblarr(years,nb)+snoval

    close,71 & openw,71, firnice_dir + '/adv_vertical_' + id[gg[g]] + '.dat'
    printf,71,'Elev  '+a
    elev_adv_vert=dblarr(years,nb)+snoval
endif

if firnice_write[1] eq 'y' then begin
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
        close,51+j & openw,51+j, firnice_dir + '/temp_ID' + firnice_profile_ID[j] + '_' + id[gg[g]] + '.dat'
        printf,51+j,'Point elevation  '+string(firnice_profile_ind[1,0],fo='(i4)')+' masl: Depth in m'
        a='' & for i=1,total(fit_layers)-1 do a=a+string(fit_dz[1,i],fo='(i4)')+'  '
        printf,51+j,'Year  Month '+a
    endfor
endif
