; ---------------------------------
; This file loads the modeled SMB data computed by GloGEM & converts it to
; the horizontally equidistant grid using either interpolation or polynomial fit.
; ---------------------------------
compile_opt idl2

bal_dz = bal ; get mass balance in m w.e. from main GloGEM model

; SMB calculation method flag (set this in your main parameter file)
; smb_method_flag = 0: Use interpolation (original method)
; smb_method_flag = 1: Use polynomial fit (smooth alternative)
if n_elements(smb_method_flag) eq 0 then smb_method_flag = 0

; ===== METHOD 0: INTERPOLATION (Original) =====
if smb_method_flag eq 0 then begin
  ; print, 'Using interpolation method for SMB'

  surf_elev_eq = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2

  ; Find valid (non-missing) data points
  valid_idx = where(bal_dz ne -99.0, count)

  if count gt 0 then begin
    ; Use only valid data for interpolation
    bal_valid = bal_dz[valid_idx]
    surf_elev_valid = surf_elev_eq[valid_idx]

    ; Interpolate using only valid data
    bal_dx = interpol(bal_valid, surf_elev_valid, sur_dx)

    ; Set SMB to zero for elevations outside glacier range
    min_glacier_elev = min(surf_elev_valid)
    max_glacier_elev = max(surf_elev_valid)
    no_ice_idx = where(sur_dx lt min_glacier_elev or sur_dx gt max_glacier_elev, count_no_ice)
    if count_no_ice gt 0 then bal_dx[no_ice_idx] = 0.0
  endif else begin
    ; Glacier has completely disappeared
    ; print, 'Warning: Glacier has completely disappeared'
    bal_dx = replicate(0.0, n_elements(sur_dx))
  endelse
endif

; ===== METHOD 1: POLYNOMIAL FIT (Smooth Alternative) =====
if smb_method_flag eq 1 then begin
  ; print, 'Using polynomial fit method for SMB'

  surf_elev_eq = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2

  ; Find valid (non-missing) data points
  valid_idx = where(bal_dz ne -99.0, count)

  if count gt 3 then begin ; Need at least 4 points for cubic fit
    bal_valid = bal_dz[valid_idx]
    surf_elev_valid = surf_elev_eq[valid_idx]

    ; Polynomial order (2 = quadratic, 3 = cubic)
    poly_order = 2 < (count - 1) ; Don't exceed available data points

    ; Fit polynomial to elevation-SMB relationship
    poly_coeffs = poly_fit(surf_elev_valid, bal_valid, poly_order, /double)

    ; Calculate polynomial SMB for each grid point
    bal_dx = fltarr(n_elements(sur_dx))
    for i = 0, n_elements(sur_dx) - 1 do begin
      ; Use current surface elevation but cap for stability
      elev_for_smb = sur_dx[i]

      ; Cap elevation to reasonable range (prevent feedback instability)
      min_elev = min(surf_elev_valid)
      max_elev = max(surf_elev_valid)
      elev_capped = (elev_for_smb > min_elev) < max_elev

      ; Calculate SMB using polynomial
      smb_value = 0.0
      for j = 0, poly_order do begin
        smb_value += poly_coeffs[j] * elev_capped ^ j
      endfor
      bal_dx[i] = smb_value

      ; Prevent positive SMB where no ice exists (like original GloGEMflow)
      if thick_dx[i] eq 0 and bal_dx[i] gt 0 then bal_dx[i] = 0.0

      ; Set SMB to zero outside original glacier elevation range
      if sur_dx[i] lt min_elev or sur_dx[i] gt max_elev then bal_dx[i] = 0.0
    endfor

    ; Print polynomial coefficients for debugging
    ; print, 'Polynomial coefficients (order ', poly_order, '):', poly_coeffs
    ; print, 'Elevation range used:', min_elev, ' to ', max_elev, ' m'
  endif else if count gt 0 then begin
    ; Too few points for polynomial, use mean value
    ; print, 'Too few points for polynomial fit, using mean SMB'
    mean_smb = mean(bal_dz[valid_idx])
    bal_dx = replicate(mean_smb, n_elements(sur_dx))

    ; Apply same constraints as above
    surf_elev_valid = surf_elev_eq[valid_idx]
    min_elev = min(surf_elev_valid)
    max_elev = max(surf_elev_valid)
    for i = 0, n_elements(sur_dx) - 1 do begin
      if thick_dx[i] eq 0 and bal_dx[i] gt 0 then bal_dx[i] = 0.0
      if sur_dx[i] lt min_elev or sur_dx[i] gt max_elev then bal_dx[i] = 0.0
    endfor
  endif else begin
    ; Glacier has completely disappeared
    ; print, 'Warning: Glacier has completely disappeared'
    bal_dx = replicate(0.0, n_elements(sur_dx))
  endelse
endif

; ===== COMMON POST-PROCESSING =====
; Additional safety checks regardless of method
for i = 0, n_elements(bal_dx) - 1 do begin
  ; Check for non-finite values
  if ~finite(bal_dx[i]) then bal_dx[i] = 0.0

  ; Cap extreme values (safety net)
  if abs(bal_dx[i]) gt 50.0 then begin ; 50 m/year is very extreme
    ; print, 'Warning: Extreme SMB value ', bal_dx[i], ' at point ', i, ' - capping'
    bal_dx[i] = bal_dx[i] > (-50.0) < 50.0
  endif
endfor
