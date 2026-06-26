; *************************************************************
; spinup_firnicetemp_thermal
;
; Two-phase thermal spinup for the firn/ice temperature model.
; Called from initialise_firnicetemp_spinup.pro when
; firnice_thermal_spinup eq 'y'.
;
; Phase 1 — Equilibrium cycling
;   Cycles a fixed mean-annual climate derived from the reference
;   period (firnice_spinup_ref_period, default 1961-1990) until the
;   deep firn temperatures converge (max change < firnice_spinup_tol).
;   Uses the same heat-equation kernel as the main loop but with
;   simplified forcing (DDF melt, no rain, no snow accumulation, no
;   advection, no output).  The C&P analytical profile computed in
;   initialise_firnicetemp_spinup.pro is the starting point.
;
;   Result: temperate/near-temperate bands converge to 0°C at depth;
;   cold high-altitude bands converge to their 1961-1990 mean-annual
;   ice temperature — physically correct for both end-members.
;
; Phase 2 — Transient run-in
;   Runs the heat equation forward through the actual ERA5/reanalysis
;   climate from firnice_spinup_ref_period[0] to tran[0]-1.  This
;   plants the 20th-century warming trend in the near-surface firn
;   before the main simulation begins.
;
; Variables read from outer scope (set by glogem.pro / initialise):
;   cyear, cmon, temp          – full loaded climate time series
;   hclim, dtdz_icetemp        – lapse-rate for ice temperature
;   t_offset                   – temperature bias correction
;   elev, gl, firn, nb         – glacier geometry
;   tl_fit, te_fit             – firn/ice temperature arrays (modified)
;   DDFsnow, DDFice            – calibrated degree-day factors [mm/°C/day]
;   mon_len                    – days per month [12-element array]
;   fit_dz, fit_layers, fit_dens – layer geometry
;   Lh_rf, cice, kice, cair, kair, geothermal_flux – physics constants
;   rf_dsc, rf_dt              – temporal sub-stepping
;   firnice_implicit, firn_permeability – solver flags
;   firnice_thermal_spinup, firnice_spinup_ref_period,
;   firnice_spinup_max_cycles, firnice_spinup_tol – spinup settings
;
; Modifies: tl_fit (firn/ice temperature profiles for all bands)
; *************************************************************

compile_opt idl2

; ── save flags we temporarily override ─────────────────────────────
_adv_saved = enable_advection
_fw_saved  = firnice_write
_aw_saved  = advection_write
enable_advection = 'n'
firnice_write    = ['n', 'n']
advection_write  = 'n'

; ── active bands ───────────────────────────────────────────────────
ii_sp = where(gl ne noval, ci_sp)
if ci_sp eq 0 then begin
    enable_advection = _adv_saved
    firnice_write    = _fw_saved
    advection_write  = _aw_saved
    goto, spinup_done
endif

; ── Phase 1: Equilibrium cycling with 1961-1990 mean annual cycle ──

; Determine available reference period in the loaded climate data
sp_y0 = long(firnice_spinup_ref_period[0])
sp_y1 = long(firnice_spinup_ref_period[1])
ii_ref = where(cyear ge sp_y0 and cyear le sp_y1, ci_ref)
if ci_ref eq 0 then begin
    ; fall back to earliest 30 years in loaded data
    sp_y0 = min(cyear)
    sp_y1 = sp_y0 + 29l
    ii_ref = where(cyear ge sp_y0 and cyear le sp_y1, ci_ref)
    print, '  [thermal spinup] reference period not in loaded data; using ' + $
           strtrim(sp_y0,2) + '-' + strtrim(sp_y1,2)
endif

; Mean monthly temperature at the climate grid point for the reference period
tclim_sp = dblarr(12)
for ms = 1, 12 do begin
    jm = where(cyear ge sp_y0 and cyear le sp_y1 and cmon eq ms, cm)
    if cm gt 0 then tclim_sp[ms-1] = mean(temp[jm])
endfor

