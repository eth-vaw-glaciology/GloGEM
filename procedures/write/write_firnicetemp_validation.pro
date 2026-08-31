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
;   elev[nb], firn[nb], gl[nb], tl_fit[nb,*]
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
rho_f_v = mean(double(fit_dens))

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
        printf, 99, elev[i], fix(firn[i]), t_amp_band[i], dT_firn_band[i], $
                    f_rf_band[i], dT_model[i], residual, tl_fit[i, 0], $
                    refr_ann[i], z_perm_v[i], $
                fo='(i5, i3, 8f9.3)'
    endif
endfor
close, 99
print, 'Firn temp validation: ' + outfile
