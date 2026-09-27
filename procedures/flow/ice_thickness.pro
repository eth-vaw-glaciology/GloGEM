compile_opt idl2

for j = 0, 2 do begin
  ; Flux per unit width at cell interfaces (fun[i]: between cells i-1 and i)
  fun = dblarr(xnum)
  fun[1:xnum-1] = ((df_dx[0:xnum-2] + df_dx[1:xnum-1]) / 2.0d0) * $
                   ((sur_dx[1:xnum-1] - sur_dx[0:xnum-2]) / dx)
  ; Volume flux through each interface: times the mean cross-section width there
  qfl = dblarr(xnum)
  qfl[1:xnum-1] = fun[1:xnum-1] * (width_mid_dx[0:xnum-2] + width_mid_dx[1:xnum-1]) / 2.0d0

  thick_dx_new = thick_dx

  ; Thickness change from the flux divergence in flux form (i=2..xnum-2):
  ; what leaves one cell enters its neighbour, so the update conserves ice
  fdiv = dblarr(xnum)
  w = width_surface_dx[2:xnum-2]
  fdiv[2:xnum-2] = (qfl[3:xnum-1] - qfl[2:xnum-2]) / dx / (w > 1d-30) * (w gt 0.0d0)
  bad = where(~finite(fdiv), n_bad)
  if n_bad gt 0 then fdiv[bad] = 0.0d0

  thick_dx_new[2:xnum-2] = thick_dx[2:xnum-2] + $
                            (1.0d0 / 3.0d0) * dt * (fdiv[2:xnum-2] + bal_dx[2:xnum-2])

  ; Mass bookkeeping of the coupled run (off during the spin-up)
  if n_elements(flow_budget_on) gt 0 then if flow_budget_on then begin
    ; ice leaving the flowline at its downstream end (interface of cells 1 and 2)
    flow_fa_vol = flow_fa_vol + (1.0d0 / 3.0d0) * dt * qfl[2]
    ; balance actually applied: melt is limited to the ice left after the flux step
    fb_m = (1.0d0 / 3.0d0) * dt * bal_dx[2:xnum-2]
    fb_h = thick_dx[2:xnum-2] + (1.0d0 / 3.0d0) * dt * fdiv[2:xnum-2]
    fb_j = where(fb_h + fb_m lt 0.0d0 and fb_m lt 0.0d0, fb_c)
    if fb_c gt 0 then fb_m[fb_j] = (-fb_h[fb_j]) < 0.0d0 > fb_m[fb_j]
    flow_mb_vol = flow_mb_vol + total(fb_m * width_surface_dx[2:xnum-2]) * dx
  endif

  neg = where(thick_dx_new lt 0.0d0, n_neg)
  if n_neg gt 0 then thick_dx_new[neg] = 0.0d0
  thick_dx_new[xnum - 1] = thick_dx_new[xnum - 2]

  thick_dx = thick_dx_new

  @procedures/flow/variables_renew
endfor