; Working arrays for the simplified spinup forcing
sno_sp = dblarr(nb)   ; zero snow (clean firn surface during spinup)
mel_sp = dblarr(nb)
plg_sp = dblarr(nb)   ; no rain during spinup
tgs_sp = dblarr(nb)
tg_sp  = dblarr(nb)

n_lyr_total = long(total(fit_layers))

; Convergence tracking: deep layers only (depth > 15 m, index >= 10)
deep_start = 10l

print, '  [thermal spinup] Phase 1: equilibrium cycling with ' + $
       strtrim(sp_y0,2) + '-' + strtrim(sp_y1,2) + ' mean climate'

converged_sp = 0b
for sp = 0l, long(firnice_spinup_max_cycles) - 1l do begin

    ; snapshot of deep layers for convergence check
    tl_deep_prev = tl_fit[ii_sp, deep_start:n_lyr_total-1]

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

    ; convergence check across all active bands' deep layers
    max_dT_sp = max(abs(tl_fit[ii_sp, deep_start:n_lyr_total-1] - tl_deep_prev))
    if sp ge long(firnice_spinup_min_cycles) - 1l and max_dT_sp lt firnice_spinup_tol then begin
        converged_sp = 1b
        print, '  [thermal spinup] Phase 1 converged after ' + strtrim(sp+1l,2) + $
               ' cycles  (max deep ΔT = ' + string(max_dT_sp, fo='(f6.3)') + ' °C)'
        break
    endif

    ; progress update every 50 cycles
    if (sp+1) mod 50 eq 0 then $
        print, '  [thermal spinup] cycle ' + strtrim(sp+1l,2) + $
               '  max deep ΔT = ' + string(max_dT_sp, fo='(f6.3)') + ' °C'
endfor

if not converged_sp then $
    print, '  [thermal spinup] WARNING: Phase 1 did not converge after ' + $
           strtrim(firnice_spinup_max_cycles,2) + ' cycles'

; ── Phase 2: Transient run-in from sp_y0 to tran[0]-1 ─────────────
yr_trans_lo = sp_y0
yr_trans_hi = tran[0] - 1l

ii_trans = where(cyear ge yr_trans_lo and cyear le yr_trans_hi, ci_trans)

if ci_trans gt 0 then begin
    print, '  [thermal spinup] Phase 2: transient run-in ' + $
           strtrim(yr_trans_lo,2) + ' – ' + strtrim(yr_trans_hi,2) + $
           '  (' + strtrim(ci_trans,2) + ' months)'

    for it = 0l, ci_trans - 1l do begin
        mt = long(cmon[ii_trans[it]])
        yt = long(cyear[ii_trans[it]])

        ; actual climate for this month
        tg_sp  = temp[ii_trans[it]] + (elev - hclim) * dtdz_icetemp[mt-1] + t_offset
        tgs_sp = tg_sp

        mel_sp[*] = 0d
        for i_sp = 0l, ci_sp - 1l do begin
            if tg_sp[ii_sp[i_sp]] gt 0d then begin
                if firn[ii_sp[i_sp]] eq 1 then $
                    mel_sp[ii_sp[i_sp]] = DDFsnow * tg_sp[ii_sp[i_sp]] * mon_len[mt-1] / 1000d $
                else $
                    mel_sp[ii_sp[i_sp]] = DDFice  * tg_sp[ii_sp[i_sp]] * mon_len[mt-1] / 1000d
            endif
        endfor

        sno = sno_sp
        mel = mel_sp
        plg = plg_sp
        tgs = tgs_sp
        m   = mt

        @procedures/processing/firnice_temperature_model.pro
    endfor

    print, '  [thermal spinup] Phase 2 complete'
endif else begin
    print, '  [thermal spinup] Phase 2: no pre-simulation data in loaded climate for ' + $
           strtrim(yr_trans_lo,2) + '-' + strtrim(yr_trans_hi,2) + '; skipping'
endelse

; ── restore flags ──────────────────────────────────────────────────
spinup_done:
enable_advection = _adv_saved
firnice_write    = _fw_saved
advection_write  = _aw_saved
