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

te_rf=dblarr(nb,rf_layers) & tl_rf=te_rf

; ── Lapse rate for ice temperature only: enforce free-air floor (-0.0065 K/m).
; ERA5 dtdz is calibrated over terrain up to ~2400 m and is too shallow when
; extrapolated to high-altitude bands. The corrected rate is used exclusively
; here — the global dtdz used by the mass balance model is NOT modified.
dtdz_icetemp = (dtdz < (-0.0065d))

; ── Long-term annual mean T_maat per band (reference period: cyear < 2020) ───
tt=dblarr(nb) & ii=where(cyear lt 2020,ci)
for i=0,nb-1 do begin
   if ci gt 0 then a=temp[ii]+(elev[i]-hclim)*mean(dtdz_icetemp)+t_offset $
     else a=temp+(elev[i]-hclim)*mean(dtdz_icetemp)+t_offset
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
    tg_band       = tclim_ref + (elev[i] - hclim) * dtdz_icetemp + t_offset
    t_amp_band[i] = max(tg_band) - min(tg_band)
    if t_amp_band[i] le T_AMP_THRESH then begin
        if elev[i] le ELEV_MAR_SPLIT then dT_firn_band[i] = DT_MAR_LOW $
        else                              dT_firn_band[i] = DT_MAR_HIGH
    endif else begin
        if elev[i] gt ELEV_CON_SPLIT then dT_firn_band[i] = DT_CON_HIGH $
        else                              dT_firn_band[i] = DT_CON_LOW
    endelse
endfor

; ── Per-band percolation depth from Herron-Langway / Sorge's law ─────────────
; The firn-ice transition depth (where density first reaches 830 kg/m³, closing
; pore connectivity) depends on accumulation rate and temperature via the
; Herron-Langway (1980) densification model.  High-accumulation sites like
; Jungfraufirn have z_FIT ~50-80 m; low-accumulation near-ELA bands ~10-20 m.
; Using a fixed 30 m for all bands (as the constant fit_dens profile does) is
; wrong for both ends of this range.
;
; Approach: estimate mean annual net accumulation per band from the reference-
; period climate, then apply the two-stage Herron-Langway model to derive z_FIT.
; This array persists throughout the simulation and is read in
; firnice_temperature_model.pro to set perm_limit.

; Mean monthly reference-period precipitation at the climate grid point (m w.e.)
pclim_ref = dblarr(12)
for m = 1, 12 do begin
    jm = where(cyear lt 2020 and cmon eq m, cm)
    if cm gt 0 then pclim_ref[m-1] = mean(prec[jm]) * c_prec / 1000.d
endfor

; Herron-Langway (1980) two-stage densification constants.
; Stage 1 (400–550 kg/m³): grain rearrangement and settling
; Stage 2 (550–830 kg/m³): pressure sintering and grain boundary diffusion
; Both use Arrhenius-type rate coefficients so that colder sites densify
; more slowly → deeper firn for the same accumulation rate.
HL_k1 = 11.0d  & HL_E1 = 10.16d   ; Stage 1: k [yr⁻¹], E [kJ/mol]
HL_k2 = 575.0d & HL_E2 = 21.4d    ; Stage 2: k [yr⁻¹/√(m w.e./yr)], E [kJ/mol]
HL_R  = 0.00832d                   ; gas constant [kJ/(mol K)]
; Precompute log factors (density constants: ρ_s=400, ρ_550=550, ρ_FIT=830, ρ_i=917 kg/m³)
; Avoids arithmetic inside alog() which confuses IDL's parser with .d literals
HL_ln1 = alog(517.d / 367.d)      ; ln((917-400)/(917-550)) ≈ 0.343
HL_ln2 = alog(367.d / 87.d)       ; ln((917-550)/(917-830)) ≈ 1.439

firnice_perm_depth = dblarr(nb) + 30.d   ; default fallback (matches old fixed value)
acc_ann_b          = dblarr(nb)           ; per-band net accumulation (m w.e.) for transfer model

