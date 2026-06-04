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
; copute ice velocity based on shallow ice approximation
ii_perm=where(gl ne noval,ci)

grav = 9.81   ; acceleration due to gravity [m/s^2]  (not 'g' — that is the glacier loop index)
rho_ice = 917 ; density of ice [kg/m^3]
A = 2.4e-24   ; ice flow law parameter [Pa^-3 s^-1]
n = 3         ; Glen's flow law exponent
THRESHOLD_ICE_VELOCITY_GRADIENT = 1e-4  ; Threshold for ice velocity gradient [year^-1]

; Compute the driving stress (tau_d) and ice velocity (u) for each element in one loop
u     = FLTARR(N_ELEMENTS(gl))  ; Initialize the velocity array with the same number of elements as gl
tau_d = FLTARR(N_ELEMENTS(gl))  ; Initialize the driving stress array with the same number of elements as gl
for i = 0, ci-1 do begin
   ; Calculate driving stress
   tau_d = rho_ice * grav * thick[ii_perm[i]] * SIN(slope[ii_perm[i]] * !DTOR)  ; driving stress in Pa
   ; Calculate depth-averaged velocity
   u[i] = (2 * A / (n + 2)) * tau_d^n * thick[ii_perm[i]] * 365.25 * 24 * 3600  ; ice velocity in m/year
endfor

;*********************
; alternative permeability model based on velocity gradient
du = FLTARR(N_ELEMENTS(u))  ; Initialize the gradient array with the same number of elements as u

; Compute the gradient of the velocity array using finite differences
du[0] = (u[1] - u[0])  ; Forward difference for the first element
FOR i = 1, N_ELEMENTS(u) - 2 DO BEGIN
    du[i] = (u[i+1] - u[i-1]) / 2.0  ; Central difference for the middle elements
ENDFOR
du[N_ELEMENTS(u) - 1] = (u[N_ELEMENTS(u) - 1] - u[N_ELEMENTS(u) - 2])  ; Backward difference for the last element
; PRINT, 'Ice velocity gradient (du) in m/year/m: ', du

; Normalize the velocity gradient to a range of 0 to 1
min_du = MIN(du)
max_du = MAX(du)
normalized_du = (du - min_du) / (max_du - min_du)

; Apply the threshold for ice velocity gradient
permeability = normalized_du
indices = WHERE(normalized_du lt THRESHOLD_ICE_VELOCITY_GRADIENT, count)

