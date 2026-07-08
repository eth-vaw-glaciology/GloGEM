; -----------------------------------------------------------------------
; ---- GloGEMflow spin-up: full Zekollari et al. (2019) calibration
; -----------------------------------------------------------------------
; Implements the two-loop calibration from Appendix A of Zekollari,
; Huss & Farinotti (2019), The Cryosphere.
;
; Structure:
;   OUTER LOOP  — ELA-bias / glacier-length calibration (max 6 iters)
;     INNER LOOP  — A_flow / glacier-volume calibration (max 6 iters)
;       Phase A: spin-up to steady state with mean SMB + ela_bias
;       Phase B: historical transient tran[0] → survey year
;                using year-by-year SMB polynomials from baly
;       → check volume at survey year; adjust A_flow
;     → check glacier length; adjust ela_bias
;
; After convergence: thick_dx / sur_dx hold the model state at the
; survey year from the historical run — NOT the steady-state geometry.
; This eliminates the spurious lag in early-period retreat that occurs
; when starting from the steady-state geometry directly.
;
; Inputs (from GloGEM scope):
;   baly[years, nb]  — annual SMB per band (m w.e.)
;   elev[nb]         — band surface elevations
;   tran[0]          — simulation start year
;   ye               — current year index (survey year = tran[0]+ye-1)
;   volumes[ye-1]    — GloGEM volume at survey year (km3)
;
; Inputs (from flow model scope):
;   xnum, dx, bed_dx, width_dx
;   width_surface_dx_init, width_mid_dx_init, width_base_dx_init
;   lambda_dx_init, horizontal_grid_inputs
;   dtfactor, df_lim
;
; Outputs:
;   thick_dx, sur_dx, width_surface_dx  — model state at survey year
;   spinup_aflow                        — calibrated A_flow (Pa-3 yr-1)
;   spinup_ela_bias                     — calibrated ELA bias (m)
; -----------------------------------------------------------------------
compile_opt idl2
spinup_t0 = systime(1)   ; wall-clock start time (seconds)

; ====================================================================
; STEP 1: Compute 1961-1990 mean SMB polynomial
; ====================================================================
print, '=== GloGEMflow spin-up: computing 1961-1990 mean SMB ==='

ref_start_yr  = 1961
ref_end_yr    = 1990
ye_start_mean = (ref_start_yr - tran[0]) > 0
ye_end_mean   = (ref_end_yr   - tran[0]) < (ye - 1)

if ye_start_mean gt ye_end_mean then begin
  print, 'Note: 1961-1990 not in window; using tran[0]-' + strtrim(tran[0]+ye-1,2) + ' as reference'
  ye_start_mean = 0
  ye_end_mean   = ye - 1
endif
n_ref_yrs = ye_end_mean - ye_start_mean + 1

; Collect valid bands (majority of reference years have ice)
elev_ref = []
bal_ref  = []
for i = 0, nb - 1 do begin
  n_valid = 0
  bsum    = 0d0
  for yy = ye_start_mean, ye_end_mean do begin
    if baly[yy, i] gt -90 then begin
      n_valid = n_valid + 1
      bsum    = bsum + baly[yy, i]
    endif
  endfor
  if n_valid gt (n_ref_yrs / 2) then begin
    elev_ref = [elev_ref, double(elev[i])]
    bal_ref  = [bal_ref,  bsum / double(n_valid)]
  endif
endfor

n_pts = n_elements(elev_ref)
print, 'SMB polynomial fit: ', n_pts, ' valid bands'
if n_pts lt 1 then begin
  print, 'WARNING: Glacier ' + strtrim(id[gg[g]], 2) + $
    ': no valid SMB bands for polynomial fit — disabling flow model for this glacier.'
  use_flow_model_gl = 'n'
  goto, glogemflow_skip
endif
; Degrade polynomial degree for small glaciers with few elevation bands.
; Degree-2 needs 3+ points; degree-1 (linear) needs 2; degree-0 (constant) needs 1.
poly_order = 2 < (n_pts - 1)
if poly_order lt 2 then $
  print, 'Warning: ' + strtrim(n_pts,2) + ' valid bands — using degree-' + strtrim(poly_order,2) + ' polynomial'

