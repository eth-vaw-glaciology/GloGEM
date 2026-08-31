; *************************************************************
; firnice_temperature_model
;
; Simulate the evolution of englacial firn and ice temperatures
; through heat conduction, latent heat release, and ice advection.
;
; For each glacierized elevation band the procedure solves a
; one-dimensional heat-conduction equation through a layered firn/ice
; column, applies latent heat from percolating meltwater based on
; firn permeability, and optionally adds horizontal and vertical ice
; advection using a shallow-ice velocity estimate and upwind finite-
; difference scheme. Temperature profiles are constrained to the
; pressure melting point and stored for output at selected depths.
; *************************************************************

compile_opt idl2

noval=-9999 & snoval=-99 ; no value indicators

; Arrays to store advection effects if enabled and requested
IF enable_advection EQ 'y' AND advection_write EQ 'y' THEN BEGIN
   ; Create arrays to track advection impacts
   adv_horiz_effect = DBLARR(N_ELEMENTS(gl))  ; Horizontal advection effect
   adv_vert_effect = DBLARR(N_ELEMENTS(gl))   ; Vertical advection effect
ENDIF

;*********************
; compute ice velocity for advection
ii_perm=where(gl ne noval,ci)

grav = 9.81   ; acceleration due to gravity [m/s^2]  (not 'g' — that is the glacier loop index)
rho_ice = 917 ; density of ice [kg/m^3]
A = 2.4e-24   ; ice flow law parameter [Pa^-3 s^-1]
n = 3         ; Glen's flow law exponent

; u[i] = depth-averaged speed of the i-th glacierized band (compact indexing, m/year)
u     = FLTARR(N_ELEMENTS(gl))
tau_d = FLTARR(N_ELEMENTS(gl))

IF use_flow_model_gl EQ 'y' AND N_ELEMENTS(u_flowmodel) EQ nb THEN BEGIN
   ; Use calibrated velocity from GloGEMflow (mapped to elevation bands at end of previous SIA year)
   FOR i = 0, ci-1 DO u[i] = u_flowmodel[ii_perm[i]]
ENDIF ELSE BEGIN
   ; Standalone SIA estimate: used when flow model is off or before the first SIA step (year 0)
   FOR i = 0, ci-1 DO BEGIN
      tau_d = rho_ice * grav * thick[ii_perm[i]] * SIN(slope[ii_perm[i]] * !DTOR)
      u[i] = (2 * A / (n + 2)) * tau_d^n * thick[ii_perm[i]] * 365.25 * 24 * 3600
   ENDFOR
ENDELSE

;*********************
; Pre-compute the pressure-melting-point (PMP) profile once per call, used
; below as an unconditional safety clamp on every layer of tl_fit. The
; per-block clamps above only cover j=1..tt-2, which can skip layers
; entirely for very thin/marginal bands (small tt) -- the clamp below
; guarantees no output path (conduction, advection, latent heat,
; bedrock-fill) can ever leave a value above PMP regardless of tt.
nfit = total(fit_layers)
pmp_profile = dblarr(nfit + 1)
pmp_profile[0] = 0d0
for jp = 1, nfit - 1 do pmp_profile[jp] = (fit_dz[1,jp] * 0.9d0 / 10.0d0) * (-0.00742d0)
pmp_profile[nfit] = pmp_profile[nfit - 1]
;*********************

ii=where(gl ne noval,ci)
for i=0,ci-1 do begin

; generate local, and actualized arrays for layer heat capacity, condictivity and density
dens_fit=dblarr(total(fit_layers))+900
a=fix(sno[ii[i]]/(fit_dens[1]/1000.)) ; number of snow layers
if a gt 18 then a=18            ; preventing too many layers for extreme snow depth (??)
; replacing top of density profile with snow values
for j=0,a-1 do dens_fit[j]=fit_dens[j]
; replacing top of density profile with firn values for the firn area
if firn[ii[i]] eq 1 then for j=min([a,5]),17 do dens_fit[j]=fit_dens[j] ; to be verified...

