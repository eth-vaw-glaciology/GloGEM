; ----------------------------------------------------------------------- ;
; ---- GloGEMflow coupled driver (Option A: flowline mass balance)  ---- ;
; ---- Based on Zekollari, Huss & Farinotti (2019)                  ---- ;
; ---- Adapted for coupled GloGEM runs by Janosch Beer (2025)       ---- ;
; ----------------------------------------------------------------------- ;
;
; KEY DESIGN: Mass balance is computed DIRECTLY on the flowline grid.
; No grid conversion needed. No writeback into the feedback loop.
;
; The flow model is self-contained:
; - Geometry lives on the horizontal flowline grid (thick_dx, sur_dx)
; - Mass balance is computed at each flowline cell using sur_dx elevation
; - The SIA advances the geometry by 1 year
; - GloGEM's vertical-band arrays are NOT modified (no writeback)
;
; GloGEM continues to compute its own mass balance on elevation bands
; for diagnostics and output, but this does NOT feed into the flow model.
;
; Volume and area for reporting are computed from the flowline grid.
; ----------------------------------------------------------------------- ;
compile_opt idl2

; ========== STEP 1: ONE-TIME INITIALISATION ========== ;
if n_elements(flow_initialised) eq 0 then begin
  ; ---- Convert vertical bands to horizontal equidistant grid ----
  @procedures/flow/vertical_to_horizontal_grid

  ; ---- Set flow model parameters ----
  @procedures/flow/set_flow_model_parameters

  ; ---- Build trapezoid cross-sections and size arrays ----
  @procedures/flow/constants_counters_initialvalues_sizevariables
  @procedures/flow/initial_geometry

  ; ---- Initialise flow model geometry ----
  dist_dx = horizontal_grid_inputs.dist_dx
  width_dx = horizontal_grid_inputs.width_dx
  bed_dx = bed_dx_init

  ; Initialise cross-section geometry from initial_geometry.pro
  width_surface_dx = width_surface_dx_init
  width_mid_dx = width_mid_dx_init
  width_base_dx = width_base_dx_init
  lambda_dx = lambda_dx_init

  ; ---- Run spin-up: full Zekollari (2019) calibration ----
  ; Calibrates A_flow (volume) + ELA bias (length) via nested loops.
  ; Each iteration: spin-up to SS → historical run tran[0]→survey year.
  ; After return: thick_dx/sur_dx are the model state AT the survey year
  ; (not the SS geometry), ready for the transient projection.
  @procedures/flow/spinup_flowmodel

  ; Initialise time-stepping state
  t = 0l
  time = 0d0
  next_time_mb = 0d0

  ; ---- Initialise flowline history arrays ----
  flow_thick_hist = dblarr(xnum, years)
  flow_sur_hist = dblarr(xnum, years)
  flow_bal_hist = dblarr(xnum, years)
  flow_width_hist = dblarr(xnum, years)

  ; Store initial state
  flow_thick_hist[*, ye] = thick_dx
  flow_sur_hist[*, ye] = sur_dx
  flow_width_hist[*, ye] = width_surface_dx

  ; Compute the flow model's initial volume and area.
  ; From this year onwards, volume/area are computed from the flowline grid.
  ; Pre-flow years keep GloGEM's values (computed from elevation bands).
  ; The small difference at the transition reflects the different geometric
  ; representations (elevation bands vs flowline cross-sections) and is
  ; well within ice thickness uncertainty (~30%, Farinotti et al. 2019).
  ii_init = where(thick_dx gt 0, c_init)
  if c_init gt 0 then begin
    flow_vol_init_m3 = total(thick_dx[ii_init] * width_dx[ii_init] * dx)
    flow_area_init_km2 = total(width_surface_dx[ii_init] * dx) / 1d6
  endif else begin
    flow_vol_init_m3 = 0d0
    flow_area_init_km2 = 0d0
  endelse
  print, 'Flow model initial volume: ', flow_vol_init_m3 / 1d9, ' km3'
  print, 'Flow model initial area:   ', flow_area_init_km2, ' km2'
  print, 'GloGEM volume at survey yr: ', volumes[ye], ' km3'
  print, 'GloGEM area at survey yr:   ', areas[ye], ' km2'

  flow_initialised = 1
  print, 'GloGEMflow coupled: initialised at year ' + $
    strtrim(ye + tran[0], 2) + $
    ' (xnum=' + strtrim(xnum, 2) + ', dx=' + strtrim(dx, 2) + ' m)'
endif

