; *************************************************************
; write_results_files_daily
;
; Write annual and daily glacier mass balance output variables to
; per-variable .dat result files for the daily time-resolution run.
;
; Iterates over all active output variable names in outf_names,
; mapping each index to the corresponding model array (area, volume,
; mass balance, melt, accumulation, ELA, AAR, refreezing, discharge,
; and daily sub-annual series). Annual variables are written as a
; single row per glacier; daily variables are written year by year
; with the glacier ID, year, and area prepended to the daily values
; converted to millimetres.
; *************************************************************

compile_opt idl2

    ; Validate inputs
    IF N_ELEMENTS(outf_names) EQ 0 THEN MESSAGE, 'Error: outf_names is required.'
    IF time_resolution NE 'daily' THEN MESSAGE, 'Error: time_resolution must be "daily".'

    if time_resolution eq 'daily' then begin
        ii=where(outf_names ne '',ci)
        for i=0,ci-1 do begin
	        case ii[i] of
	        0: var = areas
	        1: var = volumes
	        2: var = mb
	        3: var = wb
	        4: var = smelt
	        5: var = imelt
	        6: var = accum
	        7: var = rain
	        8: var = ela
	        9: var = aar
	        10: var = refre
            11: var = hmin_g
            12: var = flux_calv
	        13: var = discharge
	        14: var = discharge_gl
	        15: var = accday
            16: var = rainday
            17: var = snowmeltday
            18: var = icemeltday
            19: var = refrday
            20: var = snowlineday/1000.
            endcase
            ; For the yearly values
            if ii[i] lt 13 then $
            printf,string(i+10,fo='(i2)'),id[gg[g]]+' '+string(var,fo='('+strcompress(string(years),/remove_all)+format_of[i]+')') $
            ; For the daily values
            else begin
            for k=0,years-1 do begin
                if ii[i] ne 14 then att=areas[0] else att=areas[k]
                printf,string(i+10,fo='(i2)'),id[gg[g]]+'  '+string(y[k],fo='(i4)')+'  '+string(att,fo='(f11.3)')+' '+string(var[0+k*365.:364.+k*365.]*1000.,fo='('+strcompress(365,/remove_all)+format_of[i]+')')
            endfor
            endelse
        endfor
    endif
