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


PRO WRITE_RESULTS_FILES_DAILY, format_of, time_resolution, outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, accday, rainday, snowmeltday, icemeltday, refrday, snowlineday, id, gg, g, years, y
compile_opt idl2
    
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
end