; ========== STEP 2: MAP GloGEM'S MB ONTO FLOWLINE GRID ========== ;
; Interpolate GloGEM's elevation-band MB (bal, m w.e./yr) at each
; flowline cell's current surface elevation (sur_dx), then convert
; to m ice. Replaces the duplicate T-index recalculation in
; flowline_massbal.pro — GloGEM's calibrated MB is the single source.
bal_dx = dblarr(xnum)
ii_gl_bands = where(gl ne noval, n_gl_bands)
if n_gl_bands ge 2 then begin
  bal_we_interp = interpol(bal[ii_gl_bands], elev[ii_gl_bands], sur_dx)
endif else begin
  bal_we_interp = interpol(bal, elev, sur_dx)
endelse
ii_ice_mb = where(thick_dx gt 0, c_ice_mb)
if c_ice_mb gt 0 then bal_dx[ii_ice_mb] = bal_we_interp[ii_ice_mb] / 0.917d0

; ========== STEP 2b: STORE BEGINNING-OF-YEAR STATE (matching dhdt timing) ========== ;
; finalize_annual_massbalance.pro stores volumes[ye] BEFORE retreat.
; We match this: store the flowline state before the SIA advance.
ii_boy = where(thick_dx gt 0, c_boy)
if c_boy gt 0 then begin
  volumes[ye] = total(thick_dx[ii_boy] * width_dx[ii_boy] * dx) / 1d9
  ; Area with fractional terminus/head correction for smooth evolution
  i_t_boy = min(ii_boy)
  i_h_boy = max(ii_boy)
  area_sum_boy = total(width_surface_dx[ii_boy] * dx)
  if i_t_boy lt i_h_boy then begin
    if thick_dx[i_t_boy + 1] gt 0 then begin
      frac_t = (thick_dx[i_t_boy] / thick_dx[i_t_boy + 1]) < 1d0
      area_sum_boy = area_sum_boy + (frac_t - 1d0) * width_surface_dx[i_t_boy] * dx
    endif
    if thick_dx[i_h_boy - 1] gt 0 then begin
      frac_h = (thick_dx[i_h_boy] / thick_dx[i_h_boy - 1]) < 1d0
      area_sum_boy = area_sum_boy + (frac_h - 1d0) * width_surface_dx[i_h_boy] * dx
    endif
  endif
  areas[ye] = (area_sum_boy > 0d0) / 1d6
  mb[ye]    = total(bal_dx[ii_boy] * width_surface_dx[ii_boy] * dx * 0.917d0) / $
              total(width_surface_dx[ii_boy] * dx)
endif else begin
  volumes[ye] = 0d0
  areas[ye]   = 0d0
  mb[ye]      = 0d0
endelse

; ========== STEP 3: ADVANCE FLOW MODEL BY 1 YEAR ========== ;
time_flow = 0d0
year_end_flow = 1d0
iter_flow = 0l
max_iter_flow = 50000l

while (time_flow lt year_end_flow) and (iter_flow lt max_iter_flow) do begin
  ; ---- Adaptive time step (CFL criterion) ----
  if max(df_dx) gt 0 then begin
    dt = dtfactor * (dx ^ 2) / max(df_dx)
  endif else begin
    dt = 0.25d0
  endelse
  dt = dt < 0.25d0 ; cap
  dt = dt > 1d-4 ; floor
  if time_flow + dt gt year_end_flow then dt = year_end_flow - time_flow

  ; ---- Diffusivity ----
  @procedures/flow/diffusivity

  ; ---- Ice thickness update (3-step Runge-Kutta) ----
  @procedures/flow/ice_thickness

  time_flow = time_flow + dt
  iter_flow = iter_flow + 1l

  ; Safety: bail out if thickness blows up
  if max(thick_dx) gt 5000d0 or total(~finite(thick_dx)) gt 0 then begin
    print, 'WARNING: GloGEMflow blow-up at iter=' + strtrim(iter_flow, 2) + $
      ', max(thick_dx)=' + strtrim(max(thick_dx), 2)
    break
  endif
endwhile

if iter_flow ge max_iter_flow then $
  print, 'WARNING: GloGEMflow hit max iterations for year ' + strtrim(ye + tran[0], 2)

