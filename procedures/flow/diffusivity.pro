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
; open end of the longest grid (flow_domain_end='outflow'): cell 1 is a ghost cell with the
; thickness of cell 2 on the bed continued from cells 3 and 2 (the boundary cells have the bed
; of cell 2), so the end has no thickness step
if n_elements(flow_open_end) gt 0 then if flow_open_end and thick_dx[2] gt 0.0d0 then $
  df_dx[2] = te1 * te2 * thick_dx[2] ^ (nflow + 2) * $
    ((sur_dx[3] - (2.0d0 * bed_dx[2] - bed_dx[3]) - thick_dx[2]) / (2.0d0 * dx)) ^ (nflow - 1) < df_lim
