; *************************************************************
; prepare_output_firnicetemp
;
; Prepare output files for firnice temperature
; This procedure prepares the output files for firnice temperature. It creates the necessary directories and files,
; and writes the headers for the output data. The actual data will be written in a later step.
; *************************************************************

compile_opt idl2

; Build firnice_dir from run-type flags — never use scratch variable b, which is
; overwritten to a numeric array between glaciers during the mass-balance year loop.
if single_glacier ne '' then begin
    firnice_subpath = '/files/files_original/SINGLE'
endif else if reanalysis_direct eq 'y' then begin
    firnice_subpath = '/PAST' + version_past + mtt
endif else begin
    firnice_subpath = '/files' + mtt + '/' + GCM_model[gcms] + '/' + GCM_rcp[rcps]
endelse
firnice_dir = dirres + time_resolution + '/' + dir_region + firnice_subpath + '/firnice_temperature'

; Create directory — file_mkdir is silent and idempotent (no error if it already exists)
file_mkdir, firnice_dir
file_chmod, firnice_dir, /a_read, /a_execute

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

if firnice_write[2] eq 'y' then begin
    ; Full englacial temperature field: T for every layer of every band, every year.
    ; The four temp_*m files only sample 4 fixed depths and store the annual MAXIMUM;
    ; this file stores the annual MEAN of the whole column, which is what a
    ; cross-section figure needs. Accumulated monthly, averaged at write time.
    close,90 & openw,90, firnice_dir + '/temp_field_' + id[gg[g]] + '.dat'
    printf,90,'# full englacial temperature field, annual mean over months'
    printf,90,'# glacier ' + id[gg[g]] + '  bands ' + string(nb,fo='(i0)') + $
              '  years ' + string(tran[0],fo='(i0)') + '-' + string(tran[1],fo='(i0)')
    a='' & for i=1,total(fit_layers) do a=a+string(fit_dz[1,i-1],fo='(i6)')+'  '
    printf,90,'# columns: year  elev_masl  thick_m  n_resolved  then T at depths [m]:'
    printf,90,'#'+a
    ; sum over months and a per-band month counter, both reset implicitly by year index
    fit_field_sum = dblarr(years, nb, total(fit_layers)) + 0d0
    fit_field_cnt = dblarr(years, nb) + 0d0
    fit_field_tt  = dblarr(years, nb) + snoval   ; resolved layers (bed index) per band
    fit_field_th  = dblarr(years, nb) + snoval   ; band ice thickness [m]

    ; Companion velocity field -- the u and w that drive the advection term. Only
    ; meaningful when advection is on, so the file is only opened in that case.
    if enable_advection eq 'y' then begin
        close,91 & openw,91, firnice_dir + '/vel_field_' + id[gg[g]] + '.dat'
        printf,91,'# advection velocity field, annual mean over months, m/yr'
        printf,91,'# u = horizontal (Nye profile, downglacier positive)'
        printf,91,'# w = vertical (kinematic, DOWNWARD positive, zero at the bed)'
        printf,91,'# columns: year  elev_masl  n_resolved  u[0..' + $
                  string(total(fit_layers)-1,fo='(i0)') + ']  w[0..' + $
                  string(total(fit_layers)-1,fo='(i0)') + ']  at depths [m]:'
        printf,91,'#'+a
        fit_u_sum   = dblarr(years, nb, total(fit_layers)) + 0d0
        fit_w_sum   = dblarr(years, nb, total(fit_layers)) + 0d0
        fit_vel_cnt = dblarr(years, nb) + 0d0
        fit_vel_tt  = dblarr(years, nb) + snoval
    endif
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
        ; Match against glacierized bands only (gl ne noval, set in process_hypsometry_
        ; data.pro from thick gt 0). The hypsometry array frequently has zero-area/zero-
        ; thickness "gap" bands interleaved between real ice bands (digitization artifacts)
        ; or trailing above the highest real ice band near a summit -- a plain nearest-
        ; elevation search over the FULL band array can land on one of these, silently
        ; producing a header-only output file with zero data rows for that profile point
        ; (confirmed for two real glenglat boreholes whose requested elevation happened to
        ; be numerically closest to such a gap band, even though real ice existed one band
        ; away).
        gz=where(gl ne noval,cgz)
        for i=0,n_elements(firnice_profile)-1 do begin
        if cgz gt 0 then begin
            a=min(abs(elev0[gz]-firnice_profile[i]),ind) & ind=gz[ind]
        endif else begin
            a=min(abs(elev0-firnice_profile[i]),ind)
        endelse
        firnice_profile_ind[0,i]=ind & firnice_profile_ind[1,i]=elev0[firnice_profile_ind[0,i]]
        endfor
    endelse

    ; Borehole profile files get dynamically allocated logical units. No fixed base is
    ; safe: the original 51+j ran into adv_vertical's unit 71 at 21 profiles -- exactly
    ; what the glenglat lookup holds for Gornergletscher (01225) -- and 10+j collides with
    ; the main results files, which initialise_results_files.pro opens across 10..10+N-1
    ; (up to unit 30 with full_output='y'). get_lun allocates from 100 upward, clear of
    ; every hard-coded unit in the model, and imposes no ceiling on the profile count.
    n_prof = n_elements(firnice_profile)
    fit_prof_lun = lonarr(n_prof)
    for j=0,n_prof-1 do begin
        get_lun, _plun & fit_prof_lun[j] = _plun
        openw,fit_prof_lun[j], firnice_dir + '/temp_ID' + firnice_profile_ID[j] + '_' + id[gg[g]] + '.dat'
        printf,fit_prof_lun[j],'Point elevation  '+string(firnice_profile_ind[1,j],fo='(i4)')+' masl: Depth in m'
        a='' & for i=1,total(fit_layers)-1 do a=a+string(fit_dz[1,i],fo='(i4)')+'  '
        printf,fit_prof_lun[j],'Year  Month '+a
    endfor
endif