; ========== STEP 4: UPDATE GEOMETRY + TERMINUS CLEANUP ========== ;
; Remove thin ice at the glacier terminus.
; The SIA can leave residual ice layers (< 1 grid cell thick) at the
; front because the finite-difference scheme doesn't enforce a sharp
; terminus. We clean this up by removing isolated thin-ice cells
; and ensuring the terminus touches the bed.
;
; Find the terminus: the lowest-index ice cell (closest to tongue)
ii_ice_cleanup = where(thick_dx gt 0, c_cleanup)
if c_cleanup gt 0 then begin
  i_terminus = min(ii_ice_cleanup)  ; lowest ice cell (tongue end)
  i_head = max(ii_ice_cleanup)      ; highest ice cell (head end)
  ; Remove truly residual ice at the terminus and head (< 1 m threshold).
  ; A low threshold means cells only zero out when almost gone, so the
  ; fractional area correction handles the continuous thinning phase.
  ; Using 10 m caused multiple cells to be removed at once in late stages,
  ; producing large discrete steps in area.
  for i_clean = i_terminus, i_head do begin
    if thick_dx[i_clean] lt 1d0 then thick_dx[i_clean] = 0d0 $
    else break
  endfor
  for i_clean = i_head, i_terminus, -1 do begin
    if thick_dx[i_clean] lt 1d0 then thick_dx[i_clean] = 0d0 $
    else break
  endfor
endif

sur_dx = bed_dx + thick_dx
width_surface_dx = width_base_dx + lambda_dx * thick_dx
width_mid_dx = (width_base_dx + width_surface_dx) / 2.0

; ========== STEP 5: COMPUTE VOLUME AND AREA FROM FLOWLINE GRID ========== ;
; These are the authoritative values — computed directly from the flow model.
; No writeback to GloGEM's vertical bands is needed for the feedback loop.
ii_ice_dx = where(thick_dx gt 0, c_ice_dx)
if c_ice_dx gt 0 then begin
  ; Volume: use thick * width_dx * dx (rectangular, consistent with GloGEM)
  ; The trapezoidal cross-section is used internally for SIA flux computation
  ; but volume reporting uses the surface width to match GloGEM's convention.
  flow_vol = total(thick_dx[ii_ice_dx] * width_dx[ii_ice_dx] * dx)
  ; Continuous area: apply fractional contribution to both the terminus
  ; and head cells, based on each cell's thickness relative to its
  ; adjacent interior neighbour. This smooths retreat from both ends.
  i_term_a = min(ii_ice_dx)
  i_head_a = max(ii_ice_dx)
  area_sum = total(width_surface_dx[ii_ice_dx] * dx)
  if i_term_a lt i_head_a then begin
    if thick_dx[i_term_a + 1] gt 0 then begin
      frac_term = (thick_dx[i_term_a] / thick_dx[i_term_a + 1]) < 1d0
      area_sum += (frac_term - 1d0) * width_surface_dx[i_term_a] * dx
    endif
    if thick_dx[i_head_a - 1] gt 0 then begin
      frac_head = (thick_dx[i_head_a] / thick_dx[i_head_a - 1]) < 1d0
      area_sum += (frac_head - 1d0) * width_surface_dx[i_head_a] * dx
    endif
  endif
  flow_area = (area_sum > 0d0) / 1d6  ; m² → km²
  ; Glacier-wide mass balance (m w.e./yr)
  flow_mb = total(bal_dx[ii_ice_dx] * width_surface_dx[ii_ice_dx] * dx * 0.917d0) / $
    total(width_surface_dx[ii_ice_dx] * dx)
endif else begin
  flow_vol = 0d0
  flow_area = 0d0
  flow_mb = 0d0
endelse

; Volume/area/mb are now stored BEFORE the SIA advance (STEP 2b above).
; Post-SIA values retained here for internal diagnostics only.
; volumes[ye] = flow_vol / 1d9
; areas[ye] = flow_area
; mb[ye] = flow_mb

; ========== STEP 6: STORE ANNUAL FLOWLINE HISTORY ========== ;
flow_thick_hist[*, ye] = thick_dx
flow_sur_hist[*, ye] = sur_dx
flow_bal_hist[*, ye] = bal_dx * 0.917d0 ; store as m w.e.
flow_width_hist[*, ye] = width_surface_dx

; Print diagnostic (show scaled values for consistency with GloGEM)
print, 'Flow: vol=' + strtrim(string(volumes[ye], fo = '(f8.3)'), 2) + ' km3' + $
  ' area=' + strtrim(string(areas[ye], fo = '(f7.1)'), 2) + ' km2' + $
  ' mb=' + strtrim(string(mb[ye], fo = '(f7.3)'), 2) + ' m w.e.'

; Increment persistent time counter
t = t + 1l
time = double(ye + 1)
next_time_mb = double(ye + 1)
