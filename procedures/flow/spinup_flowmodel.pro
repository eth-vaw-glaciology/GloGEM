; -----------------------------------------------------------------------
; ---- GloGEMflow spin-up: steady state + A_flow calibration
; -----------------------------------------------------------------------
; Based on Zekollari, Huss & Farinotti (2019).
;
; Procedure (following the MATLAB version):
; 1. Compute 1961-1990 mean SMB from GloGEM's baly array
; 2. Fit a 2nd-order polynomial: bal = a*elev^2 + b*elev + c
; 3. Start from zero ice on the bedrock
; 4. Run the SIA to steady state with constant (mean) SMB
; 5. Calibrate A_flow so that steady-state volume matches observed
; 6. Store the calibrated steady-state geometry
;
; Inputs (from GloGEM scope):
; baly[years, nb] — annual balance per band per year (m w.e.)
; elev[nb] — surface elevation of bands
; gl[nb] — glacier mask
; tran[0] — start year
; noval, snoval — no-value flags
;
; Inputs (from flow model scope):
; xnum, dx — horizontal grid
; bed_dx — bedrock elevation
; width_surface_dx_init, width_mid_dx_init, width_base_dx_init
; lambda_dx_init — cross-section parameters
; obs_vol_flowlinemodel — observed volume (m³)
; df_lim — diffusivity cap
; dtfactor — CFL factor
;
; Outputs:
; thick_dx, sur_dx — steady-state geometry (overwrites initial)
; spinup_aflow — calibrated deformation-sliding factor
; -----------------------------------------------------------------------
compile_opt idl2

print, '=== GloGEMflow spin-up: computing 1961-1990 mean SMB ==='

; ---- STEP 1: Compute 1961-1990 mean SMB per elevation band ----
; baly[ye, band] stores annual balance in m w.e.
; Years 1961-1990 correspond to ye = 11..40 (since tran[0] = 1950)
ye_start_mean = 11 ; 1961
ye_end_mean = 40 ; 1990

; Collect valid (ice-covered) bands and their mean SMB
elev_valid = []
bal_valid = []
for i = 0, nb - 1 do begin
  ; Average over 1961-1990
  bal_mean_i = mean(baly[ye_start_mean : ye_end_mean, i])
  ; Only use bands that had ice (bal != snoval for most years)
  n_valid_yrs = 0
  for yy = ye_start_mean, ye_end_mean do begin
    if baly[yy, i] gt -90 then n_valid_yrs = n_valid_yrs + 1
  endfor
  if n_valid_yrs gt 15 then begin ; at least half the years had ice
    ; Recompute mean excluding snoval years
    bal_sum = 0d0
    for yy = ye_start_mean, ye_end_mean do begin
      if baly[yy, i] gt -90 then bal_sum = bal_sum + baly[yy, i]
    endfor
    bal_mean_i = bal_sum / double(n_valid_yrs)
    elev_valid = [elev_valid, double(elev[i])]
    bal_valid = [bal_valid, bal_mean_i]
  endif
endfor

n_pts = n_elements(elev_valid)
print, 'SMB polynomial fit: ', n_pts, ' valid elevation bands'

; ---- STEP 2: Fit 2nd-order polynomial: bal = a*elev^2 + b*elev + c ----
; Convert from m w.e. to m ice (flow model uses ice equivalent)
bal_valid_ice = bal_valid / 0.917d0

