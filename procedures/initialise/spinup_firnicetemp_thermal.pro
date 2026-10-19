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
; Snowpack, melt and rain come from the main run's mass-balance files run
; on the reference climate; advection with the standalone velocity and the
; reference balance; no output.
;
; firnice_spinup_solver = 'drift' reaches the same equilibrium in ~20
; years instead of hundreds: it measures the remaining drift and jumps to
; where it leads, then checks that plain years no longer move the deep
; layers. One reference year is spinup_firnicetemp_refyear.pro.
;
; Variables read from outer scope (set by glogem.pro / initialise):
;   rtemp/rprec (or tempre/precre), clim_ilat/clim_ilon – full reanalysis series
;   hclim, dtdz, dtdz_icetemp  – lapse rates (thermal surface: firnice_temperature_model)
;   t_offset                   – temperature bias correction
;   elev, gl, firn, nb         – glacier geometry
;   tl_fit, te_fit             – firn/ice temperature arrays (modified)
;   DDFsnow, DDFice            – calibrated degree-day factors [mm/°C/day]
;   mon_len                    – days per month [12-element array]
;   fit_dz, fit_layers, fit_dens – layer geometry
;   Lh_rf, cice, kice, cair, kair, geothermal_flux – physics constants
;   rf_dsc                     – temporal sub-stepping (the step length fit_dt comes from mon_len)
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
_ufm_saved = use_flow_model & _ufg_saved = use_flow_model_gl
firnice_write    = ['n', 'n', 'n']
advection_write  = 'n'
; GloGEMflow's velocity fields do not exist yet for this glacier (any held are the previous
; glacier's): the spin-up uses the standalone velocity and the reference balance
use_flow_model = 'n' & use_flow_model_gl = 'n'

; ── active bands ───────────────────────────────────────────────────
ii_sp = where(gl ne noval, ci_sp)
if ci_sp eq 0 then begin
    enable_advection = _adv_saved
    firnice_write    = _fw_saved
    advection_write  = _aw_saved
    use_flow_model = _ufm_saved & use_flow_model_gl = _ufg_saved
    goto, spinup_done
endif

