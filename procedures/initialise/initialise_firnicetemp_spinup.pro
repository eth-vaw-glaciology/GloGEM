; *************************************************************
; initialise_firnicetemp_spinup
;
; Initialise glacier retreat flags and firn/ice temperature arrays.
;
; Sets glacier_retreat to 'n' for hindcast/startyear runs, resets
; the month counter, and initialises the firn/ice temperature
; arrays with C&P exponential profiles calibrated against glenglat.
;
; ΔT_firn per elevation band is assigned via a decision-tree lookup
; on ERA5 T_amplitude and band elevation (calibrated on n=208 filtered
; glenglat profiles, notebook 02 depth-2 CART, 2026). GloGEM's own
; PMP ceiling (min[0, T]) handles near-PMP bands at runtime.
; *************************************************************

compile_opt idl2

if hindcast_dynamic eq 'y' then glacier_retreat='n'
if find_startyear eq 'y' then glacier_retreat='n'
if find_startyear eq 'n' then glacier_retreat='n'

ccmon=0l

te_rf=dblarr(nb,rf_layers) & tl_rf=te_rf

; ── Long-term annual mean T_maat per band (reference period: cyear < 2020) ───
tt=dblarr(nb) & ii=where(cyear lt 2020,ci)
for i=0,nb-1 do begin
   if ci gt 0 then a=temp[ii]+(elev[i]-hclim)*mean(dtdz)+t_offset $
     else a=temp+(elev[i]-hclim)*mean(dtdz)+t_offset
   tt[i]=mean(a)
endfor

; ── glenglat calibration constants (notebook 02 CART depth-2, rounded) ───────
T_AMP_THRESH   = 20.0d    ; °C  Maritime / Non-Maritime T_amplitude boundary
ELEV_MAR_SPLIT = 4300.0d  ; m   Maritime elevation sub-split
ELEV_CON_SPLIT = 1500.0d  ; m   Non-Maritime elevation sub-split
DT_MAR_LOW     = 4.40d    ; °C  Maritime,     elev <= 4300 m
DT_MAR_HIGH    = 0.54d    ; °C  Maritime,     elev >  4300 m (high-altitude)
DT_CON_HIGH    = 7.26d    ; °C  Non-Maritime, elev >  1500 m
DT_CON_LOW     = 10.34d   ; °C  Non-Maritime, elev <= 1500 m
z0_firn        = 15.0d    ; m   C&P e-folding depth

; ── Reference period monthly climatology at climate grid point ────────────────
tclim_ref = dblarr(12)
for m = 1, 12 do begin
    jm = where(cyear lt 2020 and cmon eq m, cm)
    if cm gt 0 then tclim_ref[m-1] = mean(temp[jm])
endfor

; ── T_amplitude per band → ΔT_firn via 4-leaf decision tree ──────────────────
dT_firn_band = dblarr(nb)
t_amp_band   = dblarr(nb)
for i = 0, nb-1 do begin
    tg_band       = tclim_ref + (elev[i] - hclim) * dtdz + t_offset
    t_amp_band[i] = max(tg_band) - min(tg_band)
    if t_amp_band[i] le T_AMP_THRESH then begin
        if elev[i] le ELEV_MAR_SPLIT then dT_firn_band[i] = DT_MAR_LOW $
        else                              dT_firn_band[i] = DT_MAR_HIGH
    endif else begin
        if elev[i] gt ELEV_CON_SPLIT then dT_firn_band[i] = DT_CON_HIGH $
        else                              dT_firn_band[i] = DT_CON_LOW
    endelse
endfor

; ── C&P exponential profile for firn bands; isothermal for ice bands ─────────
te_fit = dblarr(nb, total(fit_layers)+1)
for i = 0, nb-1 do begin
    if firn[i] eq 1 then begin
        depth = 0.d
        for j = 0, total(fit_layers)-1 do begin
            depth += fit_dz[0, j]
            te_fit[i, j] = min([0.d, tt[i] + dT_firn_band[i] * exp(-depth / z0_firn)])
        endfor
    endif else begin
        te_fit[i, *] = tt[i]
    endelse
endfor
tl_fit = te_fit

; Per-band running sums for f_rf validation (accumulated in finalize_annual_massbalance)
melt_rf_sum = dblarr(nb)
refr_rf_sum = dblarr(nb)
