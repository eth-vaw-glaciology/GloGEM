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

f_rf_band = dblarr(nb)
dT_model  = dblarr(nb)
for i = 0, nb-1 do begin
    if melt_rf_sum[i] gt 0 then $
        f_rf_band[i] = refr_rf_sum[i] / melt_rf_sum[i]
    dT_model[i] = (Lf_v / ci_v) * f_rf_band[i]
endfor

outfile = firnice_dir + '/firnice_temp_validation_' + id[gg[g]] + '.dat'
close, 99
openw, 99, outfile
printf, 99, '# GloGEM firn temperature validation  glacier: ' + id[gg[g]]
printf, 99, '# Calibration: T_amp_thresh=20.0C  elev_mar=4300m  elev_con=1500m'
printf, 99, '# f_rf denominator: melt only (rain not included)'
printf, 99, '# elev  firn  t_amp  dT_init  f_rf  dT_model  residual  T_sfc'
for i = 0, nb-1 do begin
    if gl[i] ne noval then begin
        residual = dT_model[i] - dT_firn_band[i]
        printf, 99, elev[i], fix(firn[i]), t_amp_band[i], dT_firn_band[i], $
                    f_rf_band[i], dT_model[i], residual, tl_fit[i, 0], $
                fo='(i5, i3, 6f9.3)'
    endif
endfor
close, 99
print, 'Firn temp validation: ' + outfile
