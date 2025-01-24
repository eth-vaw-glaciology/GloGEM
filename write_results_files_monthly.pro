;-----------------------------------------------------------
; Created by: 
;   Lander Van Tricht
; Date of last modificaton:
;   24/01/2025
; Name: 
;   WRITE_RESULTS_FILES
; Purpose: 
;   Procedure that writes the model results for all desired output variables.
; Inputs: 
;   https://github.com/sdrocer/GloGEM/wiki/14.-Writing-of-the-output
; Outputs:
;   All the input variables are written out as .dat output files. The filenames have been defined in outf_names.
;-----------------------------------------------------------

PRO WRITE_RESULTS_FILES_MONTHLY,outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, accday, rainday, snowmeltday, icemeltday, refrday, snowlineday, id, gg, g, years, y     

if time_resolution eq 'monthly' then begin
    ii=where(outf_names ne '',ci)
    for i=0,ci-1 do begin
	    case ii(i) of
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
	    15: var = balmo
	    16: var = precmo
	    17: var = accmo
	    18: var = melmo
	    19: var = refrmo
	    endcase
        ; For the yearly values
        if ii(i) ge 13 then begin
            a=12 
        endif else begin
            a=1
        endelse
	    printf,string(i+10,fo='(i2)'),id(gg(g))+' '+string(var,fo='('+strcompress(string(years)*a,/remove_all)+format_of(i)+')')
    endfor
endif 

if (time_resolution NE 'monthly') THEN BEGIN
    PRINT, 'Error: time_resolution must be "monthly".'
endif

end