; ── Phase 1: Equilibrium cycling with 1961-1990 mean annual cycle ──

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
    ; still warming is held there, and one that meltwater brought to it during the measured
    ; year is left alone. A bed node at the melting point is held fixed, otherwise its heat
    ; flux is.
    n_warm_sp = 5l & n_block_sp = 3l & max_jumps_sp = 15l & tol_jump_sp = 0.01d
    n_slot_sp = n_lyr_total + 1l
    lacc_a = dblarr(nb, n_slot_sp) & lacc_c = dblarr(nb, n_slot_sp)
    lacc_tt = lonarr(nb) & lacc_kbed = dblarr(nb) & lacc_wet = bytarr(nb, n_slot_sp)
    lacc_h = dblarr(nb, n_slot_sp) & lacc_vd = lacc_h & lacc_vu = lacc_h   ; advection sums
    dst_sp = dblarr(nb, n_slot_sp)   ; this jump's change per band, all nodes, for the band below
    ; last 3 measured years per band: state at the start (hx) and at the end (hy)
    hx_sp = dblarr(nb, 3, n_slot_sp) & hy_sp = hx_sp & hn_sp = lonarr(nb)
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
        lacc_a[*] = 0d & lacc_c[*] = 0d & lacc_wet[*] = 0b
        lacc_h[*] = 0d & lacc_vd[*] = 0d & lacc_vu[*] = 0d & dst_sp[*] = 0d
        fit_lacc_on = 1b
        @procedures/initialise/spinup_firnicetemp_refyear.pro
        fit_lacc_on = 0b
        n_years_sp = n_years_sp + n_run_sp + 1l

        max_jump_sp = 0d
        ; top band first: each band's jump uses the change of the band above it
        for i_sp = ci_sp - 1l, 0l, -1l do begin
            b_sp = ii_sp[i_sp]
            tt_sp = lacc_tt[b_sp]
            ni_sp = tt_sp - 2l
            if ni_sp lt 1 then continue
            Tn_sp = reform(tl_fit[b_sp, 1:tt_sp-2])
            Dn_sp = Tn_sp - reform(tl_prev_sp[b_sp, 1:tt_sp-2])
            pm_sp = pmp_sp[1:tt_sp-2]
            ; Anderson mixing: of the last measured years, take the combination whose drift is
            ; smallest, and jump from its end state. Each stored pair is a real year of the real
            ; model, so it captures what the operator below misses (e.g. the meltwater front
            ; moving with the cold content). Skipped if the weights are large or nothing improves.
            if hn_sp[b_sp] gt 0 then begin
                hx_sp[b_sp, 1:2, *] = hx_sp[b_sp, 0:1, *] & hy_sp[b_sp, 1:2, *] = hy_sp[b_sp, 0:1, *]
            endif
            hx_sp[b_sp, 0, 0:ni_sp-1] = reform(tl_prev_sp[b_sp, 1:tt_sp-2]) & hy_sp[b_sp, 0, 0:ni_sp-1] = Tn_sp
            hn_sp[b_sp] = (hn_sp[b_sp] + 1l) < 3l
            y_mix_sp = Tn_sp
            ; no mixing where ice arrives from the band above: its past years were made under a
            ; different upstream state, so combining them ignores the coupling
            inflow_sp = max(lacc_h[b_sp, 1:tt_sp-2]) gt 0.1d
            if hn_sp[b_sp] ge 2 and not inflow_sp then begin
                ; differences to the older pairs j = 1 (and 2): f_j in drift, e_j in end state
                f1_sp = Dn_sp - reform(hy_sp[b_sp, 1, 0:ni_sp-1] - hx_sp[b_sp, 1, 0:ni_sp-1])
                e1_sp = Tn_sp - reform(hy_sp[b_sp, 1, 0:ni_sp-1])
                a11_sp = total(f1_sp^2) & r1_sp = total(f1_sp*Dn_sp)
                g1_sp = 0d & g2_sp = 0d & ok_sp = 0b
                if hn_sp[b_sp] eq 3 then begin
                    f2_sp = Dn_sp - reform(hy_sp[b_sp, 2, 0:ni_sp-1] - hx_sp[b_sp, 2, 0:ni_sp-1])
                    e2_sp = Tn_sp - reform(hy_sp[b_sp, 2, 0:ni_sp-1])
                    a12_sp = total(f1_sp*f2_sp) & a22_sp = total(f2_sp^2) & r2_sp = total(f2_sp*Dn_sp)
                    det_sp = a11_sp*a22_sp - a12_sp^2
                    if det_sp gt 1d-12*(a11_sp*a22_sp) and a11_sp gt 0d then begin
                        g1_sp = (r1_sp*a22_sp - r2_sp*a12_sp) / det_sp
                        g2_sp = (a11_sp*r2_sp - a12_sp*r1_sp) / det_sp
                        ok_sp = 1b
                    endif
                endif
                if not ok_sp and a11_sp gt 0d then begin
                    g1_sp = r1_sp / a11_sp & g2_sp = 0d & ok_sp = 1b
                    f2_sp = dblarr(ni_sp) & e2_sp = f2_sp
                endif
                if ok_sp and (abs(g1_sp) > abs(g2_sp)) lt 5d then begin
                    D_mix_sp = Dn_sp - g1_sp*f1_sp - g2_sp*f2_sp
                    if total(D_mix_sp^2) lt total(Dn_sp^2) then begin
                        y_mix_sp = (Tn_sp - g1_sp*e1_sp - g2_sp*e2_sp) < pm_sp
                        Dn_sp = D_mix_sp
                    endif
                endif
            endif
            Tn_sp = y_mix_sp
            a_sp  = reform(lacc_a[b_sp, 1:tt_sp-2])
            c_sp  = reform(lacc_c[b_sp, 1:tt_sp-2])
            dz_bed_sp = (fit_dz[1,tt_sp-1] - fit_dz[1,tt_sp-2]) > 1.0d
            bed_hot_sp = (Tn_sp[ni_sp-1] + geothermal_flux*dz_bed_sp/lacc_kbed[b_sp]) ge pmp_sp[tt_sp-1]
            ; L rows: sub a, diag -(a+c) (+c at the bottom for a fixed-flux bed), super c; plus
            ; burial (from the node above), emergence (from below) and exchange h with the band
            ; above, whose change this jump (dst_sp) enters at the same relative depth
            vd_sp = reform(lacc_vd[b_sp, 1:tt_sp-2]) & vu_sp = reform(lacc_vu[b_sp, 1:tt_sp-2])
            h_sp  = reform(lacc_h[b_sp, 1:tt_sp-2])
            lsub_sp = -a_sp - vd_sp & lsup_sp = -c_sp - vu_sp & ldia_sp = a_sp + c_sp + vd_sp + vu_sp + h_sp
            if not bed_hot_sp then ldia_sp[ni_sp-1] = ldia_sp[ni_sp-1] - c_sp[ni_sp-1]
            up_sp = dblarr(ni_sp)
            if i_sp lt ci_sp - 1l then begin
                b_up_sp = ii_sp[i_sp+1] & tt_up_sp = lacc_tt[b_up_sp]
                if tt_up_sp ge 2 then up_sp = interpol(reform(dst_sp[b_up_sp, 0:tt_up_sp-1]), $
                    reform(fit_dz[1,0:tt_up_sp-1]), $
                    (reform(fit_dz[1,1:tt_sp-2]) / (fit_dz[1,tt_sp-1] > 1d)) * (fit_dz[1,tt_up_sp-1] > 1d))
            endif
            De_sp = Dn_sp + h_sp*up_sp
            ; sign flipped (-L delta = D) so the diagonal is positive for the Thomas sweep
            ; held: at the melting point and still warming (delta to pmp), or brought to the
            ; melting point by meltwater during the measured year (delta 0: refreezing, not
            ; conduction, sets them each summer)
            wet_sp  = reform(lacc_wet[b_sp, 1:tt_sp-2]) ne 0
            held_sp = ((Tn_sp ge pm_sp - 1d-6) and (Dn_sp ge -1d-6)) or wet_sp
            for it_as_sp = 0, 49 do begin
                sa_sp = lsub_sp & sb_sp = ldia_sp & sc_sp = lsup_sp & sd_sp = De_sp
                jh_sp = where(held_sp, nh_sp)
                if nh_sp gt 0 then begin
                    sa_sp[jh_sp] = 0d & sc_sp[jh_sp] = 0d & sb_sp[jh_sp] = 1d & sd_sp[jh_sp] = pm_sp[jh_sp] - Tn_sp[jh_sp]
                    jw_sp = where(wet_sp, nw_sp) & if nw_sp gt 0 then sd_sp[jw_sp] = 0d
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
                jr_sp = where(held_sp and (wet_sp eq 0) and (De_sp - lxd_sp) lt 0d, nr_sp)
                if nr_sp gt 0 then new_sp[jr_sp] = 0b
                if array_equal(new_sp, held_sp) then break
                held_sp = new_sp
            endfor
            ; interior only: the model resets the bed node and the slots below it every step
            tl_new_sp = (Tn_sp + dl_sp) < pm_sp
            chg_sp = tl_new_sp - reform(tl_fit[b_sp, 1:tt_sp-2])
            max_jump_sp = max_jump_sp > max(abs(chg_sp))
            tl_fit[b_sp, 1:tt_sp-2] = tl_new_sp
            ; the solved jump on all nodes, for the band below: surface 0, bed follows its neighbour
            ; unless held at the melting point. Only the solved part: the Anderson displacement is
            ; this band's own, and passing it on made it grow from band to band down the glacier.
            dst_sp[b_sp, 1:tt_sp-2] = dl_sp
            if not bed_hot_sp then dst_sp[b_sp, tt_sp-1] = dl_sp[ni_sp-1]
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

; ── restore flags and the mass-balance snow state ─────────────────
sno = sno_keep & mel = dblarr(nb) & plg = dblarr(nb)
use_flow_model = _ufm_saved & use_flow_model_gl = _ufg_saved
spinup_done:
enable_advection = _adv_saved
firnice_write    = _fw_saved
advection_write  = _aw_saved
