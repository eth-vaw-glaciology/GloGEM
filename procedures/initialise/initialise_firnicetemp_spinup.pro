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

; ── Lapse rate for ice temperature only: the reanalysis rate up to the climate cell's
; elevation hclim, at least 6.5 K/km above it (ERA5's rate describes the terrain around the
; cell and is too shallow when extrapolated upwards). Thermal surface only; the mass balance
; keeps dtdz. Above hclim the thermal surface is shifted by (elev-hclim)*(dtdz_icetemp-dtdz).
dtdz_icetemp = (dtdz < (-0.0065d))
if firnice_thermal_lapse eq 'reanalysis' then dtdz_icetemp = dtdz
if firnice_thermal_lapse eq 'stations' then dtdz_icetemp = firnice_lapse_stations
; height above the climate cell over which dtdz_icetemp replaces dtdz: all of it, or for 'stations' only up
; to the stations' height (the winter inversion does not reach the summits)
zth_cap = (firnice_thermal_lapse eq 'stations') ? firnice_lapse_stations_dz : 1d10

; ── Long-term annual mean T_maat per band (reference period: cyear < 2020) ───
; an energy input of the thermal model: without t_offset if firnice_forcing_toff = 'n'
t_off_th = (firnice_forcing_toff eq 'n') ? 0d : t_offset
t_maat_band=dblarr(nb) & ii=where(cyear lt 2020,ci)
for i=0,nb-1 do begin
   dlap = (elev[i]-hclim)*mean(dtdz) + (((elev[i]-hclim) > 0d) < zth_cap)*(mean(dtdz_icetemp)-mean(dtdz))
   if ci gt 0 then a=temp[ii]+dlap+t_off_th $
     else a=temp+dlap+t_off_th
   t_maat_band[i]=mean(a)
endfor

; ── glenglat calibration constants (notebook 02 CART depth-2, rounded) ───────
T_AMP_THRESH   = 20.0d    ; °C  Maritime / Non-Maritime T_amplitude boundary
ELEV_MAR_SPLIT = 4300.0d  ; m   Maritime elevation sub-split
ELEV_CON_SPLIT = 1500.0d  ; m   Non-Maritime elevation sub-split
DT_MAR_LOW     = 4.40d    ; °C  Maritime,     elev <= 4300 m
DT_MAR_HIGH    = 0.54d    ; °C  Maritime,     elev >  4300 m (high-altitude)
DT_CON_HIGH    = 7.26d    ; °C  Non-Maritime, elev >  1500 m
DT_CON_LOW     = 10.34d   ; °C  Non-Maritime, elev <= 1500 m
; z0_firn per band → firnice_z0_firn_b (initialised from firnice_z0_firn in settings.pro)

; ── Reference period monthly climatology at climate grid point ────────────────
tclim_ref = dblarr(12)
for m = 1, 12 do begin
    jm = where(cyear lt 2020 and cmon eq m, cm)
    if cm gt 0 then tclim_ref[m-1] = mean(temp[jm])
endfor

; ── T_amplitude per band → ΔT_firn, 4-leaf decision tree ─────────────────────
; DIAGNOSTIC ONLY: no longer feeds the physics, kept as the reference column that
; write_firnicetemp_validation.pro compares the modelled offset against.
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
; Herron & Langway (1980), closed form (firnice_hl1980 = 'y'): density rho in Mg/m3, depth h in m,
; accumulation A in m w.e./a; ln[rho/(rhoi-rho)] grows by rhoi*k0 per m in stage 1 and by
; rhoi*k1/sqrt(A) per m in stage 2
HL80_k0 = 11.d  & HL80_E0 = 10160.d   ; stage 1, E [J/mol]
HL80_k1 = 575.d & HL80_E1 = 21400.d   ; stage 2
HL80_R  = 8.314d                       ; [J/(mol K)]
HL80_rhoi = 0.917d
HL80_g0  = alog(400.d / 517.d)        ; ln[rho/(rhoi-rho)] at the surface density, 400 kg/m3
HL80_g55 = alog(550.d / 367.d)        ; at 550 kg/m3
HL80_g83 = alog(830.d / 87.d)         ; at 830 kg/m3 (pore close-off)

firnice_perm_depth = dblarr(nb) + 30.d   ; default fallback (matches old fixed value)

