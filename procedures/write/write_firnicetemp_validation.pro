; *************************************************************
; write_firnicetemp_validation
;
; Included from glogem.pro after the year loop, within the
; firnice_temperature eq 'y' guard.
;
; Computes per-elevation-band refreezing fraction (f_rf) from
; the accumulated melt and refreeze sums, then derives the
; model-implied ΔT_firn = (Lf/ci) * f_rf (Clauser & Pape).
; Writes a per-glacier ASCII diagnostic file for validation
; against the glenglat-calibrated initialization values.
;
; Uses variables from glogem.pro scope:
;   melt_rf_sum[nb], refr_rf_sum[nb]  — from finalize_annual_massbalance
;   t_amp_band[nb], dT_firn_band[nb]  — from initialise_firnicetemp_spinup
;   elev[nb], firn_th[nb], gl[nb], tl_fit[nb,*]
;   ela, aar, firnline_th, nflip_ice, nflip_firn [years]  — firn line log
;   firnice_dir, id[gg[g]], nb, noval
; *************************************************************

compile_opt idl2

Lf_v = 334000.d   ; J/kg     latent heat of fusion
ci_v = 2009.d     ; J/(kg K) specific heat of ice
rho_w_v = 1000.d  ; kg/m3    density of water

; ── Model-implied firn warming from refreezing ───────────────────────────────
;
; This used to be   dT = (Lf/ci) * f_rf,   with f_rf = refreeze/melt.
;
; That is dimensionally a temperature but physically wrong: it scales the warming
; with the FRACTION of melt that refreezes instead of the AMOUNT of ice formed per
; unit mass of firn. A site that melts 1 mm and refreezes all of it scores f_rf = 1
; exactly like a site that melts 1 m and refreezes all of it, though the latent heat
; released differs by a factor of a thousand. Because f_rf tends to 1 precisely where
; melt tends to 0 -- cold, dry, high-altitude firn -- the old form predicted the
; LARGEST warming where there is the LEAST meltwater: on Gornergletscher it reached
; +47 K at 4400-4600 m, against a measured Colle Gnifetti temperature near -12 C.
;
; The energy balance for a firn layer of thickness z_perm and density rho_f that
; absorbs a mass m_r of refrozen water per year is
;
;     rho_f * z_perm * ci * dT  =  m_r * Lf
;  => dT = (Lf/ci) * (rho_w * refr_annual) / (rho_f * z_perm)
;
; i.e. the refrozen mass per unit mass of the firn column it warms. z_perm is the
; depth meltwater actually reaches (Herron-Langway transition scaled by perm_frac),
; which is the same depth the thermal module percolates to, so the diagnostic and
; the model refer to the same body of firn.
;
; f_rf is still reported -- it remains a meaningful quantity in its own right -- but
; it is no longer what the temperature offset is derived from.

n_years_v = double(years) > 1.d
; mean firn density over the percolation depth, from the model's own layer profile
rho_f_v = mean(double(fit_dens_ref))   ; the firn curve, not the resampled full column

f_rf_band = dblarr(nb)
refr_ann  = dblarr(nb)
z_perm_v  = dblarr(nb)
dT_model  = dblarr(nb)
for i = 0, nb-1 do begin
    if melt_rf_sum[i] gt 0 then $
        f_rf_band[i] = refr_rf_sum[i] / melt_rf_sum[i]
    refr_ann[i] = refr_rf_sum[i] / n_years_v            ; m w.e. per year
    z_perm_v[i] = (n_elements(firnice_perm_depth) eq nb) ? $
                  (firnice_perm_depth[i] * firnice_perm_frac_b[i]) : 30.d
    if z_perm_v[i] gt 0.1d then $
        dT_model[i] = (Lf_v / ci_v) * (rho_w_v * refr_ann[i]) / (rho_f_v * z_perm_v[i])
endfor