for i = 0, nb-1 do begin
    if firn[i] ne 1 then continue   ; ice bands: percolation handled via snow layers only

    ; Mean annual net accumulation (m w.e.): snowfall minus DDF melt
    acc_ann = 0.d
    for ms = 1, 12 do begin
        tg_b  = tclim_ref[ms-1] + (elev[i] - hclim) * dtdz_icetemp[ms-1] + t_offset
        ; Elevation-scaled precipitation
        pg_b  = pclim_ref[ms-1] + pclim_ref[ms-1] * ((elev[i] - hclim) / 10000.d) * dpdz
        ; Snow fraction using same T_thres ramp as accumulation.pro
        if tg_b lt T_thres - 1.d then sfrac = 1.0d $
        else if tg_b gt T_thres + 1.d then sfrac = 0.0d $
        else sfrac = -(tg_b - T_thres - 1.d) / 2.d
        acc_ann += pg_b * sfrac * snow_multiplier
        if tg_b gt 0d then acc_ann -= DDFsnow * tg_b * mon_len[ms-1] / 1000.d
    endfor
    if acc_ann lt 0.1d then acc_ann = 0.1d   ; floor: at least nominal firn for firn bands
    acc_ann_b[i] = acc_ann

    ; Band mean annual T in Kelvin (floor at 220 K to avoid numerical issues)
    T_K_b = (tt[i] + 273.15d) > 220.d

    ; Stage 1 (ρ_s=400 → 550 kg/m³): scale height and actual depth
    ; H_s1 = b / (k₁ × exp(−E₁/(R T)))  [ice-equivalent metres]
    H_s1  = acc_ann / (HL_k1 * exp(-HL_E1 / (HL_R * T_K_b)))
    z_s1  = H_s1 * HL_ln1 * (917.d/475.d)

    ; Stage 2 (550 → 830 kg/m³): rate scales as b^0.5
    ; H_s2 = b^0.5 / (k₂ × exp(−E₂/(R T)))  [ice-equivalent metres]
    H_s2  = sqrt(acc_ann) / (HL_k2 * exp(-HL_E2 / (HL_R * T_K_b)))
    z_s2  = H_s2 * HL_ln2 * (917.d/690.d)

    z_fit = (z_s1 + z_s2) > 10.d < 120.d   ; physical bounds: 10–120 m

    firnice_perm_depth[i] = z_fit
endfor

; ── Per-band calibration parameter arrays ────────────────────────────────────
; Initialized to scalar defaults from settings.pro (or config.pro overrides).
; When firnice_temp_calib='y', the transfer model overrides per firn band.
; A per-glacier file override (apply_firnicetemp_calibration.pro, called after
; this file in glogem.pro) can then override all bands for a specific glacier.
firnice_perm_frac_b = dblarr(nb) + firnice_perm_frac
firnice_dT_scale_b  = dblarr(nb) + firnice_dT_scale

; ── Transfer-model calibration (optional, firnice_temp_calib='y') ─────────────
; Predicts (perm_frac, dT_scale) per firn band from climate predictors.
; Coefficients below are placeholders (all = defaults) until the calibration
; notebook (05_firnicetemp_calibration.ipynb) derives them from glenglat data.
; Ice bands always keep the scalar default (no firn percolation or insulation).
if firnice_temp_calib eq 'y' then begin
    ; Transfer model coefficients — replace with notebook output (05_firnicetemp_calibration.ipynb).
    ; Predictor order: c1=tt[i] (MAAT, °C), c2=t_amp_band[i] (°C),
    ;                  c3=acc_ann_b[i] (m w.e./yr), c4=elev[i] (m)
    c0_pf = 1.0d & c1_pf = 0.0d & c2_pf = 0.0d & c3_pf = 0.0d & c4_pf = 0.0d
    c0_ds = 1.0d & c1_ds = 0.0d & c2_ds = 0.0d & c3_ds = 0.0d & c4_ds = 0.0d
    for i = 0, nb-1 do begin
        if firn[i] ne 1 then continue
        firnice_perm_frac_b[i] = (c0_pf + c1_pf*tt[i] + c2_pf*t_amp_band[i] $
            + c3_pf*acc_ann_b[i] + c4_pf*elev[i]) > 0.05d < 1.0d
        firnice_dT_scale_b[i]  = (c0_ds + c1_ds*tt[i] + c2_ds*t_amp_band[i] $
            + c3_ds*acc_ann_b[i] + c4_ds*elev[i]) > 0.2d < 3.0d
    endfor
endif

; ── C&P exponential profile for firn bands; isothermal for ice bands ─────────
te_fit = dblarr(nb, total(fit_layers)+1)
for i = 0, nb-1 do begin
    if firn[i] eq 1 then begin
        depth = 0.d
        for j = 0, total(fit_layers)-1 do begin
            depth += fit_dz[0, j]
            te_fit[i, j] = min([0.d, tt[i] + firnice_dT_scale_b[i] * dT_firn_band[i] * exp(-depth / z0_firn)])
        endfor
    endif else begin
        te_fit[i, *] = tt[i]
    endelse
endfor
tl_fit = te_fit

; ── Optional thermal spinup (overrides the C&P analytical profile) ─
; Set firnice_thermal_spinup='y' in config.pro to activate.
; Uses the C&P profile above as the starting point, then runs the
; actual heat equation until deep temperatures converge, followed by
; a transient run-in through the historical climate up to tran[0].
if firnice_thermal_spinup eq 'y' and firnice_temperature eq 'y' then begin
    @procedures/initialise/spinup_firnicetemp_thermal.pro
endif