cap_fit=(1-dens_fit/1000.)*cair+dens_fit/1000.*cice
cond_fit=(1-dens_fit/1000.)*kair+dens_fit/1000.*kice

a=min(abs(thick[ii[i]]-fit_dz[1,*]),ind)
if firnice_batch eq 'y' then a=min(abs(firnice_maxdepth[0]-fit_dz[1,*]),ind)  ; run to actual depth of profile in batch/validation-mode
tt=min([ind+1,total(fit_layers)])  ; either run to bedrock, or to max of layers

; Permeability limit: stop meltwater at the firn-ice transition. Depth is
; band-specific (Herron-Langway, computed in initialise_firnicetemp_spinup.pro)
; so that high-accumulation sites get the physically correct ~50-80 m depth
; rather than the fixed 30 m that the constant fit_dens profile would give.
; Heat conduction still runs to bedrock (tt-2); only the latent-heat loop is capped.
z_perm_b  = firnice_perm_depth[ii[i]] * firnice_perm_frac_b[ii[i]]
pdidx_arr = where(fit_dz[1,*] ge z_perm_b, n_pdi)
perm_limit = (n_pdi gt 0) ? ((pdidx_arr[0] - 1l) > 1l) : (tt - 2l)
perm_limit = perm_limit < (tt - 2l)

; ── latent heat from refreezing (applied BEFORE conduction substeps) ─────────────
; Moved before the conduction loop so that all rf_dsc substeps of heat diffusion
; can smooth the temperature gradient at perm_limit depth each month. If refreezing
; ran AFTER conduction (as before), the sharp warm/cold boundary at perm_limit was
; recreated every month with no subsequent smoothing pass, producing a non-physical
; step discontinuity in the profile. Applying it first, then diffusing, is also the
; more natural operator-split: phase change is fast, diffusion is slow.
fit_water=mel[ii[i]]+plg[ii[i]]  ; liquid water available from surface (melt+rain)

if firn_permeability eq 'n' then fit_water = 0  ; check if permeability is disabled, if yes then set infiltrating water to zero

; latent heat release over firn/snow surface
; water percolation is capped at perm_limit (firn-ice transition density);
; cold ice below that depth is not reachable by annual meltwater
if firn[ii[i]] eq 1 then begin

