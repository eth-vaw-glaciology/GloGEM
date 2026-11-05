; -----------------------------------------------------------------------
; flow_timestep
;
; Adaptive time step (CFL criterion) for ice_thickness.pro, used by the
; coupled run and by both phases of the spin-up.
;
;   dt = dt_fac * dx^2 / D_stab,  0.0001 <= dt <= 0.25 yr
;
; D_stab is the larger of max(D) and the largest effective diffusivity of
; the flux-form update, (w+ D+ + w- D-) / (2 w_s) per cell: the diffusivity
; and mean cross-section width at the cell's two interfaces over its surface
; width. A narrow cell between wide cross-sections has a larger effective
; diffusivity than D itself. Before the first diffusivity call (all D zero)
; df_lim stands in for D.
;
; In:  dt_fac, df_dx, width_mid_dx, width_surface_dx, xnum, dx, df_lim
; Out: dt
; -----------------------------------------------------------------------
compile_opt idl2

ts_d = max(df_dx)
if ts_d gt 0 then begin
  ; D times mean cross-section width at each interface (ts_q[k-1]: cells k-1 and k)
  ts_q = (df_dx[0:xnum-2] + df_dx[1:xnum-1]) * (width_mid_dx[0:xnum-2] + width_mid_dx[1:xnum-1]) / 4d0
  ; effective diffusivity of the updated cells 2..xnum-2
  ts_w = width_surface_dx[2:xnum-2]
  ts_e = (ts_q[1:xnum-3] + ts_q[2:xnum-2]) / (2d0 * (ts_w > 1d-30)) * (ts_w gt 0d0)
  ts_d = ts_d > max(ts_e, /nan)
  dt = dt_fac * (dx ^ 2) / ts_d
endif else begin
  dt = dt_fac * (dx ^ 2) / df_lim
endelse
dt = (dt < 0.25d0) > 1d-4
