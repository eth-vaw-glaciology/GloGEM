PRO DEBRIS_MODEL, ye, nb, step, gl, noval, area, ar_gl, ela, bal, mb, elev, debris_expansion, debris_seed_bands, debris_seed_meters, debris_thickening, debris_frac, debris_thick, debris_thick_gradient, debris_ponddens, debris_pond_gradient, debris_ponddens_max, tran, survey_year, write_mb_elevationbands, debris_exp_gradient, debris_initialband, debris_red_factor, debris_thick0, elev_debthick, elev_debfrac, elev_debfactor, elev_pondarea, g , gg

    ;----------------------------------------------------------
    ; Compute the long-term geometric Equilibrium Line Altitude (ELA)
    ;----------------------------------------------------------
    if ye lt 10 then begin  ; If the model has been running for less than 10 years
        a = 0  ; Accumulator for glacier area fraction
        debris_seed_meters = 10.  ; Annual increase in elevation range where debris seeding is possible
        for i = 0, nb - 1 do begin
            a = a + area(i)  ; Sum up the glacier area
            medelev = i  ; Assign the current elevation band
            if a gt ar_gl * 0.45 then i = nb  ; Stop when accumulation area fraction reaches 45%
        endfor
    endif else begin  ; If model has run for at least 10 years
        a = mean(ela(ye - 10:ye - 1))  ; Compute decadal mean of ELA
        b = min(abs(elev - a), ind)  ; Find index of closest elevation to the computed mean ELA
        medelev = ind  ; Assign the median elevation
        debris_seed_meters = mean(mb(ye - 10:ye - 1)) * debris_seed_bands * (-1.)  ; Compute debris seeding factor based on past mass balance trends
    endelse

    ;----------------------------------------------------------
    ; Compute the time interval since the start of the dynamic model
    ;----------------------------------------------------------
    debris_time = 0  ; Initialize debris time
    if ye + tran(0) gt survey_year(gg(g)) then debris_time = ye + tran(0) - survey_year(gg(g))  ; Compute time elapsed since survey year

    ;----------------------------------------------------------
    ; Debris expansion logic
    ;----------------------------------------------------------
    if debris_expansion eq 'y' and debris_time gt 0 then begin  ; If debris expansion is enabled and enough time has passed
        count_seed_bands = 0  ; Counter for newly seeded debris bands
        for i = 0, medelev do begin  ; Iterate over elevation bands up to median ELA
            ; Case 1: Existing debris expands within the same elevation band
            if debris_frac(i) gt 0 and debris_frac(i) lt 1 then begin
                if bal(i) lt 0 and gl(i) ne noval then debris_frac(i) = debris_frac(i) + (debris_exp_gradient / 100.) * bal(i) * mean(mb(ye - min([ye, 10]):ye)) * max([debris_frac(i), 0.25])
                if debris_frac(i) gt 1 then debris_frac(i) = 1  ; Ensure fraction does not exceed 1
            endif
            ; Case 2: Debris seeding from neighboring bands
            if i gt 0 and i lt nb - 2 and count_seed_bands le debris_seed_meters / step then begin
                if debris_frac(i) eq 0 and max(debris_frac(i - 1:i + 1)) gt 0 then begin
                    debris_frac(i) = (debris_frac(i - 1) + debris_frac(i + 1)) / 2  ; Average debris fraction from neighboring bands
                    debris_thick(i) = debris_initialband  ; Set initial debris thickness
                    count_seed_bands = count_seed_bands + 1  ; Increment seeding counter
                endif
            endif
        endfor
    endif

    ;----------------------------------------------------------
    ; Pond expansion logic
    ;----------------------------------------------------------
    count_seed_bands = 0  ; Reset counter for pond expansion
    for i = 0, medelev do begin
        ; Case 1: Existing ponds expand within the same elevation band
        if debris_ponddens(i) gt 0 then begin
            if bal(i) lt 0 and gl(i) ne noval then debris_ponddens(i) = debris_ponddens(i) + (debris_pond_gradient / 100.) * bal(i) * mean(mb(ye - min([ye, 10]):ye)) * max([debris_ponddens(i), 0.02])
            if debris_ponddens(i) gt debris_ponddens_max then debris_ponddens(i) = debris_ponddens_max  ; Cap the maximum pond density
        endif
        ; Case 2: Seeding ponds from neighboring bands
        if i gt 0 and i lt nb - 2 and count_seed_bands le debris_seed_meters / step then begin
            if debris_ponddens(i) eq 0 and max(debris_ponddens(i - 1:i + 1)) gt 0 then begin
                debris_ponddens(i) = (debris_ponddens(i - 1) + debris_ponddens(i + 1)) / 2  ; Average neighboring pond density
                count_seed_bands = count_seed_bands + 1  ; Increment pond seeding counter
            endif
        endif
    endfor

    ;----------------------------------------------------------
    ; Debris thickening logic
    ;----------------------------------------------------------
    if debris_thickening eq 'y' and debris_time gt 0 then begin  ; If thickening is enabled and enough time has passed
        for i = 0, medelev do begin
            if debris_frac(i) gt 0 then debris_thick(i) = debris_thick(i) + (debris_thick_gradient / 100.) * bal(i) * mean(mb(ye - min([ye, 10]):ye)) * mean(debris_thick0(0:medelev))  ; Compute debris thickening
        endfor
    endif

    ;----------------------------------------------------------
    ; Prepare output
    ;----------------------------------------------------------
    if write_mb_elevationbands eq 'y' then begin  ; If output writing is enabled
        for i = 0, nb - 1 do begin
            if gl(i) ne noval then begin
                elev_debthick(ye, i) = debris_thick(i)  ; Store debris thickness
                elev_debfrac(ye, i) = debris_frac(i)  ; Store debris fraction
                elev_debfactor(ye, i) = debris_red_factor(i)  ; Store debris reduction factor
                elev_pondarea(ye, i) = debris_ponddens(i) * area(i)  ; Store pond area
            endif
        endfor
    endif

END