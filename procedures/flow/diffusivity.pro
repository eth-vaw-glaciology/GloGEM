; Calculate the diffusivity factor (D) for the continuity equation
compile_opt idl2

for i = 1, xnum - 2 do begin
  df_x[i] = 0.0
  if th_x[i] ne 0.0 then begin
    te1 = 2 * aflow / (nflow + 2)
    te2 = (rho * g_grav) ^ (nflow)
    te3 = (th_x[i]) ^ (nflow + 2)
    te4 = ((sur_x[i + 1] - sur_x[i - 1]) / (2.0 * dx)) ^ (nflow - 1)
    df_x[i] = te1 * te2 * te3 * te4
  endif
  if df_x[i] gt df_lim then df_x[i] = df_lim
endfor