; Center elevations before fitting to improve Vandermonde matrix conditioning.
; All polynomial evaluations use (z - z_center) consistently.
z_center    = mean(elev_ref)
elev_norm   = elev_ref - z_center
bal_ref_ice = bal_ref / 0.917d0
smb_coeffs  = poly_fit(elev_norm, bal_ref_ice, poly_order, /double)
smb_c = smb_coeffs[0]   ; constant
smb_b = 0d0              ; linear  (zero if degree < 1)
smb_a = 0d0              ; quadratic (zero if degree < 2)
if poly_order ge 1 then smb_b = smb_coeffs[1]
if poly_order ge 2 then smb_a = smb_coeffs[2]

; ELA from polynomial (in centred coordinates, then shift back)
discrim = smb_b^2 - 4d0 * smb_a * smb_c
if discrim ge 0 and smb_a ne 0 then $
  ela_ref = z_center + (-smb_b + sqrt(discrim)) / (2d0 * smb_a) $
else if smb_b ne 0 then $
  ela_ref = z_center - smb_c / smb_b $
else $
  ela_ref = 3000d0
print, 'Mean SMB polynomial ELA: ', ela_ref, ' m  (z_center=', z_center, ' m)'
print, 'Coefficients (centred): a=', smb_a, '  b=', smb_b, '  c=', smb_c

; ====================================================================
; STEP 2: Precompute year-by-year SMB polynomials for historical run
; ====================================================================
; Phase B starts from the END of the reference climate period (1990)
; and runs to the survey year — matching Zekollari (2019), who uses a
; 1990 steady state.  This means Phase B is ~13 years (1990→2003) not
; 63 years (1940→2003).  The short Phase B limits the overshoot that
; Phase A must provide, allowing convergence within ±500 m ELA bias.
;
; We still compute polynomials for the full window tran[0]→survey year
; (needed if ref_end_yr is before tran[0]), but Phase B only uses the
; sub-window from hist_b0 to ye-1.
hist_b0 = long((ref_end_yr > tran[0]) - tran[0])  ; first Phase B year (index into baly)
hist_n  = ye - hist_b0                             ; number of Phase B years

hist_smb_a = dblarr(ye)
hist_smb_b = dblarr(ye)
hist_smb_c = dblarr(ye)
for yy = 0, ye - 1 do begin
  elev_h = []
  bal_h  = []
  for i = 0, nb - 1 do begin
    if baly[yy, i] gt -90 then begin
      elev_h = [elev_h, double(elev[i])]
      bal_h  = [bal_h,  baly[yy, i] / 0.917d0]
    endif
  endfor
  if n_elements(elev_h) ge 3 then begin
    cf = poly_fit(elev_h - z_center, bal_h, 2, /double)  ; centred
    hist_smb_c[yy] = cf[0]
    hist_smb_b[yy] = cf[1]
    hist_smb_a[yy] = cf[2]
  endif else begin
    hist_smb_c[yy] = smb_c   ; fallback to mean polynomial
    hist_smb_b[yy] = smb_b
    hist_smb_a[yy] = smb_a
  endelse
endfor
print, 'Historical SMB polynomials computed: ', ye, ' years (' + $
  strtrim(tran[0],2) + '-' + strtrim(tran[0]+ye-1,2) + ')'
print, 'Phase B window: ', hist_n, ' years (' + $
  strtrim(tran[0]+hist_b0,2) + '-' + strtrim(tran[0]+ye-1,2) + ')'

; ====================================================================
; STEP 3: Reference geometry
; ====================================================================
obs_sur_dx   = double(horizontal_grid_inputs.sur_dx)
obs_thick_dx = double(horizontal_grid_inputs.thick_dx)

; Observed glacier length (ice cells in inventory geometry)
ii_obs_l    = where(obs_thick_dx gt 0, c_obs_l)
obs_len_m   = double(c_obs_l) * dx
print, 'Observed length: ', obs_len_m / 1000d0, ' km  (', c_obs_l, ' ice cells)'

; Target volume: GloGEM volume at survey year
vol_target  = volumes[ye - 1] * 1d9   ; m3
print, 'Volume target (', tran[0]+ye-1, '): ', vol_target / 1d9, ' km3'

ela_bias_max = 500d0   ; m — Zekollari (2019) original limit; physically unrealistic beyond this

