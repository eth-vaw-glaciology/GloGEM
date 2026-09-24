; *************************************************************
; spinup_firnicetemp_refyear
;
; One year of the reference forcing for the thermal spin-up, in the main
; run's order (hydrological year, from bal_month), so it ends where the main
; run starts. @-included by spinup_firnicetemp_thermal.pro; shares its scope.
; *************************************************************

for mo_sp = 0, 11 do begin
    ms = ((bal_month - 1 + mo_sp) mod 12) + 1
    ; surface temperature per band (lapse-rate extrapolation from climate grid)
    tgs = tclim_sp[ms-1] + (elev - hclim) * dtdz_icetemp[ms-1] + t_offset
    ; snowpack, melt and rain of the reference year (firnice_reference_forcing.pro)
    sno = reform(forc_sno[mo_sp, *])
    mel = reform(forc_mel[mo_sp, *])
    plg = reform(forc_plg[mo_sp, *])
    m   = ms

    @procedures/processing/firnice_temperature_model.pro
endfor