; Divide by 2 to allow only 50% permeability
permeability = permeability / 2

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

   for h=0,rf_dsc-1 do begin

      ; heat conduction (vertical) in the firn/ice layers
      for j=1,tt-2 do begin

         tl_fit[ii[i],0]=min([0,tgs[ii[i]]]) ; temperature of topmost layer corresponding to air temperature or melting point!
         ; temperature of bottommost layer warmed up by geothermal heat flux (cumulative energy over one time step over a )
         ttgeot=tl_fit[ii[i],tt-1]+geothermal_flux*(3600*24*30.5/rf_dsc)/cice       ; /fit_dz(0,tt-1) ; unclear how to attribute a layer thickness for collecting flux (1m at the moment...)

         tl_fit[ii[i],tt-1]=min([ttgeot,(fit_dz[1,tt-1]*0.9/10.)*(-0.00742)])    ; cannot be higher than pressure melting point

         te_fit[ii[i],j]=tl_fit[ii[i],j]+((rf_dt*cond_fit[j]/(cap_fit[j])*(tl_fit[ii[i],j-1]-tl_fit[ii[i],j])/fit_dz[0,j]^2.)- $
             (rf_dt*cond_fit[j]/(cap_fit[j])*(tl_fit[ii[i],j]-tl_fit[ii[i],j+1])/fit_dz[0,j]^2.))/2. ; division by 2 to be removed?! result becomes unstable without ?!?
         tl_fit[ii[i],j]=te_fit[ii[i],j]

         ; set back any temperatures to pressure melting point
         if tl_fit[ii[i],j] gt (fit_dz[1,j]*0.9/10.)*(-0.00742) then tl_fit[ii[i],j]=(fit_dz[1,j]*0.9/10.)*(-0.00742)

      endfor

      ; advection (horizontal and vertical) in the firn/ice layers
      IF enable_advection EQ 'y' THEN BEGIN
         ; Horizontal advection
         ; Skip first elevation band (highest) since there's no upglacier source
         IF i GT 0 THEN BEGIN
         ; Calculate vertical profile of horizontal velocity (Nye's approximation)
         vprofile = FLTARR(tt)
         FOR j=0,tt-1 DO BEGIN
            relative_height = 1.0D - (DOUBLE(j) / DOUBLE(tt))  ; 1 at surface, 0 at bed
            vprofile[j] = relative_height^4  ; approximation of velocity profile with n=3
         ENDFOR

         ; Get velocity for current elevation band
         current_vel = u[i]

         ; Get upglacier index (where ice is flowing from)
         upglacier_idx = i - 1

         ; Calculate timestep in seconds
         dt_seconds = rf_dt * 3600.0D * 24.0D * 30.5D / rf_dsc

         ; Calculate the actual horizontal distance based on slope
         band_vertical_spacing = 10.0D  ; Vertical spacing between bands in meters - ADJUST THIS VALUE
         min_slope_rad = 0.01D * !DTOR  ; Minimum slope to prevent division by zero
         local_slope_rad = MAX([slope[ii_perm[i]] * !DTOR, min_slope_rad])
         dx = band_vertical_spacing / TAN(local_slope_rad)
         dx = dx < 1000.0D  ; Cap maximum horizontal distance

         ; Calculate advection coefficient (Courant number)
         courant = current_vel * dt_seconds / (dx * 365.25D * 24.0D * 3600.0D)

         ; Ensure stability by limiting Courant number
         courant = courant < 0.8

         ; Apply advection to each layer
         FOR j=1,tt-2 DO BEGIN
            ; Scale advection by the vertical velocity profile
            layer_courant = courant * vprofile[j]

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

         ; In accumulation area: downward movement due to burial by new snow
         ; In ablation area: upward movement due to emergence velocity
         IF sno[ii[i]] GT mel[ii[i]] THEN BEGIN
         ; Accumulation area: downward movement
         ; Surface velocity = net accumulation rate
         surface_vertical_vel = MAX([(sno[ii[i]] - mel[ii[i]]), 0.0]) ; m/year, downward positive


         ; Linear decrease of vertical velocity with depth (zero at bed)
         FOR j=0,tt-1 DO BEGIN
            relative_depth = DOUBLE(j) / DOUBLE(tt-1)
            vertical_vel[j] = surface_vertical_vel * (1.0D - relative_depth)
         ENDFOR
         ENDIF ELSE BEGIN
         ; Ablation area: upward movement (emergence velocity)
         ; Simplified emergence velocity estimate based on surface slope and ice velocity
         min_slope_rad = 0.01D * !DTOR  ; Minimum slope to prevent division by zero
         local_slope_rad = MAX([slope[ii_perm[i]] * !DTOR, min_slope_rad])
         current_vel = u[i] ; Get velocity for current elevation band
         emergence_vel = current_vel * TAN(local_slope_rad) ; m/year, upward positive

         ; Convert to our coordinate system (downward positive)
         surface_vertical_vel = -emergence_vel

         ; Linear decrease of vertical velocity with depth (zero at bed)
         FOR j=0,tt-1 DO BEGIN
            relative_depth = DOUBLE(j) / DOUBLE(tt-1)
            vertical_vel[j] = surface_vertical_vel * (1.0D - relative_depth)
         ENDFOR
         ENDELSE

         ; Apply vertical advection (upwind scheme)
         ; Only if vertical velocity is significant
         IF ABS(MAX(vertical_vel)) GT 0.1D THEN BEGIN
         ; Create temporary array to store updated temperatures
         temp_v = tl_fit[ii[i],*]
         temp_before_v = tl_fit[ii[i],10]  ; Store 10m temperature before vertical advection

         ; Convert to proper time units
         dt_years = rf_dt * (30.5D/rf_dsc) / 365.25D

         ; Apply vertical advection for each layer (except boundaries)
         FOR j=1,tt-2 DO BEGIN
            ; Calculate vertical grid spacing (might vary with depth in your model)
            dz = fit_dz[0,j]

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

; setting all bedrock temperatures to lowermost computed layer (to avoid constant warming from beneath)
tl_fit[ii[i],tt-1:total(fit_layers)]=tl_fit[ii[i],tt-2]

fit_water=mel[ii[i]]+plg[ii[i]]  ; liquid water available from surface (melt+rain)

if firn_permeability eq 'n' then fit_water = 0  ; check if permeability is disabled, if yes then set infiltrating water to zero

; latent heat release over firn/snow surface (entirely permeable)
if firn[ii[i]] eq 1 then begin

for j=1,tt-2 do begin ; loop through all considered layers from top, and update temperatures
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

; reduce liquid water input through glacier ice using different permeability models
if ice_permeability eq 'y' then begin
   f = permeability[ii[i]] ; velocity gradient based permeability (Janosch model)
   fit_water=fit_water*f   ; reducing amount of water entering glacier ice
   ; f=(slope(ii(i))^2*fact_permeability(0))*(thick(ii(i))*fact_permeability(1)) ; slope based permeability (Matthias model)
endif else begin
   fit_water=fit_water*0 ; no water entering glacier ice
endelse

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

; prepare for output
if firnice_write[0] eq 'y' then begin
         ; maximum temperature in layer during one year
   elev_firnicetemp[0,ye,ii[i]]=max([elev_firnicetemp[0,ye,ii[i]],tl_fit[ii[i],2]])  ; 2m
   elev_firnicetemp[1,ye,ii[i]]=max([elev_firnicetemp[1,ye,ii[i]],tl_fit[ii[i],10]]) ; 10m
   elev_firnicetemp[2,ye,ii[i]]=max([elev_firnicetemp[2,ye,ii[i]],tl_fit[ii[i],18]]) ; 50m
   elev_firnicetemp[3,ye,ii[i]]=max([elev_firnicetemp[3,ye,ii[i]],tl_fit[ii[i],30]]) ; bedrock
endif

if firnice_write[1] eq 'y' then begin
   for j=0,n_elements(firnice_profile)-1 do begin
      if ii[i] eq firnice_profile_ind[0,j] then begin
         a=tl_fit[firnice_profile_ind[0,j],1:total(fit_layers)] & a[tt-2:total(fit_layers)-1]=snoval
         printf,51+j,ye+tran[0],m,a,fo='(2i4,'+string(total(fit_layers),fo='(i2)')+'f8.3)'
      endif
   endfor
endif

endfor

; Return advection effects in the output variables if requested
IF enable_advection EQ 'y' AND advection_write EQ 'y' THEN BEGIN
   elev_adv_horiz = adv_horiz_effect
   elev_adv_vert = adv_vert_effect
ENDIF