; ====================================================================
; STEP 3b: Initial ELA bias — zero-balance over observed glacier
; ====================================================================
ii_obs_ice = where(obs_thick_dx gt 0, c_obs_ice)
ela_bias_init = 0d0
if c_obs_ice gt 0 then begin
  z_obs     = obs_sur_dx[ii_obs_ice]
  w_obs     = double(width_dx[ii_obs_ice])
  mb_obs    = smb_a * (z_obs - z_center)^2 + smb_b * (z_obs - z_center) + smb_c
  mb_mean   = total(mb_obs * w_obs) / total(w_obs)
  z_mean    = total(z_obs * w_obs) / total(w_obs)
  dsmb_dz   = 2d0 * smb_a * z_mean + smb_b
  if abs(dsmb_dz) gt 1d-12 then $
    ela_bias_init = (mb_mean / dsmb_dz) < ela_bias_max > (-ela_bias_max)
  print, 'Mean SMB over observed glacier (ela_bias=0): ', mb_mean, ' m ice/yr'
  print, 'Initial ELA bias estimate: ', ela_bias_init, ' m'
endif

; ====================================================================
; STEP 4: Calibration parameters
; ====================================================================
spinup_nyears  = 5000l
spinup_ss_crit = 0.01d0   ; SS criterion: dV/V < 0.01 %/yr
vol_prec       = 0.01d0   ; volume tolerance: 1 %
len_prec       = 0.01d0   ; length tolerance: 1 % (floor; adapted below to grid spacing)
max_vol_iter   = 6
max_len_iter   = 15

; Adaptive time step: halve spinup_dtfactor on blow-up before touching A_flow.
; Matches MATLAB volume_calibration.m: dtfactor halved down to 5e-2 before giving up.
spinup_dtfactor = dtfactor
dtfactor_min    = 0.05d0
max_dt_retry    = 4l       ; 0.75→0.375→0.1875→0.09375→(below min)

; Initial guesses
aflow_init      = aflow          ; save default (from set_flow_model_parameters.pro)
aflow_guess     = aflow
ela_bias        = ela_bias_init

; Storage for calibration history
spinup_len_tbl  = dblarr(max_len_iter, 3)   ; [ela_bias, length_m, aflow]
n_len_done = 0

; ====================================================================
; OUTER LOOP: ELA-bias / length calibration
; ====================================================================
len_converged = 0

