; Calculate the diffusivity factor (D) that will be used to solve the
; continuity equation (will be solved as a diffusion type equation in 'ice_thickness.pro')
compile_opt idl2

; Diagnostic variables
max_df_before = 0.0
max_df_after = 0.0
problem_indices = []

; print, 'Diffusivity calculation diagnostics:'
; print, 'Constants: aflow=', aflow, ' nflow=', nflow, ' rho=', rho, ' g_grav=', g_grav
; print, 'df_lim=', df_lim

for i = 1, xnum - 2 do begin
  df_x[i] = 0.0
  if th_x[i] ne 0.0 then begin ; if ice is present
    te1 = 2 * aflow / (nflow + 2)
    te2 = (rho * g_grav) ^ (nflow)
    te3 = (th_x[i]) ^ (nflow + 2)
    te4 = ((sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)) ^ (nflow - 1)
    df_x[i] = te1 * te2 * te3 * te4

    ; Track maximum before limiting
    if df_x[i] gt max_df_before then max_df_before = df_x[i]

    ; Diagnostic for extreme values
    if df_x[i] gt 1e7 then begin
      ; print, 'Extreme diffusivity at i=', i
      ; print, '  th_x[i]=', th_x[i]
      ; print, '  surface gradient=', (sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)
      ; print, '  sur_x values: [', sur_x[i - 1], ', ', sur_x[i], ', ', sur_x[i + 1], ']'
      ; print, '  te1=', te1
      ; print, '  te2=', te2
      ; print, '  te3=', te3
      ; print, '  te4=', te4
      ; print, '  df_x[i]=', df_x[i]
      problem_indices = [problem_indices, i]
    endif
  endif

  if df_x[i] gt df_lim then begin ; impose a limit on the diffusivity
    ; if df_x[i] gt 1e7 then print, 'Limiting df_x[', i, '] from ', df_x[i], ' to ', df_lim
    df_x[i] = df_lim
  endif

  ; Track maximum after limiting
  if df_x[i] gt max_df_after then max_df_after = df_x[i]
endfor

; CRITICAL DIAGNOSTIC: Track what causes diffusivity spike
if max_df_before gt 1e8 then begin
  print, '*** DIFFUSIVITY SPIKE DETECTED! ***'
  extreme_idx = where(df_x eq df_lim) ; Find points that hit the limit
  if n_elements(extreme_idx) gt 0 then begin
    i = extreme_idx[0]
    print, '  Location i=', i
    print, '  th_x[i]=', th_x[i]
    surf_grad = (sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)
    print, '  surface gradient=', surf_grad
    print, '  sur_x values: [', sur_x[i - 1], ', ', sur_x[i], ', ', sur_x[i + 1], ']'

    ; Recalculate components to see which exploded
    te1_debug = 2 * aflow / (nflow + 2)
    te2_debug = (rho * g_grav) ^ (nflow)
    te3_debug = (th_x[i]) ^ (nflow + 2)
    te4_debug = ((sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)) ^ (nflow - 1)

    print, '  te1 (flow factor)=', te1_debug
    print, '  te2 (rho*g)^n=', te2_debug
    print, '  te3 (thickness^5)=', te3_debug
    print, '  te4 (gradient^2)=', te4_debug
    print, '  df_x before limit=', te1_debug * te2_debug * te3_debug * te4_debug
  endif
endif

; Summary diagnostics
; print, 'Max diffusivity before limiting:', max_df_before
; print, 'Max diffusivity after limiting:', max_df_after
; print, 'Max ice thickness:', max(th_x)
; print, 'Max surface elevation:', max(sur_x)
; print, 'Number of extreme diffusivity points:', n_elements(problem_indices)

; Check for problematic surface gradients
gradients = fltarr(xnum - 2)
for i = 1, xnum - 2 do begin
  if th_x[i] ne 0 then gradients[i - 1] = (sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)
endfor
valid_gradients = gradients[where(gradients ne 0)]
if n_elements(valid_gradients) gt 0 then begin
  ; print, 'Surface gradient range: min=', min(valid_gradients), ' max=', max(valid_gradients)
endif

; Add this to both models in diffusivity.pro
print, 'Diffusivity diagnostics:'
print, '  Max th: ', max(th_x) ; or max(th) for working model
print, '  Max df: ', max(df_x) ; or max(df) for working model
print, '  te3 (th^5): ', max((th_x) ^ 5) ; Check if th^5 is exploding
