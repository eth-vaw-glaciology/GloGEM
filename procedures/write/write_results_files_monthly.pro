; *************************************************************
; write_results_files_monthly
;
; Write annual and monthly glacier mass balance output variables to
; per-variable .dat result files for the monthly time-resolution run.
;
; Iterates over all active output variable names in outf_names,
; mapping each index to the corresponding model array (area, volume,
; mass balance, melt, accumulation, ELA, AAR, refreezing, discharge,
; and monthly sub-annual series for balance, precipitation,
; accumulation, melt, and refreezing). Annual variables are written
; as a single row per glacier; monthly variables include 12 values
; per year concatenated into the same row format.
; *************************************************************

compile_opt idl2

    ; Validate inputs
    IF N_ELEMENTS(outf_names) EQ 0 THEN MESSAGE, 'Error: outf_names is required.'
    IF time_resolution NE 'monthly' THEN MESSAGE, 'Error: time_resolution must be "monthly".'

    if time_resolution eq 'monthly' then begin
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
			15: var = balmo
			16: var = precmo
			17: var = accmo
			18: var = melmo
			19: var = refrmo
			20: var = snowlinemon   ; monthly transient snowline [m a.s.l.] (written directly, no scaling)
            endcase
         	if ii[i] ge 13 then a=12 else a=1
	   		printf,string(i+10,fo='(i2)'),id[gg[g]]+' '+string(var,fo='('+strcompress(string(years)*a,/remove_all)+format_of[i]+')')
   		endfor
    endif