for len_iter = 0, max_len_iter - 1 do begin

  print, ''
  print, '--- Length iter ', len_iter+1, '  ELA_bias=', ela_bias, ' m ---'

  ; ----------------------------------------------------------------
  ; INNER LOOP: A_flow / volume calibration
  ; ----------------------------------------------------------------
  spinup_vol_tbl  = dblarr(max_vol_iter, 2)   ; [aflow, vol_at_survey]
  n_vol_done = 0
  vol_converged = 0

  for vol_iter = 0, max_vol_iter - 1 do begin
    print, '  Vol iter ', vol_iter+1, '  A_flow=', aflow_guess

    ; -------- Phase A: spin-up to steady state --------
    thick_dx         = dblarr(xnum)
    sur_dx           = double(bed_dx)
    width_surface_dx = double(width_surface_dx_init)
    width_mid_dx     = double(width_mid_dx_init)
    width_base_dx    = double(width_base_dx_init)
    lambda_dx        = double(lambda_dx_init)
    df_dx            = dblarr(xnum)
    aflow            = aflow_guess

    spinup_vol_prev  = 0d0
    ss_reached       = 0
    phase_a_failed   = 0

    for spinup_yr = 0l, spinup_nyears - 1 do begin
      ; SMB polynomial with ELA bias (vectorized, centred coordinates)
      z_eff = (sur_dx - ela_bias) - z_center
      ii_cap = where(z_eff gt ((obs_sur_dx - ela_bias) - z_center) and obs_thick_dx gt 0, c_cap)
      if c_cap gt 0 then z_eff[ii_cap] = (obs_sur_dx[ii_cap] - ela_bias) - z_center
      bal_dx = smb_a * z_eff^2 + smb_b * z_eff + smb_c
      ii_zero = where(thick_dx le 0 and bal_dx lt 0, c_zero)
      if c_zero gt 0 then bal_dx[ii_zero] = 0d0

      ; SIA time step
      spinup_t = 0d0
      while spinup_t lt 1d0 do begin
        if max(df_dx) gt 0 then $
          dt = spinup_dtfactor * (dx^2) / max(df_dx) $
        else $
          dt = 0.25d0
        dt = (dt < 0.25d0) > 1d-4
        if spinup_t + dt gt 1d0 then dt = 1d0 - spinup_t
        @procedures/flow/diffusivity
        @procedures/flow/ice_thickness
        spinup_t = spinup_t + dt
        if max(thick_dx) gt 5000d0 or total(~finite(thick_dx)) gt 0 then begin
          phase_a_failed = 1
          break
        endif
      endwhile
      if phase_a_failed then break

      sur_dx = bed_dx + thick_dx
      width_surface_dx = width_base_dx + lambda_dx * thick_dx
      width_mid_dx = (width_base_dx + width_surface_dx) / 2.0

      ; Steady-state check every 10 years
      if (spinup_yr mod 10) eq 0 and spinup_yr gt 0 then begin
        ii_ss = where(thick_dx gt 0, c_ss)
        ss_vol = c_ss gt 0 ? total(thick_dx[ii_ss] * width_mid_dx[ii_ss] * dx) : 0d0
        if spinup_vol_prev gt 0 then begin
          if abs(ss_vol - spinup_vol_prev) / spinup_vol_prev * 100d0 lt spinup_ss_crit then begin
            print, '    SS yr ', spinup_yr, '  vol=', ss_vol/1d9, ' km3'
            ss_reached = 1
            break
          endif
          ; Early exit: volume exceeds target and is still growing — this A_flow won't converge
          if spinup_yr ge 200 and ss_vol gt vol_target and ss_vol gt spinup_vol_prev then begin
            print, '    Phase A non-convergent: vol=', ss_vol/1d9, ' km3 growing, target=', $
              vol_target/1d9, ' km3 --- forcing exit'
            ss_reached = 1
            break
          endif
        endif
        spinup_vol_prev = ss_vol
      endif
    endfor

    if phase_a_failed then begin
      if spinup_dtfactor gt dtfactor_min then begin
        spinup_dtfactor = (spinup_dtfactor * 0.5d0) > dtfactor_min
        print, '    Phase A blow-up --- halving dtfactor to ' + strtrim(spinup_dtfactor, 2)
      endif else begin
        print, '    Phase A blow-up (dtfactor at min) --- halving A_flow'
        aflow_guess = (aflow_guess * 0.5d0) > 1d-20
      endelse
      continue
    endif
    if ~ss_reached then print, '    WARNING: SS not reached after ', spinup_nyears, ' yr'

    ; -------- Phase B: historical transient run --------
    ; Save Phase A end state so we can restore it for dtfactor retry
    thick_dx_after_a     = thick_dx
    sur_dx_after_a       = sur_dx
    wsurf_after_a        = width_surface_dx
    wmid_after_a         = width_mid_dx

    print, '    Historical run: ', tran[0]+hist_b0, ' -> ', tran[0]+ye-1
    phase_b_passed = 0

    for dt_b_retry = 0l, max_dt_retry do begin
      if dt_b_retry gt 0 then begin
        ; Restore Phase A endpoint and retry with the newly halved spinup_dtfactor
        thick_dx         = thick_dx_after_a
        sur_dx           = sur_dx_after_a
        width_surface_dx = wsurf_after_a
        width_mid_dx     = wmid_after_a
      endif
      phase_b_failed = 0

      for yy = 0, hist_n - 1 do begin
        ha = hist_smb_a[hist_b0 + yy]
        hb = hist_smb_b[hist_b0 + yy]
        hc = hist_smb_c[hist_b0 + yy]
        z_h = sur_dx - z_center
        ii_hcap = where(z_h gt (obs_sur_dx - z_center) and obs_thick_dx gt 0, c_hcap)
        if c_hcap gt 0 then z_h[ii_hcap] = obs_sur_dx[ii_hcap] - z_center
        bal_dx = ha * z_h^2 + hb * z_h + hc
        ii_hzero = where(thick_dx le 0 and bal_dx lt 0, c_hzero)
        if c_hzero gt 0 then bal_dx[ii_hzero] = 0d0
        ii_hnan = where(~finite(bal_dx), c_hnan)
        if c_hnan gt 0 then bal_dx[ii_hnan] = 0d0

        hist_t = 0d0
        while hist_t lt 1d0 do begin
          if max(df_dx) gt 0 then $
            dt = spinup_dtfactor * (dx^2) / max(df_dx) $
          else $
            dt = 0.25d0
          dt = (dt < 0.25d0) > 1d-4
          if hist_t + dt gt 1d0 then dt = 1d0 - hist_t
          @procedures/flow/diffusivity
          @procedures/flow/ice_thickness
          hist_t = hist_t + dt
          if max(thick_dx) gt 5000d0 or total(~finite(thick_dx)) gt 0 then begin
            phase_b_failed = 1
            break
          endif
        endwhile
        if phase_b_failed then break

        sur_dx = bed_dx + thick_dx
        width_surface_dx = width_base_dx + lambda_dx * thick_dx
        width_mid_dx = (width_base_dx + width_surface_dx) / 2.0
      endfor

      if NOT phase_b_failed then begin
        phase_b_passed = 1
        break
      endif

      if spinup_dtfactor gt dtfactor_min then begin
        spinup_dtfactor = (spinup_dtfactor * 0.5d0) > dtfactor_min
        print, '    Phase B blow-up --- halving dtfactor to ' + strtrim(spinup_dtfactor, 2)
      endif else begin
        break  ; dtfactor at minimum, still failing → let outer handler change A_flow
      endelse
    endfor

    if NOT phase_b_passed then begin
      print, '    Phase B blow-up (dtfactor at min) --- halving A_flow'
      aflow_guess = (aflow_guess * 0.5d0) > 1d-20
      continue
    endif

    ; -------- Check volume at survey year --------
    ii_sv = where(thick_dx gt 0, c_sv)
    survey_vol = c_sv gt 0 ? total(thick_dx[ii_sv] * width_mid_dx[ii_sv] * dx) : 0d0

    spinup_vol_tbl[vol_iter, 0] = aflow_guess
    spinup_vol_tbl[vol_iter, 1] = survey_vol
    n_vol_done = vol_iter + 1

    vol_err_pct = (survey_vol - vol_target) / vol_target * 100d0
    print, '    Survey vol=', survey_vol/1d9, ' km3  target=', vol_target/1d9, '  err=', vol_err_pct, '%'

    if abs(survey_vol - vol_target) / vol_target lt vol_prec then begin
      print, '    Volume converged!'
      vol_converged = 1
      break
    endif

    ; Estimate next A_flow guess
    if vol_iter eq 0 then begin
      if survey_vol gt 0 then $
        aflow_guess = aflow_guess * (vol_target / survey_vol)^(-4d0) $
      else $
        aflow_guess = aflow_guess * 0.1d0
    endif else begin
      a1 = spinup_vol_tbl[vol_iter-1, 0]
      v1 = spinup_vol_tbl[vol_iter-1, 1]
      a2 = spinup_vol_tbl[vol_iter, 0]
      v2 = spinup_vol_tbl[vol_iter, 1]
      if v2 ne v1 then $
        aflow_guess = a1 + (vol_target - v1) * (a2 - a1) / (v2 - v1) $
      else $
        aflow_guess = aflow_guess * 0.5d0
    endelse
    aflow_guess = (aflow_guess > 1d-20) < 1d-12

  endfor ; volume calibration loop

  if ~vol_converged then begin
    print, '  Volume did not converge --- using best result'
    best_err = 1d30
    best_idx = 0
    for i = 0, n_vol_done - 1 do begin
      err = abs(spinup_vol_tbl[i, 1] - vol_target)
      if err lt best_err then begin
        best_err = err
        best_idx = i
      endif
    endfor
    print, '  Best A_flow=', spinup_vol_tbl[best_idx, 0], '  vol=', spinup_vol_tbl[best_idx, 1]/1d9, ' km3'
    aflow_guess = spinup_vol_tbl[best_idx, 0]
  endif

  spinup_aflow = aflow_guess

  ; -------- Check glacier length --------
  ii_len = where(thick_dx gt 0, c_len)
  mod_len_m = double(c_len) * dx
  len_ratio = obs_len_m gt 0 ? mod_len_m / obs_len_m : 1d0

  spinup_len_tbl[len_iter, 0] = ela_bias
  spinup_len_tbl[len_iter, 1] = mod_len_m
  spinup_len_tbl[len_iter, 2] = spinup_aflow
  n_len_done = len_iter + 1

  print, '  Length: mod=', mod_len_m/1000d0, ' km  obs=', obs_len_m/1000d0, ' km  ratio=', len_ratio

  ; Adaptive precision: must be at least 1.5 grid cells wide so the
  ; discrete length can actually satisfy the criterion.
  len_prec_eff = len_prec > (1.5d0 * dx / (obs_len_m > 1d0))

  if abs(len_ratio - 1d0) le len_prec_eff then begin
    print, '  Length calibration converged (prec=', len_prec_eff*100d0, '%)'
    len_converged = 1
    break
  endif

  if len_iter eq max_len_iter - 1 then begin
    ; Max iterations reached — pick the best
    best_err = 1d30
    best_idx = 0
    for i = 0, n_len_done - 1 do begin
      err = abs(spinup_len_tbl[i, 1] - obs_len_m)
      if err lt best_err then begin
        best_err = err
        best_idx = i
      endif
    endfor
    ela_bias    = spinup_len_tbl[best_idx, 0]
    aflow_guess = spinup_len_tbl[best_idx, 2]
    print, '  Length max iters --- best ELA_bias=', ela_bias, '  A_flow=', aflow_guess
    break
  endif

  ; Estimate next ela_bias
  if len_iter eq 0 then begin
    if len_ratio lt 1d0 then begin
      ela_bias    = ela_bias - 10d0
      aflow_guess = spinup_aflow + 0.2d-16
    endif else begin
      ela_bias    = ela_bias + 10d0
      aflow_guess = (spinup_aflow - 0.2d-16) > 1d-17
    endelse
  endif else begin
    e1 = spinup_len_tbl[len_iter-1, 0]
    l1 = spinup_len_tbl[len_iter-1, 1]
    e2 = spinup_len_tbl[len_iter, 0]
    l2 = spinup_len_tbl[len_iter, 1]
    if l2 ne l1 then $
      ela_bias = e1 + (obs_len_m - l1) * (e2 - e1) / (l2 - l1) $
    else $
      ela_bias = ela_bias + (len_ratio gt 1d0 ? 10d0 : -10d0)
    if abs(l2 - l1) gt 1d0 then $
      aflow_guess = spinup_len_tbl[len_iter-1, 2] + $
        (obs_len_m - l1) / (l2 - l1) * (spinup_len_tbl[len_iter, 2] - spinup_len_tbl[len_iter-1, 2]) $
    else $
      aflow_guess = spinup_aflow
    aflow_guess = (aflow_guess > 1d-20) < 1d-12
  endelse

  if abs(ela_bias) gt ela_bias_max then begin
    print, '  WARNING: ELA bias hit limit (', ela_bias, ' m) --- stopping length calibration'
    break
  endif

