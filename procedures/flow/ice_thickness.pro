compile_opt idl2

for j = 0, 2 do begin
  ; Flux per unit width at cell interfaces (fun[i]: between cells i-1 and i)
  fun = dblarr(xnum)
  fun[1:xnum-1] = ((df_dx[0:xnum-2] + df_dx[1:xnum-1]) / 2.0d0) * $
                   ((sur_dx[1:xnum-1] - sur_dx[0:xnum-2]) / dx)
  ; Volume flux through each interface: times the mean cross-section width there
  qfl = dblarr(xnum)
  qfl[1:xnum-1] = fun[1:xnum-1] * (width_mid_dx[0:xnum-2] + width_mid_dx[1:xnum-1]) / 2.0d0

  ; No cell gives more ice than it holds in this sub-step: each outgoing flux is
  ; scaled by the factor of the cell it leaves (qfl[i] > 0: cell i gives to cell i-1,
  ; qfl[i] < 0: cell i-1 gives to cell i). An ice-free cell gives nothing.
  lim_v = thick_dx * width_mid_dx * dx
  lim_o = dblarr(xnum)
  lim_o[1:xnum-1] = lim_o[1:xnum-1] + (qfl[1:xnum-1] > 0.0d0)
  lim_o[0:xnum-2] = lim_o[0:xnum-2] + ((-qfl[1:xnum-1]) > 0.0d0)
  lim_f = dblarr(xnum) + 1.0d0
  ; scale only where the outflow exceeds the ice held (no 0/0 for empty cells)
  lim_d = (1.0d0 / 3.0d0) * dt * lim_o
  lim_j = where(lim_v lt lim_d, lim_c)
  if lim_c gt 0 then lim_f[lim_j] = lim_v[lim_j] / lim_d[lim_j]
  lim_p = qfl[1:xnum-1] gt 0.0d0
  qfl[1:xnum-1] = qfl[1:xnum-1] * (lim_p * lim_f[1:xnum-1] + (1 - lim_p) * lim_f[0:xnum-2])

  thick_dx_new = thick_dx

  ; Thickness change from the flux divergence in flux form (i=2..xnum-2):
  ; what leaves one cell enters its neighbour, so the update conserves ice
  fdiv = dblarr(xnum)
  w = width_surface_dx[2:xnum-2]
  fdiv[2:xnum-2] = (qfl[3:xnum-1] - qfl[2:xnum-2]) / dx / (w > 1d-30) * (w gt 0.0d0)
  bad = where(~finite(fdiv), n_bad)
  if n_bad gt 0 then fdiv[bad] = 0.0d0

  ; Update the trapezoid cross-section area H*(w_base + lambda*H/2) (m2) by the
  ; flux and the balance, then solve it for H: the width grows with H, so a
  ; linear update in H would create or destroy ice. No area left: H = 0.
  tz_wb = width_base_dx[2:xnum-2] & tz_lm = lambda_dx[2:xnum-2] & tz_h = thick_dx[2:xnum-2]
  tz_a0 = tz_h * (tz_wb + tz_lm * tz_h / 2.0d0)
  tz_df = (1.0d0 / 3.0d0) * dt * fdiv[2:xnum-2] * w
  tz_db = (1.0d0 / 3.0d0) * dt * bal_dx[2:xnum-2] * w
  tz_a = tz_a0 + tz_df + tz_db
  tz_n = dblarr(xnum - 3)
  tz_j = where(tz_a gt 0.0d0, tz_c)
  if tz_c gt 0 then tz_n[tz_j] = 2.0d0 * tz_a[tz_j] / $
    (tz_wb[tz_j] + sqrt(tz_wb[tz_j] ^ 2 + 2.0d0 * tz_lm[tz_j] * tz_a[tz_j]))
  thick_dx_new[2:xnum-2] = tz_n

  ; Mass bookkeeping of the coupled run (off during the spin-up)
  if n_elements(flow_budget_on) gt 0 then if flow_budget_on then begin
    ; ice leaving the flowline at its downstream end (interface of cells 1 and 2)
    flow_fa_vol = flow_fa_vol + (1.0d0 / 3.0d0) * dt * qfl[2]
    ; balance actually applied (cross-section area): melt is limited to the area left after the flux step
    fb_m = tz_db
    fb_h = tz_a0 + tz_df
    fb_j = where(fb_h + fb_m lt 0.0d0 and fb_m lt 0.0d0, fb_c)
    if fb_c gt 0 then fb_m[fb_j] = (-fb_h[fb_j]) < 0.0d0 > fb_m[fb_j]
    flow_mb_vol = flow_mb_vol + total(fb_m) * dx
  endif

  neg = where(thick_dx_new lt 0.0d0, n_neg)
  if n_neg gt 0 then thick_dx_new[neg] = 0.0d0
  thick_dx_new[xnum - 1] = thick_dx_new[xnum - 2]

  thick_dx = thick_dx_new

  @procedures/flow/variables_renew
endfor