outfile = firnice_dir + '/firnice_temp_validation_' + id[gg[g]] + '.dat'
close, 99
openw, 99, outfile
printf, 99, '# GloGEM firn temperature validation  glacier: ' + id[gg[g]]
printf, 99, '# Calibration: T_amp_thresh=20.0C  elev_mar=4300m  elev_con=1500m'
printf, 99, '# f_rf denominator: melt only (rain not included)'
printf, 99, '# dT_model = (Lf/ci) * (rho_w * refr_annual) / (rho_firn * z_perm)  -- refrozen'
printf, 99, '#            mass per unit mass of the firn column it warms, NOT (Lf/ci)*f_rf'
printf, 99, '# elev  firn  t_amp  dT_init  f_rf  dT_model  residual  T_sfc  refr_ann  z_perm'
for i = 0, nb-1 do begin
    if gl[i] ne noval then begin
        residual = dT_model[i] - dT_firn_band[i]
        printf, 99, elev[i], fix(firn_th[i]), t_amp_band[i], dT_firn_band[i], $
                    f_rf_band[i], dT_model[i], residual, tl_fit[i, 0], $
                    refr_ann[i], z_perm_v[i], $
                fo='(i5, i3, 8f9.3)'
    endif
endfor
close, 99
print, 'Firn temp validation: ' + outfile

; firn line per year: modelled ELA and AAR, lowest thermal firn band, bands switching firn<->ice
outfile = firnice_dir + '/firnice_firnline_' + id[gg[g]] + '.dat'
openw, 99, outfile
printf, 99, '# GloGEM firn line log  glacier: ' + id[gg[g]] + '  (year = hydrological year label)'
printf, 99, '# year   ela   aar  firnline_th  n_firn_to_ice  n_ice_to_firn'
for ifl_y = 0, years-1 do if ela[ifl_y] ne snoval then $
    printf, 99, ifl_y+tran[0], ela[ifl_y], aar[ifl_y], firnline_th[ifl_y], nflip_ice[ifl_y], nflip_firn[ifl_y], $
            fo='(i5, f7.0, f6.1, f9.0, 2i8)'
close, 99

