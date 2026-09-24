; *************************************************************
; spinup_firnicetemp_thermal
;
; Thermal spin-up for the firn/ice temperature model. Called from
; glogem.pro (after the calibration overrides) when
; firnice_thermal_spinup eq 'y'.
;
; Repeats one year of the reference-period mean climate
; (firnice_spinup_ref_period, default hydrological years 1961-1990,
; firnice_reference_forcing.pro) until the deep layers stop changing.
; The year runs in the main run's month order and ends in the month
; before the main run starts, which then continues from this state.
; Forcing is simplified (DDF melt, no rain, no snow, no advection, no
; output).
;
; firnice_spinup_solver = 'drift' reaches the same equilibrium in ~20
; years instead of hundreds: it measures the remaining drift and jumps to
; where it leads, then checks that plain years no longer move the deep
; layers. One reference year is spinup_firnicetemp_refyear.pro.
;
; Variables read from outer scope (set by glogem.pro / initialise):
;   rtemp/rprec (or tempre/precre), clim_ilat/clim_ilon – full reanalysis series
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
firnice_write    = ['n', 'n', 'n']
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

; Mean monthly climate of the reference period, from the full reanalysis series
@procedures/initialise/firnice_reference_forcing.pro

; Working arrays for the simplified spinup forcing
sno_sp = dblarr(nb)   ; zero snow (clean firn surface during spinup)
mel_sp = dblarr(nb)
plg_sp = dblarr(nb)   ; no rain during spinup
tgs_sp = dblarr(nb)
tg_sp  = dblarr(nb)

n_lyr_total = long(total(fit_layers))

; Convergence tracking: deep layers only, selected by DEPTH so it survives a grid change.
; First node at or below 15 m, the depth of zero annual amplitude on Alpine glaciers.
_jdeep = where(reform(fit_dz[1,*]) ge 15.d, _ndeep)
deep_start = (_ndeep gt 0) ? _jdeep[0] : (n_elements(fit_dz[1,*]) - 1l)
deep_start = long(deep_start)

print, '  [thermal spinup] Phase 1: equilibrium cycling with ' + $
       strtrim(sp_y0,2) + '-' + strtrim(sp_y1,2) + ' mean climate'

