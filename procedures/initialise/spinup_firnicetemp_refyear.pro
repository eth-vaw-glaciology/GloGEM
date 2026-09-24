; *************************************************************
; spinup_firnicetemp_refyear
;
; One year of the reference climate for the thermal spin-up, in the main
; run's order (hydrological year, from bal_month), so it ends where the main
; run starts. @-included by spinup_firnicetemp_thermal.pro; shares its scope.
; *************************************************************

for mo_sp = 0, 11 do begin
    ms = ((bal_month - 1 + mo_sp) mod 12) + 1
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