; Mean annual net accumulation (m w.e.) per firn band: snowfall minus DDF melt
hl_mask = (firn eq 1)
hl_acc  = dblarr(nb)
hl_tk   = (t_maat_band + 273.15d) > 220.d   ; band mean annual T in Kelvin (floor at 220 K)
for i = 0, nb-1 do begin
    if firn[i] ne 1 then continue   ; ice bands: percolation handled via snow layers only
    acc_ann = 0.d
    for ms = 1, 12 do begin
        tg_b  = tclim_ref[ms-1] + (elev[i] - hclim) * dtdz[ms-1] + t_offset
        ; Elevation-scaled precipitation
        pg_b  = pclim_ref[ms-1] + pclim_ref[ms-1] * ((elev[i] - hclim) / 10000.d) * dpdz
        ; Snow fraction using same T_thres ramp as accumulation.pro
        if tg_b lt T_thres - 1.d then sfrac = 1.0d $
        else if tg_b gt T_thres + 1.d then sfrac = 0.0d $
        else sfrac = -(tg_b - T_thres - 1.d) / 2.d
        acc_ann += pg_b * sfrac * snow_multiplier
        if tg_b gt 0d then acc_ann -= DDFsnow * tg_b * mon_len[ms-1] / 1000.d
    endfor
    hl_acc[i] = acc_ann
endfor
@procedures/initialise/firnice_perm_depth.pro

; firn mask of the thermal model: the mass-balance mask unless the thermal spin-up replaces it
; (firnice_reference_forcing.pro); it follows the mass-balance mask again once that is updated
; from modelled balances (finalize_annual_massbalance.pro)
firn_th = firn

sr_steps = 0l & sr_bed = 0l   ; firnice_snow_refreeze: band-steps with snow refreezing, and those reaching the bed node

; ── Per-band calibration parameter arrays ────────────────────────────────────
; Initialized to scalar defaults from settings.pro (or config.pro overrides).
; A per-glacier file override (apply_firnicetemp_calibration.pro, called after
; this file in glogem.pro) can then override all bands for a specific glacier.
;
; The climate-regression transfer model that used to predict these per firn
; band (from t_maat_band[i]/t_amp_band[i]/elev[i], gated on firnice_temp_calib='y') has
; been RETIRED to simplify this file -- its coefficients were placeholders,
; never fit past a first pass (see notebooks/archive/05_firnicetemp_calibration.ipynb). Any run
; with firnice_temp_calib='y' (e.g. config_centraleurope_glenglat_knn.pro /
; _bayes.pro) now starts every band from these flat scalar defaults instead of
; a per-band prediction; the knn/bayes delta correctors (apply_firnicetemp_
; calibration_knn.pro / _bayes.pro) still apply on top, just against this
; flatter baseline than before -- a real output change for those two configs,
; not merely a no-op cleanup.
firnice_perm_frac_b = dblarr(nb) + firnice_perm_frac
firnice_z0_firn_b   = dblarr(nb) + firnice_z0_firn   ; per-band C&P e-folding depth [m]

; ── Advection velocity scaling factor (Tier-3 Bayesian calibration parameter) ─
; Replaces z0 as the calibrated parameter for the advection pathway: z0 stays
; fixed at its settings.pro default (firnice_z0_firn above), while this factor
; scales the physical advection velocity u in firnice_temperature_model.pro.
; Default (firnice_adv_scale, settings.pro) = 1.0 = unscaled baseline physics.
; Overridden per band by the Python calibration writeback script.
firnice_adv_scale_b = dblarr(nb) + firnice_adv_scale

; ── Snow/firn insulation scaling ─────────────────────────────────────────────
; Per-band multiplier on the Calonne (2011) snow/firn conductivity (see
; firnice_temperature_model.pro); the Yen ice branch is unscaled. Continuous in
; the tracked snow depth via dens_fit.
firnice_insul_scale_b = dblarr(nb) + firnice_insul_scale

; ── Refreezing fraction ──────────────────────────────────────────────────────
; Per-band share of surface meltwater+rain that percolates into the column (see
; fit_water in firnice_temperature_model.pro). Energy only; the mass balance is
; unaffected.
firnice_refreeze_frac_b = dblarr(nb) + firnice_refreeze_frac

; ── Initial profile for all bands ────────────────────────────────────────────
; Isothermal at the long-term mean air temperature, capped at the melting point.
; The decision-tree firn insulation offset that used to shape this profile is gone;
; with firnice_thermal_spinup='y' the real profile is built from the surface BC,
; conductivity, advection and latent heat instead of being prescribed here.
te_fit = dblarr(nb, total(fit_layers)+1)
for i = 0, nb-1 do te_fit[i, 0:total(fit_layers)-1] = min([0.d, t_maat_band[i]])
tl_fit = te_fit

; The thermal spinup used to run here. It now runs in glogem.pro AFTER the
; apply_firnicetemp_calibration* overrides, so it uses this glacier's calibrated
; parameters rather than the settings.pro defaults.

