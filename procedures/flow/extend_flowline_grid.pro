; -----------------------------------------------------------------------
; extend_flowline_grid
;
; Lengthens the ice-free area in front of the glacier (the downstream end of
; the flowline grid, index 0) by another quarter of the glacier's length, as
; Harry's MATLAB volume_calibration.m does when ice leaves the domain
; (frontal_length + 0.25, at most 1.5). The new cells are exactly those that
; vertical_to_horizontal_grid.pro and initial_geometry.pro build for the
; longer prefrontal area: the prefrontal bed continued with the same slope,
; the prefrontal width, and the boundary condition moved to the new end.
; Every flowline array shifts by ext_n cells.
;
; In : ext_ctx  'spinup'  : grid geometry and bed_dx (the spin-up redoes the attempt)
;               'coupled' : also the flowline state of the running year
;      flow_frontal_length, flow_frontal_length_max, flow_pf_n, flow_pf_len,
;      flow_pf_bed0, flow_pf_slope, dx, xnum
; Out: ext_n    cells added (0: already at the longest grid, nothing changed)
; -----------------------------------------------------------------------
compile_opt idl2

ext_n = 0l
ext_fl = flow_frontal_length + 0.25
if ext_fl le flow_frontal_length_max + 1e-6 then begin
  ext_nnew = long(ceil((flow_pf_len * ext_fl) / dx))
  ext_n = ext_nnew - flow_pf_n
endif

if ext_n gt 0 then begin
  xnum_old = xnum
  ; prefrontal bed and distances as vertical_to_horizontal_grid.pro builds them for the longer area
  ext_pf = reverse(flow_pf_bed0 - (findgen(ext_nnew) * flow_pf_slope * dx))
  ext_x  = findgen(ext_nnew) * dx + flow_pf_len + dx
  ext_ng = xnum_old - flow_pf_n
  ext_hg = horizontal_grid_inputs
  horizontal_grid_inputs = {dist_dx: [ext_hg.dist_dx[0:ext_ng-1], ext_x], $
                            sur_dx: [ext_pf[0:ext_n-1], ext_hg.sur_dx], $
                            width_dx: [fltarr(ext_n), ext_hg.width_dx], $
                            thick_dx: [fltarr(ext_n), ext_hg.thick_dx], $
                            bed_dx: [ext_pf[0:ext_n-1], ext_hg.bed_dx]}

  ; bed as initial_geometry.pro stores it (float); the old boundary cells get their own bed back
  ext_b = float(ext_pf)
  bed_dx_init[0:1] = ext_b[ext_n:ext_n+1]
  bed_dx_init = [ext_b[0:ext_n-1], bed_dx_init]
  bed_dx_init[0] = bed_dx_init[2]
  bed_dx_init[1] = bed_dx_init[2]
  ; prefrontal cross-sections are all alike: copy those of cell 0
  width_surface_dx_init = [replicate(width_surface_dx_init[0], ext_n), width_surface_dx_init]
  width_base_dx_init    = [replicate(width_base_dx_init[0], ext_n), width_base_dx_init]
  width_mid_dx_init     = [replicate(width_mid_dx_init[0], ext_n), width_mid_dx_init]
  lambda_dx_init        = [replicate(lambda_dx_init[0], ext_n), lambda_dx_init]

  xnum = xnum_old + ext_n
  flow_pf_n = ext_nnew
  flow_frontal_length = ext_fl
  bed_dx = bed_dx_init
  dist_dx = horizontal_grid_inputs.dist_dx
  width_dx = horizontal_grid_inputs.width_dx

  if ext_ctx eq 'coupled' then begin
    ; cells 0..ext_n+1 are ice-free: the new cells and the two old boundary cells
    ext_k = lindgen(ext_n + 2)
    ext_z = dblarr(ext_n)
    thick_dx = [ext_z, thick_dx]
    sur_dx   = bed_dx + thick_dx
    width_base_dx    = [replicate(width_base_dx_init[0], ext_n), width_base_dx]
    lambda_dx        = [replicate(lambda_dx_init[0], ext_n), lambda_dx]
    width_surface_dx = width_base_dx + lambda_dx * thick_dx
    width_mid_dx     = (width_base_dx + width_surface_dx) / 2.0
    df_dx = [ext_z, df_dx]
    obs_sur_dx = [ext_z, obs_sur_dx]
    obs_sur_dx[ext_k] = sur_dx[ext_k]
    thick_dx_year_start = [ext_z, thick_dx_year_start]
    sur_dx_year_start   = [ext_z, sur_dx_year_start]
    sur_dx_year_start[ext_k] = sur_dx[ext_k]
    w_boy_dx = [ext_z, w_boy_dx]
    w_boy_dx[ext_k] = width_surface_dx[ext_k]
    if c_boy gt 0 then ii_boy = ii_boy + ext_n

    ; this year's balance on those cells, mapped as in STEP 2 of glogemflow_coupled.pro
    ext_ms = sur_dx[ext_k] < obs_sur_dx[ext_k]
    ext_mz = (ext_ms > elev[mb_srt[0]]) < elev[mb_srt[-1]]
    if n_elements(mb_srt) ge 2 then begin
      ext_bw = interpol(bal[mb_srt], elev[mb_srt], ext_mz)
      ext_aw = interpol(acc[mb_srt], elev[mb_srt], ext_mz)
      ext_rw = interpol(refreeze[mb_srt], elev[mb_srt], ext_mz)
    endif else begin
      ext_bw = dblarr(ext_n + 2) + bal[mb_srt[0]]
      ext_aw = dblarr(ext_n + 2) + acc[mb_srt[0]]
      ext_rw = dblarr(ext_n + 2) + refreeze[mb_srt[0]]
    endelse
    ext_bd = dblarr(ext_n + 2)
    ext_j = where(ext_bw lt 0, ext_c)
    if ext_c gt 0 then ext_bd[ext_j] = ext_bw[ext_j] / 0.9d0
    bal_dx         = [ext_bd, bal_dx[2:*]]
    bal_we_interp  = [ext_bw, bal_we_interp[2:*]]
    acc_we_interp  = [ext_aw, acc_we_interp[2:*]]
    refr_we_interp = [ext_rw, refr_we_interp[2:*]]
    mb_sur_dx      = [ext_ms, mb_sur_dx[2:*]]
    mb_z           = [ext_mz, mb_z[2:*]]

    ; flowline history: the new cells were ice-free
    ext_ny = n_elements(flow_thick_hist[0, *])
    ext_h = dblarr(xnum, ext_ny) & ext_h[ext_n:*, *] = flow_thick_hist & flow_thick_hist = ext_h
    ext_h = dblarr(xnum, ext_ny) & ext_h[ext_n:*, *] = flow_bal_hist   & flow_bal_hist = ext_h
    ext_h = dblarr(xnum, ext_ny) & ext_h[ext_n:*, *] = flow_sur_hist
    ext_h[ext_k, *] = rebin(sur_dx[ext_k], ext_n + 2, ext_ny) & flow_sur_hist = ext_h
    ext_h = dblarr(xnum, ext_ny) & ext_h[ext_n:*, *] = flow_width_hist
    ext_h[0:ext_n-1, *] = rebin(width_surface_dx[0:ext_n-1], ext_n, ext_ny) & flow_width_hist = ext_h
  endif
endif