; snow logbook
if n_elements(snl_sum) gt 0 then begin
    outfile = firnice_dir + '/firnice_snowclim_' + id[gg[g]] + '.dat'
    openw, 99, outfile
    printf, 99, '# GloGEM snow logbook  glacier: ' + id[gg[g]] + '  (means over the run per calendar month; snow at the start of the month, temperatures at its end)'
    printf, 99, '# R: resistance from the surface to the first node under the snow [m2 K/W], as the solver uses it (R_used) and for layered snow and ice (R_series)'
    printf, 99, '#  elev month firn_frac sno_mwe z_snow z_mass  T_surf   T_ice    T_1m    T_2m  R_used R_series'
    for snl_b = 0, nb-1 do begin
        for snl_mo = 0, 11 do begin
            if snl_cnt[snl_mo,snl_b] gt 0 then begin
                snl_q = snl_sum[*,snl_mo,snl_b] / snl_cnt[snl_mo,snl_b]
                printf, 99, elev[snl_b], snl_mo+1, snl_q[9], snl_q[0:2], snl_q[3:6], snl_q[7:8], $
                        fo='(i6, i6, f10.2, 3f7.3, 4f8.2, 2f8.3)'
            endif
        endfor
    endfor
    close, 99
    outfile = firnice_dir + '/firnice_wetdepth_' + id[gg[g]] + '.dat'
    openw, 99, outfile
    printf, 99, '# GloGEM wet-depth log  glacier: ' + id[gg[g]] + '  per firn band and year: deepest node the percolating water brought to 0 C [m] and water left at the percolation limit [m w.e.]'
    printf, 99, '#  elev  year  wet_depth  water_lost'
    for snl_b = 0, nb-1 do begin
        if gl[snl_b] eq noval then continue
        for snl_y = 0, years-1 do $
            if wdl_depth[snl_y,snl_b] gt 0d or wdl_lost[snl_y,snl_b] gt 0d then $
                printf, 99, elev[snl_b], snl_y+tran[0], wdl_depth[snl_y,snl_b], wdl_lost[snl_y,snl_b], fo='(i6, i6, f11.1, f12.3)'
    endfor
    close, 99
    if firnice_perm_limit eq 'firn' then begin
       outfile = firnice_dir + '/firnice_firnledger_' + id[gg[g]] + '.dat'
       openw, 99, outfile
       printf, 99, '# GloGEM firn ledger  glacier: ' + id[gg[g]] + '  per band and year, after that year''s balance: firn [m w.e.], its depth on the thermal density profile [m], number of annual layers, year of the oldest (firnice_perm_limit ''firn'')'
       printf, 99, '#  elev  year  firn_we  firn_depth  n_layers  oldest'
       for snl_b = 0, nb-1 do begin
          if gl[snl_b] eq noval then continue
          for snl_y = 0, years-1 do $
             printf, 99, elev[snl_b], snl_y+tran[0], fll_we[snl_y,snl_b], fll_z[snl_y,snl_b], $
                     fll_n[snl_y,snl_b], fll_old[snl_y,snl_b], fo='(i6, i6, f9.3, f12.2, i10, i8)'
       endfor
       close, 99
    endif
    outfile = firnice_dir + '/firnice_bed_' + id[gg[g]] + '.dat'
    openw, 99, outfile
    printf, 99, '# GloGEM bed log  glacier: ' + id[gg[g]] + '  per band and year it was glacierized: the node at the band ice thickness (depth [m], annual mean, minimum and maximum [C], pressure melting point [C]) and the column bottom (depth [m], annual mean [C]; deeper than the bed where the column runs to a borehole reading)'
    printf, 99, '#  elev  year  bed_depth   T_mean   T_min   T_max   T_pmp  bottom_depth  T_bottom'
    for snl_b = 0, nb-1 do begin
        for snl_y = 0, years-1 do $
            if bed_cnt[snl_y,snl_b] gt 0d then $
                printf, 99, elev[snl_b], snl_y+tran[0], bed_z[snl_y,snl_b], bed_sum[snl_y,snl_b]/bed_cnt[snl_y,snl_b], $
                        bed_min[snl_y,snl_b], bed_max[snl_y,snl_b], (bed_z[snl_y,snl_b]*0.9d/10d)*(-0.00742d), $
                        bed_zb[snl_y,snl_b], bed_bot[snl_y,snl_b]/bed_cnt[snl_y,snl_b], $
                        fo='(i6, i6, f11.1, 3f8.3, f8.3, f14.1, f10.3)'
    endfor
    close, 99
    outfile = firnice_dir + '/firnice_snowmay_' + id[gg[g]] + '.dat'
    openw, 99, outfile
    printf, 99, '# GloGEM snow on 1 May [m w.e.]  glacier: ' + id[gg[g]] + '  rows: band elevation, then one column per year from ' + strtrim(tran[0],2)
    for snl_b = 0, nb-1 do begin
        if gl[snl_b] ne noval then printf, 99, elev[snl_b], snl_may[*,snl_b], fo='(i6,' + strtrim(years,2) + 'f8.3)'
    endfor
    close, 99
    if n_elements(snl_bh) gt 0 then begin
        outfile = firnice_dir + '/firnice_snowbh_' + id[gg[g]] + '.dat'
        openw, 99, outfile
        printf, 99, '# GloGEM snow at the start of each month at the profile bands [m w.e.]  glacier: ' + id[gg[g]]
        printf, 99, '# profile  band_elev  year  month  sno'
        for snl_p = 0, n_prof-1 do begin
            for snl_y = 0, years-1 do begin
                for snl_mo = 0, 11 do begin
                    if snl_bh[snl_y,snl_mo,snl_p] ne snoval then $
                        printf, 99, firnice_profile_ID[snl_p], firnice_profile_ind[1,snl_p], snl_y+tran[0], $
                                snl_mo+1, snl_bh[snl_y,snl_mo,snl_p], fo='(a8, i8, i6, i6, f8.3)'
                endfor
            endfor
        endfor
        close, 99
    endif
endif