converged_sp = 0b
n_cyc_sp = 0l
if firnice_spinup_solver eq 'drift' then begin

    ; ── drift correction ────────────────────────────────────────────
    ; Run real years; measure how fast each layer still drifts over one year (D); solve
    ; L*delta = -D, where L holds the conduction coefficients the model summed over that
    ; year; add delta; repeat. Stops once the real model no longer drifts, so the result is
    ; the model's own equilibrium: L only affects how fast we get there.
    ; Surface delta is 0. Layers may not jump past the melting point; one already at it and
    ; still warming is held there. A bed node at the melting point is held fixed, otherwise
    ; its heat flux is.
    n_warm_sp = 5l & n_block_sp = 3l & max_jumps_sp = 8l & tol_jump_sp = 0.01d
    n_slot_sp = n_lyr_total + 1l
    lacc_a = dblarr(nb, n_slot_sp) & lacc_c = dblarr(nb, n_slot_sp)
    lacc_tt = lonarr(nb) & lacc_kbed = dblarr(nb)
    pmp_sp = (reform(fit_dz[1,*])*0.9d/10.d)*(-0.00742d)
    n_jumps_sp = 0l
    n_years_sp = 0l
    while n_jumps_sp lt max_jumps_sp and not converged_sp do begin

        n_run_sp = (n_jumps_sp eq 0) ? n_warm_sp : (n_block_sp - 1l)
        for yr_sp = 0l, n_run_sp - 1l do begin
            @procedures/initialise/spinup_firnicetemp_refyear.pro
        endfor

        ; measured year, with coefficient sums
        tl_prev_sp = tl_fit
        lacc_a[*] = 0d & lacc_c[*] = 0d
        fit_lacc_on = 1b
        @procedures/initialise/spinup_firnicetemp_refyear.pro
        fit_lacc_on = 0b
        n_years_sp = n_years_sp + n_run_sp + 1l

        max_jump_sp = 0d
        for i_sp = 0l, ci_sp - 1l do begin
            b_sp = ii_sp[i_sp]
            tt_sp = lacc_tt[b_sp]
            ni_sp = tt_sp - 2l
            if ni_sp lt 1 then continue
            Tn_sp = reform(tl_fit[b_sp, 1:tt_sp-2])
            Dn_sp = Tn_sp - reform(tl_prev_sp[b_sp, 1:tt_sp-2])
            pm_sp = pmp_sp[1:tt_sp-2]
            a_sp  = reform(lacc_a[b_sp, 1:tt_sp-2])
            c_sp  = reform(lacc_c[b_sp, 1:tt_sp-2])
            dz_bed_sp = (fit_dz[1,tt_sp-1] - fit_dz[1,tt_sp-2]) > 1.0d
            bed_hot_sp = (Tn_sp[ni_sp-1] + geothermal_flux*dz_bed_sp/lacc_kbed[b_sp]) ge pmp_sp[tt_sp-1]
            ; L rows: sub a, diag -(a+c) (+c at the bottom for a fixed-flux bed), super c
            lsub_sp = -a_sp & lsup_sp = -c_sp & ldia_sp = a_sp + c_sp
            if not bed_hot_sp then ldia_sp[ni_sp-1] = ldia_sp[ni_sp-1] - c_sp[ni_sp-1]
            ; sign flipped (-L delta = D) so the diagonal is positive for the Thomas sweep
            held_sp = (Tn_sp ge pm_sp - 1d-6) and (Dn_sp ge -1d-6)
            for it_as_sp = 0, 49 do begin
                sa_sp = lsub_sp & sb_sp = ldia_sp & sc_sp = lsup_sp & sd_sp = Dn_sp
                jh_sp = where(held_sp, nh_sp)
                if nh_sp gt 0 then begin
                    sa_sp[jh_sp] = 0d & sc_sp[jh_sp] = 0d & sb_sp[jh_sp] = 1d & sd_sp[jh_sp] = pm_sp[jh_sp] - Tn_sp[jh_sp]
                endif
                for k_sp = 1l, ni_sp - 1l do begin
                    f_sp = sa_sp[k_sp] / sb_sp[k_sp-1]
                    sb_sp[k_sp] = sb_sp[k_sp] - f_sp*sc_sp[k_sp-1]
                    sd_sp[k_sp] = sd_sp[k_sp] - f_sp*sd_sp[k_sp-1]
                endfor
                dl_sp = dblarr(ni_sp)
                dl_sp[ni_sp-1] = sd_sp[ni_sp-1] / sb_sp[ni_sp-1]
                for k_sp = ni_sp - 2l, 0l, -1l do dl_sp[k_sp] = (sd_sp[k_sp] - sc_sp[k_sp]*dl_sp[k_sp+1]) / sb_sp[k_sp]
                ; held layers the rest of the column would pull colder are released
                lxd_sp = ldia_sp*dl_sp
                if ni_sp gt 1 then begin
                    lxd_sp[1:*]        = lxd_sp[1:*] + lsub_sp[1:*]*dl_sp[0:ni_sp-2]
                    lxd_sp[0:ni_sp-2]  = lxd_sp[0:ni_sp-2] + lsup_sp[0:ni_sp-2]*dl_sp[1:*]
                endif
                new_sp = held_sp
                jf_sp = where(held_sp eq 0, nf_sp)
                if nf_sp gt 0 then new_sp[jf_sp] = (Tn_sp[jf_sp] + dl_sp[jf_sp]) gt (pm_sp[jf_sp] + 1d-9)
                jr_sp = where(held_sp and (Dn_sp - lxd_sp) lt 0d, nr_sp)
                if nr_sp gt 0 then new_sp[jr_sp] = 0b
                if array_equal(new_sp, held_sp) then break
                held_sp = new_sp
            endfor
            ; interior only: the model resets the bed node and the slots below it every step
            tl_fit[b_sp, 1:tt_sp-2] = (Tn_sp + dl_sp) < pm_sp
            max_jump_sp = max_jump_sp > max(abs(dl_sp))
        endfor
        n_jumps_sp = n_jumps_sp + 1l
        print, '  [thermal spinup] jump ' + strtrim(n_jumps_sp,2) + ' after ' + $
               strtrim(n_years_sp,2) + ' years: largest jump = ' + string(max_jump_sp, fo='(f8.4)') + ' °C'
        if n_jumps_sp ge 2 and max_jump_sp lt tol_jump_sp then converged_sp = 1b
    endwhile

    ; verification: plain years must not move the deep layers. One year first, so the bed
    ; node and the slots below it are the model's own again.
    @procedures/initialise/spinup_firnicetemp_refyear.pro
    tl_deep_prev = tl_fit[ii_sp, deep_start:n_lyr_total-1]
    for yr_sp = 0l, n_warm_sp - 1l do begin
        @procedures/initialise/spinup_firnicetemp_refyear.pro
    endfor
    n_years_sp = n_years_sp + n_warm_sp + 1l
    max_dT_sp = max(abs(tl_fit[ii_sp, deep_start:n_lyr_total-1] - tl_deep_prev))
    n_cyc_sp = n_years_sp
    if converged_sp then $
        print, '  [thermal spinup] drift correction converged: ' + strtrim(n_jumps_sp,2) + $
               ' jumps, ' + strtrim(n_years_sp,2) + ' years; next ' + strtrim(n_warm_sp,2) + $
               ' plain years move the deep layers by ' + string(max_dT_sp, fo='(f7.4)') + ' °C' $
    else $
        print, '  [thermal spinup] WARNING: drift correction did not converge in ' + $
               strtrim(max_jumps_sp,2) + ' jumps; falling back to plain cycling'
endif

if not converged_sp then begin
for sp = n_cyc_sp, long(firnice_spinup_max_cycles) - 1l do begin

    ; snapshot of deep layers for convergence check
    tl_deep_prev = tl_fit[ii_sp, deep_start:n_lyr_total-1]

    @procedures/initialise/spinup_firnicetemp_refyear.pro

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
endif

; ── restore flags ──────────────────────────────────────────────────
spinup_done:
enable_advection = _adv_saved
firnice_write    = _fw_saved
advection_write  = _aw_saved
