; Calculate the diffusivity factor (D) that will be used to solve the
; continuity equation (will be solved as a diffusion type equation in 'ice_thickness.pro')
compile_opt idl2

for i = 1, xnum - 2 do begin
  df[i] = 0.0
  if th[i] ne 0.0 then begin ; if ice is present
    te1 = 2 * aflow / (nflow + 2)
    te2 = (rho * g) ^ (nflow)
    te3 = (th[i]) ^ (nflow + 2)
    te4 = ((sur[i + 1] - sur[i - 1]) / (2.0 * dx)) ^ (nflow - 1)
    df[i] = te1 * te2 * te3 * te4
  endif

  if df[i] gt df_lim then begin ; impose a limit on the diffusivity (is defined in 'constants_counters_initialvalues_sizevariables.pro'; will likely also have to be modified for other regions than the Alps)
    df[i] = df_lim
  endif
endfor

; Add this to both models in diffusivity.pro
print, 'Diffusivity diagnostics:'
print, '  Max th: ', max(th) ; or max(th) for working model
print, '  Max df: ', max(df) ; or max(df) for working model
print, '  te3 (th^5): ', max((th) ^ 5) ; Check if th^5 is exploding
