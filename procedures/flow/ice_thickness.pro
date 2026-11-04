compile_opt idl2

for j = 0, 2 do begin
  ; Flux at cell interfaces (i=1..xnum-1)
  fun = dblarr(xnum)
  fun[1:xnum-1] = ((df_dx[0:xnum-2] + df_dx[1:xnum-1]) / 2.0d0) * $
                   ((sur_dx[1:xnum-1] - sur_dx[0:xnum-2]) / dx)

  thick_dx_new = thick_dx

  ; Flux divergence, gradient, and thickness update (i=2..xnum-2)
  fluxdiv_dx[2:xnum-2] = (fun[3:xnum-1] - fun[2:xnum-2]) / dx
  grad_dx[2:xnum-2]    = (sur_dx[3:xnum-1] - sur_dx[1:xnum-3]) / (2.0d0 * dx)
  term1[2:xnum-2] = fluxdiv_dx[2:xnum-2] * width_mid_dx[2:xnum-2]
  term2[2:xnum-2] = ((width_mid_dx[3:xnum-1] - width_mid_dx[1:xnum-3]) / (2.0d0 * dx)) * $
                     grad_dx[2:xnum-2] * df_dx[2:xnum-2]
  w = width_surface_dx[2:xnum-2]
  term3[2:xnum-2] = (term1[2:xnum-2] + term2[2:xnum-2]) / (w > 1d-30)
  term3[2:xnum-2] *= (w gt 0.0d0)
  bad = where(~finite(term3[2:xnum-2]), n_bad)
  if n_bad gt 0 then term3[bad + 2] = 0.0d0

  thick_dx_new[2:xnum-2] = thick_dx[2:xnum-2] + $
                            (1.0d0 / 3.0d0) * dt * (term3[2:xnum-2] + bal_dx[2:xnum-2])

  neg = where(thick_dx_new lt 0.0d0, n_neg)
  if n_neg gt 0 then thick_dx_new[neg] = 0.0d0
  thick_dx_new[xnum - 1] = thick_dx_new[xnum - 2]

  thick_dx = thick_dx_new

  @procedures/flow/variables_renew
endfor
