; *************************************************************
; spinup_firnicetemp_refyear
;
; One year of the reference climate for the thermal spin-up, Jan-Dec.
; @-included by spinup_firnicetemp_thermal.pro; shares its scope.
; *************************************************************

for ms = 1, 12 do begin
    ; surface temperature per band (lapse-rate extrapolation from climate grid)
    tg_sp  = tclim_sp[ms-1] + (elev - hclim) * dtdz_icetemp[ms-1] + t_offset
    tgs_sp = tg_sp   ; surface BC used in firnice_temperature_model line 96

    ; simplified DDF melt (mm/°C/day → m w.e./month)
    mel_sp[*] = 0d
    for i_sp = 0l, ci_sp - 1l do begin
        if tg_sp[ii_sp[i_sp]] gt 0d then begin
            if firn[ii_sp[i_sp]] eq 1 then $
                mel_sp[ii_sp[i_sp]] = DDFsnow * tg_sp[ii_sp[i_sp]] * mon_len[ms-1] / 1000d $
            else $
                mel_sp[ii_sp[i_sp]] = DDFice  * tg_sp[ii_sp[i_sp]] * mon_len[ms-1] / 1000d
        endif
    endfor

    ; set outer-scope variables that firnice_temperature_model reads
    sno = sno_sp
    mel = mel_sp
    plg = plg_sp
    tgs = tgs_sp
    m   = ms

    @procedures/processing/firnice_temperature_model.pro
endfor