endfor ; length calibration loop

; ====================================================================
; STEP 5: Finalise
; ====================================================================
aflow = spinup_aflow
spinup_ela_bias = ela_bias

sur_dx = bed_dx + thick_dx
width_surface_dx = width_base_dx + lambda_dx * thick_dx
width_mid_dx = (width_base_dx + width_surface_dx) / 2.0

ii_fin = where(thick_dx gt 0, c_fin)
final_vol  = c_fin gt 0 ? total(thick_dx[ii_fin] * width_mid_dx[ii_fin] * dx) : 0d0
final_area = c_fin gt 0 ? total(width_surface_dx[ii_fin] * dx) / 1d6 : 0d0

print, ''
print, '=== Spin-up complete ==='
print, 'Spin-up wall time   : ', systime(1) - spinup_t0, ' s'
print, 'Calibrated A_flow   : ', spinup_aflow, ' Pa^-3 yr^-1'
print, 'ELA bias            : ', spinup_ela_bias, ' m'
print, 'Effective dtfactor  : ', spinup_dtfactor
print, 'Final volume        : ', final_vol / 1d9, ' km3  (target=', vol_target/1d9, ')'
print, 'Volume error        : ', (final_vol - vol_target) / vol_target * 100d0, ' %'
print, 'Final area          : ', final_area, ' km2'
print, 'Final length        : ', double(c_fin) * dx / 1000d0, ' km  (obs=', obs_len_m/1000d0, ')'
print, 'Max thickness       : ', max(thick_dx), ' m'
if hist_n lt 13 then $
  print, 'Note: historical run only covers ', hist_n, ' yr (' + $
    strtrim(tran[0],2) + '-' + strtrim(tran[0]+hist_n-1,2) + ').'

@procedures/flow/write_spinup_stats
