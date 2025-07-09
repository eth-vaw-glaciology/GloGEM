; Calculate the ice thickness at the next time step through the continuity
; equation. Notice that the diffusivity factor was calculated earlier.
; Evolution towards geometry at next time step occurs in 3 steps
; (updating the geometry and recalculating the flux divergence and
; surface gradient at each of these 'sub-steps')
compile_opt idl2

; Add diagnostic tracking to identify explosion point
print, 'ENTERING ice_thickness, Max th before: ', max(th_x)
print, 'Initial dt: ', dt

for j = 0, 2 do begin ; 3 sub-steps used. Worked well. Maybe not really needed or better solutions --> will have to be tested for other regions in the world

  print, 'Sub-step j=', j, ' Max th: ', max(th_x)

  ; ; Define unstaggered grid for flux (fun)
  fun = fltarr(xnum) ; Flux on unstaggered grid
  for i = 2, xnum - 1 do begin
    fun[i] = ((df_x[i - 1] + df_x[i]) / 2.0) * ((sur[i] - sur[i - 1]) / dx)
  endfor

  ; ; Calculate new ice thickness
  for i = 1, xnum - 2 do begin
    fluxdiv_x[i] = ((fun[i + 1] - fun[i]) / dx)
    grad_x[i] = ((sur[i + 1] - sur[i - 1]) / (2 * dx)) ; surface gradient
    term1[i] = fluxdiv_x[i] * width_mid[i]
    term2[i] = ((width_mid[i + 1] - width_mid[i - 1]) / (2 * dx)) * grad_x[i] * df_x[i]
    term3[i] = (term1[i] + term2[i]) / width_surface[i]
    if ~finite(term3[i]) then term3[i] = 0 ; to avoid problems when width_surface == 0
    th_x[i] = th_x[i] + (1.0 / 3.0) * dt * (term3[i] + bal_x[i])
  endfor

  ; Quick check for extreme values before cleanup
  if max(abs(term3)) gt 1e6 then begin
    print, '  EXTREME term3 detected in sub-step j=', j
    print, '  Max term3: ', max(abs(term3))
    print, '  Max term1: ', max(abs(term1))
    print, '  Max term2: ', max(abs(term2))
    print, '  Max df_x: ', max(df_x)
  endif

  i = where(th_x lt 0, count)
  if count gt 0 then th_x[i] = 0 ; Faster than using 'if' statement in loop
  th_x[xnum - 1] = th_x[xnum - 2] ; Thickness at last grid cell equals the thickness at penultimate grid cell

  ; Detailed diagnostics after thickness update in each sub-step
  print, '  After sub-step j=', j, ' Max th: ', max(th_x)
  print, '  Max thickness change this sub-step: ', max(abs((1.0 / 3.0) * dt * (term3 + bal_x)))
  print, '  Max term3: ', max(abs(term3))
  print, '  Max bal_x: ', max(abs(bal_x))

  ; Check for explosion
  if max(th_x) gt 5000.0 then begin
    print, '*** EXPLOSION DETECTED in sub-step j=', j, ' ***'
    print, '  Max dt*term3: ', max(abs(dt * term3))
    print, '  Max dt*bal_x: ', max(abs(dt * bal_x))
    print, '  Max df_x: ', max(df_x)
    print, '  Max fluxdiv_x: ', max(abs(fluxdiv_x))
    print, '  Max grad_x: ', max(abs(grad_x))
    print, '  Max term1: ', max(abs(term1))
    print, '  Max term2: ', max(abs(term2))
  endif

  ; Call the script to renew various variables at these sub time-steps (surface elevation, ≈width_mid and width_surface)
  @variables_renew
endfor

; Add final diagnostic
print, 'EXITING ice_thickness, Max th after: ', max(th_x)

; ; Add these diagnostics to your ice_thickness.pro
; print, 'Before thickness update:'
; print, '  Max bal_x: ', max(abs(bal_x))
; print, '  Max term3: ', max(abs(term3))
; print, '  Max dt*term3: ', max(abs(dt * term3))
; print, '  Max dt*bal_x: ', max(abs(dt * bal_x))
; print, '  Min width_surface: ', min(width_surface[where(width_surface gt 0)])

; ; After thickness update
; print, 'After thickness update:'
; print, '  Max thickness: ', max(th_x)
; print, '  Thickness change: ', max(abs(dt * (term3 + bal_x)))
