compile_opt idl2

; ; --- Diagnostics before thickness update ---
; print, 'Before thickness update:'
; print, '  Max abs(bal_dx): ', max(abs(bal_dx))
; print, '  Max abs(term3): ', max(abs(term3))
; print, '  Max abs(dt*term3): ', max(abs(dt * term3))
; print, '  Max abs(dt*bal_dx): ', max(abs(dt * bal_dx))
; iws = where(width_surface_dx gt 0, cnt_ws)
; if cnt_ws gt 0 then print, '  Min width_surface_dx: ', min(width_surface_dx[iws])

; print, 'DIAG: max(df_dx)=', max(df_dx), ' max(thick_dx)=', max(thick_dx)
; imax = where(abs(term3) eq max(abs(term3)), count)
; if count gt 0 then print, 'DIAG: term1[imax]=', term1[imax], ' term2[imax]=', term2[imax], ' width_surface_dx[imax]=', width_surface_dx[imax]

for j = 0, 2 do begin
  fun = fltarr(xnum)
  ; Only print during the first two runs (j eq 0 or j eq 1)
  for i = 1, xnum - 1 do begin
    if j le 1 then begin
      ; print, 'i=', i, ' df_dx[i-1]=', df_dx[i - 1], ' df_dx[i]=', df_dx[i], ' sur_dx[i]=', sur_dx[i], ' sur_dx[i-1]=', sur_dx[i - 1]
    endif
    fun[i] = ((df_dx[i - 1] + df_dx[i]) / 2.0) * ((sur_dx[i] - sur_dx[i - 1]) / dx)
    ; if (i le 10) and (j le 1) then print, 'fun[', i, ']=', fun[i]
  endfor

  ; Use a temporary array for thickness update
  thick_dx_new = thick_dx

  for i = 2, xnum - 2 do begin
    ; ; diagnostics to check the balance of the continuity equation -> optional, if needed
    ; if i le 10 then begin
    ; print, 'i=', i, ' thick_dx=', thick_dx[i], ' term3=', term3[i], ' bal_dx=', bal_dx[i], $
    ; ' width_surface_dx=', width_surface_dx[i], ' width_mid_dx=', width_mid_dx[i], ' fluxdiv_dx=', fluxdiv_dx[i]
    ; if j eq 2 then begin
    ; return
    ; endif
    ; endif

    fluxdiv_dx[i] = ((fun[i + 1] - fun[i]) / dx)
    grad_dx[i] = ((sur_dx[i + 1] - sur_dx[i - 1]) / (2 * dx))
    term1[i] = fluxdiv_dx[i] * width_mid_dx[i]
    term2[i] = ((width_mid_dx[i + 1] - width_mid_dx[i - 1]) / (2 * dx)) * grad_dx[i] * df_dx[i]
    term3[i] = (term1[i] + term2[i]) / width_surface_dx[i]
    if ~finite(term3[i]) then term3[i] = 0
    thick_dx_new[i] = thick_dx[i] + (1.0 / 3.0) * dt * (term3[i] + bal_dx[i])
  endfor

  i = where(thick_dx_new lt 0, count)
  if count gt 0 then thick_dx_new[i] = 0
  thick_dx_new[xnum - 1] = thick_dx_new[xnum - 2]

  thick_dx = thick_dx_new

  @variables_renew
endfor

; ; --- Diagnostics after thickness update ---
; print, 'After thickness update:'
; print, '  Max thick_dx: ', max(thick_dx)
; print, '  Max abs(thickness change): ', max(abs(thick_dx_new - thick_dx))

; print, 'DIAG: max(abs(thick_dx_new - thick_dx))=', max(abs(thick_dx_new - thick_dx))
