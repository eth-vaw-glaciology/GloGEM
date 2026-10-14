; *************************************************************
; firnice_reference_forcing
;
; Mean monthly climate of the thermal spin-up's reference period
; (firnice_spinup_ref_period, hydrological years, e.g. Oct 1960 - Sep 1990),
; from the full reanalysis series at the glacier's climate cell.
; The main run only loads tran[0]-1..tran[1] into temp/prec, so the full
; series is taken from rtemp/rprec (or tempre/precre on the 'new' path).
;
; Sets: tclim_sp[12] [°C], pclim_sp[12] [mm/month], at the climate cell.
; *************************************************************

compile_opt idl2

if time_resolution ne 'monthly' then $
    message, 'thermal spin-up: only monthly runs are supported'

if new eq 'y' then begin
    ts_sp = double(tempre) & ps_sp = double(precre)
endif else begin
    ts_sp = reform(rtemp[*, clim_ilon, clim_ilat])
    ps_sp = reform(rprec[*, clim_ilon, clim_ilat])
endelse

sp_y0 = long(firnice_spinup_ref_period[0])
sp_y1 = long(firnice_spinup_ref_period[1])
; months from bal_month on belong to the next hydrological year
hyd_sp = long(ryear) + (long(rmon) ge bal_month)

tclim_sp = dblarr(12) & pclim_sp = dblarr(12)
for ms = 1, 12 do begin
    jm = where(hyd_sp ge sp_y0 and hyd_sp le sp_y1 and rmon eq ms, cm)
    if cm lt 20 then message, 'thermal spin-up: only ' + strtrim(cm,2) + ' years of month ' + $
        strtrim(ms,2) + ' in ' + strtrim(sp_y0,2) + '-' + strtrim(sp_y1,2) + ' (need >= 20)'
    tclim_sp[ms-1] = mean(ts_sp[jm])
    pclim_sp[ms-1] = mean(ps_sp[jm])
endfor

if sp_y1 ne tran[0]-1l then $
    print, '  [thermal spinup] note: reference period ends Sep ' + strtrim(sp_y1,2) + $
           ', main run starts month ' + strtrim(bal_month,2) + ' of ' + strtrim(tran[0]-1l,2)

; ── One reference year of surface forcing, from the main run's own mass-balance files ──
; accumulation/meltmodel/refreezing run with mb_book = 0b on the spin-up's own snowpack,
; in the main run's month order and with its snow bookkeeping (glogem.pro month loop and
; finalize_annual_massbalance). The snowpack settles in the first year; the third is kept.
; The mass-balance state (sno, sur, snostor) is restored afterwards.
; Sets per month (hydrological order) and band: forc_sno (start of month, after the
; January reset), forc_mel, forc_plg, forc_tgs (air temperature, reanalysis lapse rate), and b_ref [m w.e./yr] = psg - mel + refr of that year;
; then the thermal firn mask firn_th (b_ref > 0) and its firnice_perm_depth.
; forc_mel, forc_plg and forc_tgs are the thermal model's energy inputs (firnice_thermal_forcing.pro,
; without t_offset if firnice_forcing_toff = 'n'); b_ref, forc_sno and firn_th stay the mass balance's.
sno_keep = sno & sur_keep = sur & snostor_keep = snostor
sno = dblarr(nb) & sur = dblarr(nb) & snostor = dblarr(nb)
forc_sno = dblarr(12, nb) & forc_mel = dblarr(12, nb) & forc_plg = dblarr(12, nb) & forc_tgs = dblarr(12, nb)
b_ref = dblarr(nb)
rfw_mb = 0d & rfw_th = 0d   ; firn-band melt + rain of the kept year, mass balance and thermal
mb_book = 0b
for yr_rf = 0, 2 do begin
    rf_ind = dblarr(nb) & rf_cold = rf_ind
    bal_rf = dblarr(nb)
    for mo_rf = 0, 11 do begin
        m = ((bal_month - 1 + mo_rf) mod 12) + 1
        psg = dblarr(nb) & mel = psg & refr = psg & corrdis = psg & snowmel = mel & icemel = mel
        if bal_month eq dd_thresholds[2] then if m eq 1 then sno = sno - snostor
        if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sno = sno - snostor
        jj = where(sno lt 0, cj) & if cj gt 0 then sno[jj] = 0
        tg = tclim_sp[m-1] + (elev - hclim) * dtdz[m-1] + t_offset
        pc = pclim_sp[m-1] * c_prec / 1000.
        forc_sno[mo_rf, *] = sno
        @procedures/processing/accumulation.pro
        @procedures/processing/meltmodel.pro
        if refreezing_full eq 'y' then begin
            @procedures/processing/refreezing_full.pro
        endif else begin
            if refreezing_parametrised eq 'y' then begin
                @procedures/processing/refreezing_parametrised.pro
            endif
        endelse
        @procedures/processing/firnice_thermal_forcing.pro
        forc_mel[mo_rf, *] = mel_th & forc_plg[mo_rf, *] = plg_th & forc_tgs[mo_rf, *] = tgs_th
        if yr_rf eq 2 then begin
            jw = where(firn eq 1 and gl ne noval, cw)
            if cw gt 0 then begin
                rfw_mb = rfw_mb + total((mel[jw] + plg[jw]) * area[jw]) / total(area[jw])
                rfw_th = rfw_th + total((mel_th[jw] + plg_th[jw]) * area[jw]) / total(area[jw])
            endif
        endif
        ; snow reservoir and surface type, as in the glogem.pro month loop
        sno = sno + psg - mel
        jj = where(sno gt 0, cj) & if cj gt 0 then sur[jj] = 1
        jj = where(sno lt 0, cj) & if cj gt 0 then sno[jj] = 0
        jj = where(sno eq 0 and gl ne noval, cj) & if cj gt 0 then sur[jj] = 0
        jj = where(sno eq 0 and gl eq noval, cj) & if cj gt 0 then sur[jj] = noval
        jj = where(sno eq 0 and firn eq 1, cj) & if cj gt 0 then sur[jj] = 2
        bal_rf = bal_rf + psg - mel + refr
    endfor
    snostor = sno
    jj = where(gl eq noval, cj) & if cj gt 0 then sur[jj] = noval
    b_ref = bal_rf
