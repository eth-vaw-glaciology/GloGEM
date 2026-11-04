; Calculate the diffusivity factor (D) for the continuity equation
compile_opt idl2

df_dx[*] = 0.0d0
te1 = 2.0d0 * aflow / (nflow + 2)
te2 = (rho * g_grav) ^ nflow
ii  = 1 + where(thick_dx[1:xnum-2] ne 0.0d0, n_ice)
if n_ice gt 0 then begin
  te3       = thick_dx[ii] ^ (nflow + 2)
  te4       = ((sur_dx[ii + 1] - sur_dx[ii - 1]) / (2.0d0 * dx)) ^ (nflow - 1)
  df_dx[ii] = te1 * te2 * te3 * te4
  df_dx[ii] = df_dx[ii] < df_lim   ; element-wise cap at df_lim
endif
