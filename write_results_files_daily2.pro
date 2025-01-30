;-----------------------------------------------------------
; Created by: 
;   Lander Van Tricht
; Date of last modification:
;   24/01/2025
; Name: 
;   WRITE_RESULTS_FILES_DAILY
; Purpose: 
;   Writes model results for all desired output variables into .dat files.
; Inputs: 
;   outf_names      - Array of output filenames
;   ANNUAL (The values below are stored with annual values)
;   areas           - Array of glacier areas
;   volumes         - Array of glacier volumes
;   mb              - Array of mass balance values
;   wb              - Array of winter balance values
;   smelt           - Array of snow melt 
;   imelt           - Array of ice melt 
;   accum           - Array of accumulation data
;   rain            - Array of rain data
;   ela             - Array of equilibrium line altitude data
;   aar             - Array of accumulation area ratio data
;   refre           - Array of refreezing data
;   hmin_g          - Array of glacier minimum height data
;   flux_calv       - Array of calving flux data
;   discharge       - Array of discharge data
;   discharge_gl    - Array of glacier discharge data
;   DAILY (The variables below are stored with daily values)
;   accday          - Array of accumulation
;   rainday         - Array of rain
;   snowmeltday     - Array of snowmelt
;   icemeltday      - Array of ice melt
;   refrday         - Array of refreezing
;   snowlineday     - Array of snowline altitude
;   id              - Identifier for each glacier to be modelled in a region
;   gg, g           - Glacier group and index
;   years           - Number of simulation years
;   y               - Array of year values
;-----------------------------------------------------------


PRO WRITE_RESULTS_FILES_DAILY, format_of, outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, accday, rainday, snowmeltday, icemeltday, refrday, snowlineday, id, gg, g, years, y

    ; Validate inputs
    IF N_ELEMENTS(outf_names) EQ 0 THEN BEGIN
        PRINT, 'Error: outf_names is required.'
        RETURN
    ENDIF

    ; Validate time resolution (ensure it's daily)
    IF time_resolution NE 'daily' THEN BEGIN
        PRINT, 'Error: time_resolution must be "daily".'
        RETURN
    ENDIF

    ; Map variable indices to names
    vars = [areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, accday, rainday, snowmeltday, icemeltday, refrday, snowlineday / 1000.0]

    ; Get output indices
    ii = WHERE(outf_names NE '', ci)
    IF ci EQ 0 THEN BEGIN
        PRINT, 'Error: No output filenames specified.'
        RETURN
    ENDIF

    ; Loop through each output variable
    FOR i = 0, ci - 1 DO BEGIN
        var = vars[ii[i]]

        ; Handle yearly values (indices < 13)
        IF ii[i] LT 13 THEN BEGIN
            output_format = '(' + STRCOMPRESS(STRING(years), /REMOVE_ALL) + format_of(ii[i]) + ')'
            PRINTF, STRING(i + 10, FORMAT='(I2)'), id[gg[g]] + ' ' + STRING(var, FORMAT=output_format)
        
        ; Handle daily values (indices >= 13)
        ENDIF ELSE BEGIN
            FOR k = 0, years - 1 DO BEGIN
                att = (ii[i] NE 14) ? areas[0] : areas[k] ; Set attribute based on index
                daily_values = var[0 + k * 365 : 364 + k * 365] * 1000.0
                output_format = '(' + STRCOMPRESS(365, /REMOVE_ALL) + format_of(ii[i]) + ')'

                PRINTF, STRING(i + 10, FORMAT='(I2)'), id[gg[g]] + '  ' + STRING(y[k], FORMAT='(I4)') + '  ' + STRING(att, FORMAT='(F11.3)') + ' ' + STRING(daily_values, FORMAT=output_format)
            ENDFOR
        ENDELSE
    ENDFOR

END