endfor
mb_book = 1b
sno = sno_keep & sur = sur_keep & snostor = snostor_keep

; firnice_perm_limit 'firn': the firn layers start in the steady state of the reference balance,
; one layer of b_ref for each of the n_fl years before the run where b_ref > 0
if firnice_perm_limit eq 'firn' then begin
   fl_we[*] = 0d & fl_yr[*] = 0l
   jj = where(b_ref gt 0 and gl ne noval, cj)
   if cj gt 0 then for fl_k = 0l, n_fl-1 do begin
      fl_we[jj,fl_k] = b_ref[jj] & fl_yr[jj,fl_k] = long(tran[0]) - 1l - fl_k
   endfor
endif

; Thermal firn mask from the reference balance, and its firn-ice transition depth from the same
; balance and the band's reference-period mean temperature
firn_th = dblarr(nb)
jj = where(b_ref gt 0 and gl ne noval, cj) & if cj gt 0 then firn_th[jj] = 1
hl_mask = (firn_th eq 1)
hl_acc  = b_ref
hl_tk   = dblarr(nb)
t_off_th = (firnice_forcing_toff eq 'n') ? 0d : t_offset
for i = 0, nb-1 do hl_tk[i] = mean(tclim_sp + (elev[i] - hclim) * dtdz + (((elev[i] - hclim) > 0d) < zth_cap) * (dtdz_icetemp - dtdz) + t_off_th)
hl_tk   = (hl_tk + 273.15d) > 220.d
@procedures/initialise/firnice_perm_depth.pro
jg = where(gl ne noval, cg)
if cg gt 0 then begin
    jf = where(firn_th[jg] eq 1, cf) & jm = where(firn[jg] eq 1, cm)
    aar_ref = (cf gt 0) ? 100d * total(area[jg[jf]]) / total(area[jg]) : 0d
    print, '  [thermal spinup] firn mask from the reference balance: ' + strtrim(cf,2) + ' of ' + $
           strtrim(cg,2) + ' bands, lowest ' + (cf gt 0 ? strtrim(round(min(elev[jg[jf]])),2) : '-') + $
           ' m, AAR ' + strtrim(round(aar_ref),2) + ' %' + $
           ' (mass-balance mask: ' + strtrim(cm,2) + ', lowest ' + (cm gt 0 ? strtrim(round(min(elev[jg[jm]])),2) : '-') + ' m)'
endif
if firnice_forcing_toff eq 'n' then $
    print, '  [thermal forcing] t_offset ' + string(t_offset, fo='(f6.2)') + ' K left out: firn-band melt + rain ' + $
           string(rfw_th, fo='(f7.3)') + ' m w.e./a (mass balance ' + string(rfw_mb, fo='(f7.3)') + ')'