for j=1,perm_limit do begin ; percolate to firn-ice transition only
   c=(-1)*(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*cap_fit[j]*fit_dz[0,j]/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit[ii[i],j]=(fit_dz[1,j]*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin
      if c gt 0 and fit_water gt 0 then tl_fit[ii[i],j]=tl_fit[ii[i],j]-(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*(fit_water/c)
      fit_water=fit_water-c
   endelse
 ;  if j eq 10 and ii(i) eq 245 then print, m,c,fit_water,tl_fit(ii(i),10)
endfor

endif else begin

; latent heat release over ice surface, incl. seasonal snow (mainly impermeable)

kk=where(dens_fit lt 900,ck)
for j=1,ck do begin ; loop through all SNOW layers from top, and update temperatures
   c=(-1)*(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*cap_fit[j]*fit_dz[0,j]/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit[ii[i],j]=(fit_dz[1,j]*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin
      if c gt 0 and fit_water gt 0 then tl_fit[ii[i],j]=tl_fit[ii[i],j]-(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*(fit_water/c)
      fit_water=fit_water-c
   endelse
endfor

; ice is assumed impermeable: no liquid water enters glacier ice
fit_water=fit_water*0

for j=ck+1,tt-2 do begin ; loop through all ICE layers from top, and update temperatures
   c=(-1)*(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*cap_fit[j]*fit_dz[0,j]/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit[ii[i],j]=(fit_dz[1,j]*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin
      if c gt 0 and fit_water gt 0 then tl_fit[ii[i],j]=tl_fit[ii[i],j]-(tl_fit[ii[i],j]-((fit_dz[1,j]*0.9/10.)*(-0.00742)))*(fit_water/c)
      fit_water=fit_water-c
   endelse
;   if j eq 10 and ii(i) eq 20 then print, m,c,fit_water,tl_fit(ii(i),20),f
endfor

endelse

   ; driving stress (SIA): used for strain heating if enabled
   tau_d_sh = rho_ice * grav * (thick[ii[i]] > 1.0d) * sin(slope[ii[i]] * !DTOR)

   for h=0,rf_dsc-1 do begin

      ; ── boundary conditions (shared by both conduction schemes) ──────────────
      ; All bands get a snow/firn insulation correction to the surface BC:
      ;   Firn bands: full correction  — dT_scale_b * dT_firn_band
      ;   Ice bands:  reduced (ICE_FRAC) — seasonal snow insulates ~40% as much
      ;               as perennial firn; gives non-flat ice profiles matching C&P init.
      ; ICE_FRAC must match the value in initialise_firnicetemp_spinup.pro.
      ICE_FRAC = 0.4d
      if firn[ii[i]] eq 1 then begin
          tl_fit[ii[i],0] = min([0d, tgs[ii[i]] + firnice_dT_scale_b[ii[i]] * dT_firn_band[ii[i]]])
      endif else begin
          tl_fit[ii[i],0] = min([0d, tgs[ii[i]] + ICE_FRAC * firnice_dT_scale_b[ii[i]] * dT_firn_band[ii[i]]])
      endelse
      ; Basal boundary condition: prescribed geothermal GRADIENT (Neumann), from Fourier's law
      ;     G = -k dT/dz_up   ->   dT/dz = G / k   (z measured downward, T warming with depth)
      ; so the bed node sits one layer-spacing below its neighbour at that gradient:
      ;     T[tt-1] = T[tt-2] + G * dz / k
      ;
      ; REPLACES an accumulation form, ttgeot = T[tt-1] + G*(month_seconds/rf_dsc)/cice, which
      ; had three separate problems:
      ;   (a) UNITS: W m^-2 * s / (J m^-3 K^-1) = K*m, not K -- the division by a layer
      ;       thickness was missing, so it behaved as if every layer were 1 m thick when the
      ;       bottom layer is 20 m for any column deeper than 79 m.
      ;   (b) the month length was hardcoded (3600*24*30.5), so a daily-resolution run would
      ;       have received a ~30x too large increment.
      ;   (c) it accumulated into the bed node, but line ~430 then overwrote that node with the
      ;       node ABOVE it at the end of every month, discarding the accumulated warming.
      ; Net effect of the old form was an insulating base plus a fixed ~0.08 K offset, i.e. an
      ; effective gradient near 0.004 K/m against a true G/k of ~0.029 K/m -- roughly 7x too
      ; weak, biasing modelled deep ice COLD and so under-predicting temperate basal ice.
      ; The gradient form below is timestep-independent by construction, which is why it fixes
      ; (a) and (b) together; (c) is fixed at the bedrock-fill line itself.
      dz_bed = (fit_dz[1,tt-1] - fit_dz[1,tt-2]) > 1.0d   ; true spacing of the bottom layer [m]
      ttgeot = tl_fit[ii[i],tt-2] + geothermal_flux * dz_bed / cond_fit[tt-1]
      tl_fit[ii[i],tt-1] = min([ttgeot, (fit_dz[1,tt-1]*0.9d/10.d)*(-0.00742d)])

      ; ── heat conduction (vertical) ────────────────────────────────────────────
      if firnice_implicit eq 'n' then begin

         ; explicit forward-difference with ×½ stability factor
         for j=1,tt-2 do begin
            te_fit[ii[i],j]=tl_fit[ii[i],j]+((rf_dt*cond_fit[j]/(cap_fit[j])*(tl_fit[ii[i],j-1]-tl_fit[ii[i],j])/fit_dz[0,j]^2.)- $
                (rf_dt*cond_fit[j]/(cap_fit[j])*(tl_fit[ii[i],j]-tl_fit[ii[i],j+1])/fit_dz[0,j]^2.))/2.
            tl_fit[ii[i],j]=te_fit[ii[i],j]
            if tl_fit[ii[i],j] gt (fit_dz[1,j]*0.9/10.)*(-0.00742) then tl_fit[ii[i],j]=(fit_dz[1,j]*0.9/10.)*(-0.00742)
         endfor

      endif else begin

         ; fully implicit backward Euler — Thomas algorithm, O(N) per column.
         ; Unconditionally stable; uses the correct thermal diffusivity k/(c·dz²)
         ; with no artificial halving factor.
         n_inner = tt - 2
         if n_inner gt 0 then begin
            aa = dblarr(n_inner)   ; subdiagonal   a_k = -r_j
            bb = dblarr(n_inner)   ; diagonal      b_k =  1 + 2*r_j
            cc = dblarr(n_inner)   ; superdiagonal c_k = -r_j
            dd = dblarr(n_inner)   ; RHS

            for k=0,n_inner-1 do begin
               j  = k + 1
               rj = rf_dt * cond_fit[j] / (cap_fit[j] * fit_dz[0,j]^2d)
               aa[k] = -rj
               bb[k] = 1.0d + 2.0d * rj
               cc[k] = -rj
               dd[k] = tl_fit[ii[i],j]
            endfor

            ; fold Dirichlet surface and bed values into the RHS
            dd[0]         = dd[0]         - aa[0]         * tl_fit[ii[i],0]
            dd[n_inner-1] = dd[n_inner-1] - cc[n_inner-1] * tl_fit[ii[i],tt-1]

            ; Thomas forward sweep
            for k=1,n_inner-1 do begin
               m     = aa[k] / bb[k-1]
               bb[k] = bb[k] - m * cc[k-1]
               dd[k] = dd[k] - m * dd[k-1]
            endfor

            ; back substitution — write result directly to tl_fit, apply PMP clamp
            tl_fit[ii[i],tt-2] = min([dd[n_inner-1]/bb[n_inner-1], $
                                       (fit_dz[1,tt-2]*0.9d/10.d)*(-0.00742d)])
            for k=n_inner-2,0,-1 do begin
               j = k + 1
               tl_fit[ii[i],j] = min([(dd[k] - cc[k]*tl_fit[ii[i],j+1])/bb[k], $
                                       (fit_dz[1,j]*0.9d/10.d)*(-0.00742d)])
            endfor
         endif

      endelse

      ; ── strain heating (viscous dissipation) ──────────────────────────────────────
      if enable_strain_heating eq 'y' then begin
          ; Rate factor for the dissipation. The flow model calibrates `aflow` per glacier
          ; (Pa^-3 yr^-1) so that the modelled geometry matches the inventory; using the
          ; hardcoded A above instead would heat the ice at a rate inconsistent with the
          ; velocity field the model actually produces -- for Aletsch by a factor 2.4
          ; (calibrated 1.0e-24 vs hardcoded 2.4e-24 Pa^-3 s^-1), and Q goes as tau^(n+1),
          ; so the inconsistency is not small. `aflow` lumps sliding in with deformation,
          ; which is the right total dissipation to first order (tau_b*u_b + internal
          ; shear both scale with the same calibrated flux) even though this term then
          ; distributes all of it as internal shear rather than as basal friction.
          A_sh = A
          if n_elements(aflow) gt 0 then $
             if finite(aflow[0]) then $
                if aflow[0] gt 0 then A_sh = aflow[0] / 3.15576d7   ; yr^-1 -> s^-1
          sh_exp = double(n) + 1.0d   ; = 4 for Glen n=3
          for j = 1, tt-2 do begin
              tau_j = tau_d_sh * (fit_dz[1,j] / (thick[ii[i]] > 1.0d))
              Q_j   = 2.0d * A_sh * tau_j^sh_exp       ; W m⁻³
              dT_j  = Q_j * rf_dt / (dens_fit[j] * cap_fit[j])  ; K per substep
              tl_fit[ii[i],j] = (tl_fit[ii[i],j] + dT_j) < pmp_profile[j]
          endfor
      endif

      ; advection (horizontal and vertical) in the firn/ice layers
      IF enable_advection EQ 'y' THEN BEGIN
         ; Horizontal advection
         ; Bands are ascending (i=0 = terminus, i=ci-1 = top). Skip topmost band: no upglacier source above it.
         IF i LT ci-1 THEN BEGIN
         ; Vertical profile of horizontal velocity: the SIA/Nye shear profile
         ;     u(zeta)/u_surface = 1 - zeta^(n+1),   zeta = depth/H,  n = 3
         ; Ice moves at close to surface speed through most of the column, with the shear
         ; concentrated in a thin layer near the bed.
         ;
         ; REPLACES the previous form vprofile = (1 - j/tt)^4, i.e. relative_height^4, which is
         ; a DIFFERENT function -- it decays immediately with depth instead of near the bed. At
         ; quarter depth it gave 0.32 of the surface speed where the correct profile gives
         ; 0.996; at half depth 0.06 versus 0.94. That under-applied horizontal advection by
         ; more than an order of magnitude over most of the column, including the 10-80 m band
         ; where essentially all glenglat calibration observations sit.
         ;
         ; Two further corrections in the same block:
         ;  (a) zeta is now a true DEPTH fraction (fit_dz[1,j] / resolved column depth), not the
         ;      layer INDEX fraction j/tt. The grid is stretched (1 m / 5 m / 20 m blocks), so
         ;      index 10 of 30 is a third of the way down by count but only 14 m of 259 m by
         ;      depth -- the old form evaluated the profile at the wrong place as well as
         ;      using the wrong shape.
         ;  (b) u[i] is a DEPTH-AVERAGED speed in both paths that supply it (GloGEMflow's
         ;      u_flowmodel = D|ds/dx|/H, glogemflow_coupled.pro STEP 7; and the standalone
         ;      2A/(n+2)*tau_d^n*H estimate at line 47 -- the (n+2) denominator is the
         ;      depth-average normalisation). Scaling it by a profile equal to 1 at the surface
         ;      would apply the depth-averaging twice. The profile is therefore renormalised by
         ;      its own column mean, mean(1 - zeta^(n+1)) = 1 - 1/(n+2) = 0.8 for n=3, so that
         ;      the column mean of vprofile is 1 and vprofile[0] = 1/0.8 = 1.25 recovers the
         ;      surface speed from the depth-averaged input.
         vprofile  = DBLARR(tt)
         col_depth = fit_dz[1,tt-1] > 1.0D            ; resolved column depth [m]
         nye_mean  = 1.0D - 1.0D/(DOUBLE(n) + 2.0D)   ; = 0.8 for n = 3
         FOR j=0,tt-1 DO BEGIN
            zeta = fit_dz[1,j] / col_depth            ; 0 at surface, 1 at bed
            zeta = (zeta > 0.0D) < 1.0D
            vprofile[j] = (1.0D - zeta^(DOUBLE(n) + 1.0D)) / nye_mean
         ENDFOR

         ; Get velocity for current elevation band
         current_vel = u[i]

         ; Upglacier source is the next higher-elevation band (i+1)
         upglacier_idx = i + 1

         ; Timestep in seconds. rf_dt (settings.pro) is already seconds-per-
         ; substep (= seconds-in-a-month / rf_dsc) -- do not multiply by
         ; another month-seconds/rf_dsc factor here, that double-counts the
         ; conversion and inflates dt_seconds by ~rf_dsc*86400*30.5, which
         ; saturates the courant clamp below for almost any nonzero velocity.
         dt_seconds = rf_dt

         ; Horizontal distance to upglacier band, derived from actual elevation spacing and slope
         delta_elev = ABS(elev[ii[i+1]] - elev[ii[i]])  ; vertical elevation step [m]
         delta_elev = MAX([delta_elev, 5.0D])            ; guard against identical elevations
         min_slope_rad = 0.01D * !DTOR  ; minimum slope to avoid division by zero
         local_slope_rad = MAX([slope[ii_perm[i]] * !DTOR, min_slope_rad])
         dx_horiz = delta_elev / TAN(local_slope_rad)
         dx_horiz = dx_horiz < 5000.0D  ; cap at 5 km

         ; Calculate advection coefficient (Courant number)
         courant = current_vel * dt_seconds / (dx_horiz * 365.25D * 24.0D * 3600.0D)

         ; Ensure stability by limiting Courant number
         courant = courant < 0.8

         ; Apply advection to each layer
         FOR j=1,tt-2 DO BEGIN
            ; Scale advection by the vertical velocity profile. The 0.8 clamp is re-applied
            ; PER LAYER, not just to the column-mean courant above: vprofile now peaks at
            ; 1/0.8 = 1.25 at the surface (see the renormalisation note above), so a
            ; column-mean courant already at its 0.8 cap would otherwise reach 1.0 in the
            ; near-surface layers -- the stability boundary of the first-order upwind step,
            ; at which a layer is replaced wholesale by its upglacier neighbour.
            layer_courant = courant * vprofile[j]
            layer_courant = (layer_courant > 0.0D) < 0.8D

            ; Store the temperature before horizontal advection at 10m depth
            temp_before = tl_fit[ii[i],10]  ; Store 10m temperature before horizontal advection

            ; First-order upwind scheme for advection
            tl_fit[ii[i],j] = (1.0D - layer_courant) * tl_fit[ii[i],j] + $
                     layer_courant * tl_fit[ii[upglacier_idx],j]

            ; Store horizontal advection effect (average temperature change at key depths)
            IF advection_write EQ 'y' THEN BEGIN
            IF j EQ 10 THEN adv_horiz_effect[ii[i]] = tl_fit[ii[i],j] - temp_before  ; Effect of horizontal advection at 10m depth
            ENDIF

            ; Ensure temperature doesn't exceed pressure melting point
            tl_fit[ii[i],j] = tl_fit[ii[i],j] < (fit_dz[1,j]*0.9D/10.0D)*(-0.00742D)
         ENDFOR
         ENDIF

         ; Vertical advection
         ; Calculate vertical velocity component
         vertical_vel = DBLARR(tt)

         IF use_flow_model EQ 'y' AND N_ELEMENTS(w_flowmodel) EQ nb THEN BEGIN
            ; Kinematic vertical velocity from GloGEMflow (mass-continuity
            ; surface boundary condition; see glogemflow_coupled.pro STEP 7),
            ; m/year, downward positive. Tied to the same smooth, annually-
            ; resolved SIA state as u_flowmodel -- replaces the heuristics
            ; below when available.
            surface_vertical_vel = w_flowmodel[ii_perm[i]]
         ENDIF ELSE BEGIN
            ; Standalone fallback: used for year 0 (no SIA step has run yet
            ; so w_flowmodel isn't populated) or when use_flow_model='n'.
            IF sno[ii[i]] GT mel[ii[i]] THEN BEGIN
               ; Accumulation area: downward movement
               ; Surface velocity = net accumulation rate
               surface_vertical_vel = MAX([(sno[ii[i]] - mel[ii[i]]), 0.0]) ; m/year, downward positive
            ENDIF ELSE BEGIN
               ; Ablation area: upward movement (emergence velocity)
               ; Simplified emergence velocity estimate based on surface slope and ice velocity
               min_slope_rad = 0.01D * !DTOR  ; Minimum slope to prevent division by zero
               local_slope_rad = MAX([slope[ii_perm[i]] * !DTOR, min_slope_rad])
               current_vel = u[i] ; Get velocity for current elevation band
               emergence_vel = current_vel * TAN(local_slope_rad) ; m/year, upward positive
               ; Convert to our coordinate system (downward positive)
               surface_vertical_vel = -emergence_vel
            ENDELSE
         ENDELSE

         ; Linear decrease of vertical velocity with depth (zero at bed)
         FOR j=0,tt-1 DO BEGIN
            relative_depth = DOUBLE(j) / DOUBLE(tt-1)
            vertical_vel[j] = surface_vertical_vel * (1.0D - relative_depth)
         ENDFOR

         ; ── velocity-field diagnostic ────────────────────────────────────────
         ; Records the advection field the model actually applies: the Nye-shaped
         ; horizontal profile u(zeta) = u_bar (1 - zeta^(n+1)) / (1 - 1/(n+2)) and the
         ; kinematic vertical profile, both per layer. Sits inside the advection block,
         ; so it only fills when enable_advection='y' -- and, like the advection itself,
         ; it skips the topmost band (no upglacier source above it).
         IF firnice_write[2] EQ 'y' THEN BEGIN
            col_depth_d = fit_dz[1,tt-1] > 1.0D
            nye_mean_d  = 1.0D - 1.0D/(DOUBLE(n) + 2.0D)
            FOR j = 0, tt-1 DO BEGIN
               zeta_d = ((fit_dz[1,j] / col_depth_d) > 0.0D) < 1.0D
               fit_u_sum[ye,ii[i],j] = fit_u_sum[ye,ii[i],j] + $
                  u[i] * (1.0D - zeta_d^(DOUBLE(n) + 1.0D)) / nye_mean_d
               fit_w_sum[ye,ii[i],j] = fit_w_sum[ye,ii[i],j] + vertical_vel[j]
            ENDFOR
            fit_vel_cnt[ye,ii[i]] = fit_vel_cnt[ye,ii[i]] + 1d0
            fit_vel_tt[ye,ii[i]]  = tt
         ENDIF

         ; Apply vertical advection (upwind scheme)
         ; Only if vertical velocity is significant
         ; Activation guard. MUST be MAX(ABS(...)), not ABS(MAX(...)): vertical_vel tapers
         ; linearly to exactly 0.0 at the bed, so in the ABLATION zone -- where the whole
         ; profile is negative (upward/emergence) -- MAX(vertical_vel) returns that trailing
         ; 0.0 and ABS(0.0) > 0.1 is false. The entire vertical-advection block was therefore
         ; skipped for every emergence case, and the v_courant < 0 upwind branch below was
         ; unreachable. That silently disabled exactly the mechanism that carries deep cold ice
         ; toward the surface in the ablation zone -- and it was active (enable_advection='y')
         ; in all four Bayesian calibration campaigns run to date.
         IF MAX(ABS(vertical_vel)) GT 0.1D THEN BEGIN
         ; Create temporary array to store updated temperatures
         temp_v = tl_fit[ii[i],*]
         temp_before_v = tl_fit[ii[i],10]  ; Store 10m temperature before vertical advection

         ; Convert rf_dt (already seconds-per-substep) to years directly --
         ; do not multiply by another month-seconds/rf_dsc factor here, see
         ; the matching note on dt_seconds above (same bug, same fix).
         dt_years = rf_dt / (365.25D * 24.0D * 3600.0D)

         ; Apply vertical advection for each layer (except boundaries)
         FOR j=1,tt-2 DO BEGIN
            ; Grid-aware spacing: use the actual center-to-center distance
            ; between donor and receiver layers (from the cumulative depth
            ; array fit_dz[1,*]) rather than this layer's own thickness --
            ; correctly handles the 1m/5m/20m depth-resolution transitions
            ; (~9m, ~59m) instead of mismatching dz across them.
            IF vertical_vel[j] GE 0 THEN BEGIN
               dz = fit_dz[1,j] - fit_dz[1,j-1]     ; downward: distance to layer above
            ENDIF ELSE BEGIN
               dz = fit_dz[1,j+1] - fit_dz[1,j]      ; upward: distance to layer below
            ENDELSE
            dz = dz > 1d-3                            ; guard against zero spacing

            ; Calculate Courant number for vertical advection
            v_courant = vertical_vel[j] * dt_years / dz

            ; Ensure stability
            v_courant = v_courant < 0.8D       ; Limit to 0.8 for stability
            v_courant = MAX([v_courant, -0.8D])

            IF v_courant GE 0 THEN BEGIN
            ; Downward advection (from above)
            IF j GT 1 THEN temp_v[j] = temp_v[j] - v_courant * (temp_v[j] - temp_v[j-1])
            ENDIF ELSE BEGIN
            ; Upward advection (from below)
            IF j LT tt-2 THEN temp_v[j] = temp_v[j] - v_courant * (temp_v[j+1] - temp_v[j])
            ENDELSE
         ENDFOR

         ; Store vertical advection effect at 10m depth
         IF advection_write EQ 'y' THEN BEGIN
            adv_vert_effect[ii[i]] = temp_v[10] - temp_before_v  ; Effect at 10m depth
         ENDIF

         ; Update temperature array with advected values
         FOR j=1,tt-2 DO tl_fit[ii[i],j] = temp_v[j]

         ; Ensure temperatures don't exceed pressure melting point
         FOR j=1,tt-2 DO BEGIN
            IF tl_fit[ii[i],j] GT (fit_dz[1,j]*0.9D/10.0D)*(-0.00742D) THEN $
            tl_fit[ii[i],j] = (fit_dz[1,j]*0.9D/10.0D)*(-0.00742D)
         ENDFOR
         ENDIF
      ENDIF

   endfor

; Fill the unresolved output slots BELOW the bed with the bed value. Previously this line read
;   tl_fit[ii[i],tt-1:total(fit_layers)] = tl_fit[ii[i],tt-2]
; which also overwrote the BED node (tt-1) with the node above it, deleting the geothermal
; warming every month -- the comment "to avoid constant warming from beneath" describes a
; symptom of the old accumulating BC (see the basal boundary condition above), not something
; the gradient BC needs: that form is diagnostic from T[tt-2] each substep and cannot run away.
; The bed node is now preserved and only slots strictly below it are filled.
if tt le total(fit_layers) then tl_fit[ii[i],tt:total(fit_layers)]=tl_fit[ii[i],tt-1]

; universal PMP safety clamp -- see pmp_profile note above
tl_fit[ii[i],*] = tl_fit[ii[i],*] < pmp_profile

; prepare for output
if firnice_write[0] eq 'y' then begin
         ; maximum temperature in layer during one year
   elev_firnicetemp[0,ye,ii[i]]=max([elev_firnicetemp[0,ye,ii[i]],tl_fit[ii[i],2]])  ; 2m
   elev_firnicetemp[1,ye,ii[i]]=max([elev_firnicetemp[1,ye,ii[i]],tl_fit[ii[i],10]]) ; 10m
   elev_firnicetemp[2,ye,ii[i]]=max([elev_firnicetemp[2,ye,ii[i]],tl_fit[ii[i],18]]) ; 50m
   elev_firnicetemp[3,ye,ii[i]]=max([elev_firnicetemp[3,ye,ii[i]],tl_fit[ii[i],total(fit_layers)]]) ; bedrock (last slot; was hardcoded 30)
endif

if firnice_write[2] eq 'y' then begin
         ; full column, accumulated over the months of this year (annual MEAN at write
         ; time). Layers at or below tt-1 are the bed node and the below-bed fill, so
         ; tt is stored to let the reader mask everything the model did not resolve.
   fit_field_sum[ye,ii[i],*] = fit_field_sum[ye,ii[i],*] + reform(tl_fit[ii[i],0:total(fit_layers)-1])
   fit_field_cnt[ye,ii[i]]   = fit_field_cnt[ye,ii[i]] + 1d0
   fit_field_tt[ye,ii[i]]    = tt
   fit_field_th[ye,ii[i]]    = thick[ii[i]]
endif

if firnice_write[1] eq 'y' then begin
   for j=0,n_elements(firnice_profile)-1 do begin
      if ii[i] eq firnice_profile_ind[0,j] then begin
         a=tl_fit[firnice_profile_ind[0,j],1:total(fit_layers)] & a[tt-2:total(fit_layers)-1]=snoval
         printf,fit_prof_lun[j],ye+tran[0],m,a,fo='(2i4,'+string(total(fit_layers),fo='(i2)')+'f8.3)'
      endif
   endfor
endif

endfor

; Store advection effects in the annual output arrays (indexed by year)
IF enable_advection EQ 'y' AND advection_write EQ 'y' THEN BEGIN
   elev_adv_horiz[ye, *] = adv_horiz_effect
   elev_adv_vert[ye, *]  = adv_vert_effect
ENDIF
