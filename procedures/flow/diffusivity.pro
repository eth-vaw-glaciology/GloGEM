; Calculate the diffusivity factor (D) for the continuity equation
compile_opt idl2

for i = 1, xnum - 2 do begin
  df_dx[i] = 0.0
  if thick_dx[i] ne 0.0 then begin
    te1 = 2 * aflow / (nflow + 2)
    te2 = (rho * g_grav) ^ (nflow)
    te3 = (thick_dx[i]) ^ (nflow + 2)
    te4 = ((sur_dx[i + 1] - sur_dx[i - 1]) / (2.0 * dx)) ^ (nflow - 1)
    df_dx[i] = te1 * te2 * te3 * te4
  endif
  if df_dx[i] gt df_lim then df_dx[i] = df_lim
endfor