; Fit polynomial (IDL's poly_fit returns coefficients [c, b, a])
smb_coeffs = poly_fit(elev_valid, bal_valid_ice, 2, /double)
smb_c = smb_coeffs[0] ; constant term
smb_b = smb_coeffs[1] ; linear term
smb_a = smb_coeffs[2] ; quadratic term

; Compute ELA from the polynomial (where bal = 0)
; a*elev^2 + b*elev + c = 0 → elev = (-b ± sqrt(b²-4ac)) / 2a
discrim = smb_b ^ 2 - 4d0 * smb_a * smb_c
if discrim ge 0 and smb_a ne 0 then begin
  ela_spinup = (-smb_b + sqrt(discrim)) / (2d0 * smb_a)
endif else begin
  ; Linear fallback
  if smb_b ne 0 then ela_spinup = -smb_c / smb_b else ela_spinup = 3000d0
endelse

print, 'SMB polynomial (m ice/yr): ', smb_a, ' * elev^2 + ', smb_b, ' * elev + ', smb_c
print, 'ELA from polynomial: ', ela_spinup, ' m'

; Compute mean SMB over observed glacier
bal_mean_obs = 0d0
w_sum = 0d0
for i = 0, xnum - 1 do begin
  if horizontal_grid_inputs.thick_dx[i] gt 0 then begin
    b_i = smb_a * horizontal_grid_inputs.sur_dx[i] ^ 2 + $
      smb_b * horizontal_grid_inputs.sur_dx[i] + smb_c
    bal_mean_obs = bal_mean_obs + b_i * width_surface_dx_init[i]
    w_sum = w_sum + width_surface_dx_init[i]
  endif
endfor
if w_sum gt 0 then bal_mean_obs = bal_mean_obs / w_sum
print, 'Mean SMB over observed glacier: ', bal_mean_obs, ' m ice/yr'

; Observed volume (target for calibration)
vol_obs = obs_vol_flowlinemodel
print, 'Observed volume (target): ', vol_obs / 1d9, ' km3'

; ---- STEP 3: Define the steady-state run function ----
; This runs the flow model from zero ice to steady state with constant SMB.
; Returns the steady-state volume.

; Spin-up parameters
spinup_nyears = 5000l ; max years
spinup_ss_crit = 0.01d0 ; steady state: volume change < 0.01%/yr
spinup_vol_prec = 0.01d0 ; volume match within 1%
spinup_max_iter = 6 ; max calibration iterations

; Initial guess for A_flow (deformation-sliding factor)
; The IDL version uses aflow in set_flow_model_parameters.pro
; We'll modify it and re-run
aflow_guess = aflow ; use the default from set_flow_model_parameters

; Store the observed geometry for later comparison
obs_sur_dx = horizontal_grid_inputs.sur_dx
obs_thick_dx = horizontal_grid_inputs.thick_dx

print, ''
print, '=== Starting A_flow calibration ==='
print, 'Initial A_flow guess: ', aflow_guess

; Arrays to store calibration results [aflow, volume]
calib_aflow = dblarr(spinup_max_iter)
calib_vol = dblarr(spinup_max_iter)
n_calib = 0

; ---- STEP 4: Calibration loop ----
for calib_iter = 0, spinup_max_iter - 1 do begin
  print, ''
  print, '--- Calibration iteration ', calib_iter + 1, ' ---'
  print, 'A_flow = ', aflow_guess

  ; Set the current A_flow
  aflow = aflow_guess

  ; Reset geometry: start from zero ice
  thick_dx = dblarr(xnum)
  sur_dx = double(bed_dx)
  width_surface_dx = width_surface_dx_init ; reset widths
  width_mid_dx = width_mid_dx_init
  width_base_dx = width_base_dx_init
  lambda_dx = lambda_dx_init

  ; Reset diffusivity
  df_dx = fltarr(xnum)

  ; Run to steady state
  spinup_vol_prev = 0d0
  spinup_converged = 0

  for spinup_yr = 0l, spinup_nyears - 1 do begin
    ; ---- Apply SMB polynomial ----
    bal_dx = dblarr(xnum)
    for i = 0, xnum - 1 do begin
      ; Use modelled surface elevation for SMB-elevation feedback
      mb_elev = sur_dx[i]
      ; Safety cap: don't let modelled surface exceed observed
      ; (prevents runaway thickening, as in MATLAB version)
      if mb_elev gt obs_sur_dx[i] and obs_thick_dx[i] gt 0 then $
        mb_elev = obs_sur_dx[i]
      bal_dx[i] = smb_a * mb_elev ^ 2 + smb_b * mb_elev + smb_c
      ; On ice-free cells: negative SMB is meaningless (cant melt rock) - set to zero
      if thick_dx[i] le 0 and bal_dx[i] lt 0 then bal_dx[i] = 0d0
    endfor

    ; ---- Advance flow model by 1 year ----
    spinup_time = 0d0
    while spinup_time lt 1d0 do begin
      ; Adaptive time step
      if max(df_dx) gt 0 then begin
        dt = dtfactor * (dx ^ 2) / max(df_dx)
      endif else begin
        dt = 0.25d0
      endelse
      dt = dt < 0.25d0
      dt = dt > 1d-4
      if spinup_time + dt gt 1d0 then dt = 1d0 - spinup_time

      ; Diffusivity
      @procedures/flow/diffusivity

      ; Ice thickness (3-step Runge-Kutta)
      @procedures/flow/ice_thickness

      spinup_time = spinup_time + dt

      ; Blow-up check
      if max(thick_dx) gt 5000d0 or total(~finite(thick_dx)) gt 0 then begin
        print, 'WARNING: Spin-up blow-up at year ', spinup_yr, ' max=', max(thick_dx)
        goto, spinup_failed
      endif
    endwhile

    ; Update geometry
    sur_dx = bed_dx + thick_dx
    width_surface_dx = width_base_dx + lambda_dx * thick_dx
    width_mid_dx = (width_base_dx + width_surface_dx) / 2.0

    ; Check steady state every 10 years
    if (spinup_yr mod 10) eq 0 and spinup_yr gt 0 then begin
      ii_ice = where(thick_dx gt 0, c_ice)
      if c_ice gt 0 then begin
        spinup_vol = total(thick_dx[ii_ice] * width_dx[ii_ice] * dx)
      endif else spinup_vol = 0d0

      if spinup_vol_prev gt 0 then begin
        vol_change_pct = abs(spinup_vol - spinup_vol_prev) / spinup_vol_prev * 100d0
        if vol_change_pct lt spinup_ss_crit then begin
          print, 'Steady state reached at year ', spinup_yr, $
            ' vol=', spinup_vol / 1d9, ' km3 (change=', vol_change_pct, '%)'
          spinup_converged = 1
          break
        endif
      endif
      spinup_vol_prev = spinup_vol
    endif
  endfor ; spinup years

  ; Compute final volume
  ii_ice = where(thick_dx gt 0, c_ice)
  if c_ice gt 0 then begin
    spinup_vol = total(thick_dx[ii_ice] * width_dx[ii_ice] * dx)
  endif else spinup_vol = 0d0

  ; Store calibration result
  calib_aflow[calib_iter] = aflow_guess
  calib_vol[calib_iter] = spinup_vol
  n_calib = calib_iter + 1

  print, 'Steady-state volume: ', spinup_vol / 1d9, ' km3'
  print, 'Observed volume:     ', vol_obs / 1d9, ' km3'
  print, 'Volume error:        ', (spinup_vol - vol_obs) / vol_obs * 100d0, ' %'

  ; Check if volume is within tolerance
  if abs(spinup_vol - vol_obs) / vol_obs lt spinup_vol_prec then begin
    print, 'Volume calibration converged!'
    print, 'Calibrated A_flow = ', aflow_guess
    goto, spinup_done
  endif

  ; ---- Estimate next A_flow guess ----
  if calib_iter eq 0 then begin
    ; First iteration: use the V ~ A^(-1/4) scaling
    if spinup_vol gt 0 then begin
      vol_ratio = vol_obs / spinup_vol
      aflow_guess = aflow_guess * (vol_ratio) ^ (-4d0)
    endif else begin
      aflow_guess = aflow_guess * 0.1d0 ; reduce if no ice formed
    endelse
  endif else begin
    ; Subsequent iterations: linear interpolation between last two points
    a1 = calib_aflow[calib_iter - 1]
    v1 = calib_vol[calib_iter - 1]
    a2 = calib_aflow[calib_iter]
    v2 = calib_vol[calib_iter]
    if v2 ne v1 then begin
      ; Linear interpolation to find aflow where vol = vol_obs
      aflow_guess = a1 + (vol_obs - v1) * (a2 - a1) / (v2 - v1)
    endif else begin
      aflow_guess = aflow_guess * 0.5d0
    endelse
  endelse

  ; Safety: keep A_flow in reasonable range
  aflow_guess = (aflow_guess > 1d-20) < 1d-12

  goto, spinup_continue
  spinup_failed:
  print, 'Spin-up failed for A_flow = ', aflow_guess
  ; Try with smaller A_flow (less flow, more stable)
  aflow_guess = aflow_guess * 0.1d0
  spinup_continue:
endfor ; calibration iterations

print, 'WARNING: Volume calibration did not converge after ', spinup_max_iter, ' iterations'
print, 'Using best result...'
; Use the iteration with smallest volume error
best_err = 1d30
best_idx = 0
for i = 0, n_calib - 1 do begin
  err = abs(calib_vol[i] - vol_obs)
  if err lt best_err then begin
    best_err = err
    best_idx = i
  endif
endfor
; Re-run with the best A_flow to get the geometry
aflow_guess = calib_aflow[best_idx]
aflow = aflow_guess
; (would need to re-run here, but for now just use current state)

spinup_done:

; Store the calibrated A_flow
spinup_aflow = aflow

; Final geometry is in thick_dx, sur_dx (from the last steady-state run)
; Update cross-section geometry
sur_dx = bed_dx + thick_dx
width_surface_dx = width_base_dx + lambda_dx * thick_dx
width_mid_dx = (width_base_dx + width_surface_dx) / 2.0

; Report final state
ii_ice = where(thick_dx gt 0, c_ice)
if c_ice gt 0 then begin
  final_vol = total(thick_dx[ii_ice] * width_dx[ii_ice] * dx)
  final_area = total(width_surface_dx[ii_ice] * dx) / 1d6
endif else begin
  final_vol = 0d0
  final_area = 0d0
endelse

print, ''
print, '=== Spin-up complete ==='
print, 'Calibrated A_flow: ', spinup_aflow
print, 'Final volume:      ', final_vol / 1d9, ' km3'
print, 'Observed volume:   ', vol_obs / 1d9, ' km3'
print, 'Volume error:      ', (final_vol - vol_obs) / vol_obs * 100d0, ' %'
print, 'Final area:        ', final_area, ' km2'
print, 'Max thickness:     ', max(thick_dx), ' m'
