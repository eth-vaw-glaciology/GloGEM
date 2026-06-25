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
  ; After return: thick_dx/sur_dx are the model state AT the survey year.
  ;
  ; The calibrated parameters (spinup_aflow, spinup_ela_bias) and the
  ; resulting glacier state (thick_dx) are SSP-independent — they depend
  ; only on the inventory geometry and the 1961-1990 SMB climatology.
  ; Cache them to disk after the first SSP so subsequent SSPs can skip
  ; the ~5-minute calibration loop entirely.
  spinup_cache_dir  = dirres + 'spinup_cache/'
  spinup_cache_file = spinup_cache_dir + strtrim(id[gg[g]], 2) + '_spinup.sav'

  if file_test(spinup_cache_file) then begin
    restore, spinup_cache_file   ; restores: spinup_aflow, spinup_ela_bias, thick_dx,
                                 ;           sur_dx, width_surface_dx, width_mid_dx,
                                 ;           width_base_dx, lambda_dx
    aflow = spinup_aflow
    if n_elements(spinup_dtfactor) gt 0 then begin
      dtfactor = spinup_dtfactor
      if abs(spinup_dtfactor - 0.75d0) gt 0.01d0 then $
        print, 'dtfactor set to ' + strtrim(dtfactor, 2) + ' (from spinup cache)'
    endif
    print, 'Spin-up cache hit: ' + strtrim(id[gg[g]], 2) + $
      '  A_flow=' + strtrim(spinup_aflow, 2) + $
      '  ELA_bias=' + strtrim(spinup_ela_bias, 2) + ' m'
  endif else begin
    file_mkdir, spinup_cache_dir
    @procedures/flow/spinup_flowmodel
    save, spinup_aflow, spinup_ela_bias, spinup_dtfactor, thick_dx, sur_dx, $
          width_surface_dx, width_mid_dx, width_base_dx, lambda_dx, $
          file=spinup_cache_file
    print, 'Spin-up cache saved: ' + strtrim(id[gg[g]], 2)
  endelse

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

  ; ---- Scale geometry to match GloGEM survey volume ----
  ; The spin-up finds the correct ice dynamics parameters (A_flow, ELA_bias)
  ; but Phase B often drifts away from the target volume. Scale thick_dx so
  ; the flow model starts from exactly the GloGEM-observed volume at the survey
  ; year. This ensures sur_dx is at the correct elevation for mass-balance
  ; interpolation — without this, inflated ice surfaces see too-positive MB
  ; (accumulation zone) and glaciers grow instead of retreat.
  flow_blown_up = 0
  if flow_vol_init_m3 gt 0d0 and volumes[ye] gt 0d0 then begin
    f_scale = (volumes[ye] * 1d9) / flow_vol_init_m3
    thick_dx         = thick_dx * f_scale
    sur_dx           = bed_dx + thick_dx
    width_surface_dx = width_base_dx + lambda_dx * thick_dx
    width_mid_dx     = (width_base_dx + width_surface_dx) / 2d0
    if abs(f_scale - 1d0) gt 0.01d0 then $
      print, 'INFO: Rescaled thick_dx by factor ' + strtrim(f_scale, 2) + $
        ' to match GloGEM survey vol (was ' + strtrim(flow_vol_init_m3/1d9, 2) + ' km3)'
  endif

  ; Reference surface frozen at inventory-date state (after scaling).
  ; Used in STEP 2 to cap MB interpolation elevation — matches MATLAB massbal.m:
  ;   mb_sur(z) = obs_surf(z)  for cells where sur > obs_surf
  obs_sur_dx = sur_dx

endif

; ========== STEP 2: MAP GloGEM'S MB ONTO FLOWLINE GRID ========== ;
; Interpolate GloGEM's elevation-band MB (bal, m w.e./yr) at each
; flowline cell's current surface elevation (sur_dx), then convert
; to m ice. Replaces the duplicate T-index recalculation in
; flowline_massbal.pro — GloGEM's calibrated MB is the single source.
bal_dx = dblarr(xnum)
; Cap surface elevation used for MB interpolation at the inventory-date reference surface.
; Prevents runaway positive feedback when modelled ice temporarily exceeds the observed
; profile (inflated geometry → high elevation → positive accumulation-zone MB → more growth).
mb_sur_dx = sur_dx < obs_sur_dx
ii_gl_bands = where(gl ne noval, n_gl_bands)
if n_gl_bands ge 2 then begin
  bal_we_interp = interpol(bal[ii_gl_bands], elev[ii_gl_bands], mb_sur_dx)
endif else begin
  bal_we_interp = interpol(bal, elev, mb_sur_dx)
endelse
ii_ice_mb = where(thick_dx gt 0, c_ice_mb)
if c_ice_mb gt 0 then bal_dx[ii_ice_mb] = bal_we_interp[ii_ice_mb] / 0.917d0
; Apply NEGATIVE MB to ice-free cells as well — matches MATLAB (massbal.m zeroes
; only positive MB in ice-free cells, not negative).  Without this, SIA-advanced
; terminus cells see zero ablation for a full year and survive; with it they are
; immediately counter-acted by the local (strongly negative) MB and cannot persist.
ii_free_mb = where(thick_dx le 0, c_free_mb)
if c_free_mb gt 0 then begin
  ii_neg_in_free = where(bal_we_interp[ii_free_mb] lt 0, c_neg)
  if c_neg gt 0 then $
    bal_dx[ii_free_mb[ii_neg_in_free]] = bal_we_interp[ii_free_mb[ii_neg_in_free]] / 0.917d0
endif

; ========== STEP 2b: STORE BEGINNING-OF-YEAR STATE (matching dhdt timing) ========== ;
; finalize_annual_massbalance.pro stores volumes[ye] BEFORE retreat.
; We match this: store the flowline state before the SIA advance.
; Skip if blown up: volumes[ye]/areas[ye] from finalize_annual_massbalance.pro
; (the dhdt parametrisation) are then automatically kept in the output.
if NOT flow_blown_up then begin
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
endif

; ========== STEP 3: ADVANCE FLOW MODEL BY 1 YEAR ========== ;
if NOT flow_blown_up then begin
time_flow = 0d0
year_end_flow = 1d0
iter_flow = 0l
max_iter_flow = 50000l

; Save beginning-of-year geometry so blow-up can restore it rather than
; zeroing thick_dx. Zeroing would cause update_elevation_bands (called
; immediately after this file in glogem.pro) to deactivate all bands,
; making finalize_annual_massbalance report vol=0 for every subsequent
; year — even though dhdt should continue evolving the glacier normally.
thick_dx_year_start = thick_dx
sur_dx_year_start   = sur_dx

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

  ; Safety: bail out if thickness blows up; fall back to dhdt for rest of run.
  ; Restore beginning-of-year geometry (not zero) so update_elevation_bands
  ; keeps the band state intact and dhdt can continue retreating the glacier.
  if max(thick_dx) gt 5000d0 or total(~finite(thick_dx)) gt 0 then begin
    print, 'WARNING: GloGEMflow blow-up at iter=' + strtrim(iter_flow, 2) + $
      ', max(thick_dx)=' + strtrim(max(thick_dx), 2)
    print, '  Falling back to dhdt parametrisation for remainder of run.'
    flow_blown_up = 1
    thick_dx      = thick_dx_year_start
    sur_dx        = sur_dx_year_start
    break
  endif
endwhile

if iter_flow ge max_iter_flow then $
  print, 'WARNING: GloGEMflow hit max iterations for year ' + strtrim(ye + tran[0], 2)

endif  ; NOT flow_blown_up (STEP 3)

; ========== STEP 4: UPDATE GEOMETRY ========== ;
; No explicit terminus cleanup here — ice_thickness.pro already zeroes
; any negative thickness after each sub-step (matching the MATLAB reference
; model exactly: `i=find(th<0); th(i)=0`).  Thin but positive cells thin
; naturally to zero through ablation; imposing a minimum thickness threshold
; creates discrete area steps (the zigzag) rather than preventing them.
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

; ========== STEP 7: MAP FLOWLINE VELOCITY TO ELEVATION BANDS ========== ;
; Compute depth-averaged ice speed AND a kinematic vertical velocity from
; the post-SIA state, and interpolate both onto the elevation-band grid.
; Stored in u_flowmodel[nb] / w_flowmodel[nb] for use by
; firnice_temperature_model.pro in the following year (enable_advection='y').
;
; Speed: u = D * |ds/dx| / h  (m/year), where D = df_dx is the SIA diffusivity.
; df_dx uses aflow in Pa^-3 a^-1, so u is directly in m/year.
;
; Vertical velocity: standard mass-continuity kinematic surface boundary
; condition, converted to this codebase's downward-positive convention and
; dist_dx/flow-direction setup (dist_dx increases away from the terminus;
; ice flows toward decreasing dist_dx):
;   w_s = bal_dx + u * d(sur_dx)/d(dist_dx) - d(sur_dx)/dt
; bal_dx is already m ice/yr (positive = accumulation); the dh/dt term uses
; the previous year's flowline surface (flow_sur_hist[*,ye-1], stored at
; STEP 6 above, before this point). Replaces the previous per-band
; raw-monthly sno-mel (noisy) / steady-state emergence (ignores transient
; thickness change) heuristics in firnice_temperature_model.pro with a
; value tied to the same smooth, annually-resolved SIA state that already
; drives u_flowmodel.
;
; Both are interpolated (rather than binned into the nearest band) for the
; same reason as update_elevation_bands.pro: xnum flowline cells (125 for
; Aletsch) are far fewer than nb elevation bands (~254), so nearest-cell
; binning would leave many bands with no cell most years, producing a
; noisy/flickering field that gets advected directly into the temperature
; field.
grad_vel_dx = dblarr(xnum)
for i_vel = 1, xnum-2 do $
  grad_vel_dx[i_vel] = (sur_dx[i_vel+1] - sur_dx[i_vel-1]) / (2.0d0 * dx)

u_flowmodel = dblarr(nb)
w_flowmodel = dblarr(nb)
ii_vel_ice = where(thick_dx[1:xnum-2] gt 0d0 and abs(grad_vel_dx[1:xnum-2]) gt 0d0, n_vel_ice) + 1l
if n_vel_ice ge 2l then begin
  u_dx = df_dx[ii_vel_ice] * abs(grad_vel_dx[ii_vel_ice]) / thick_dx[ii_vel_ice]
  srt_vel = sort(sur_dx[ii_vel_ice])
  sur_vel_sorted = sur_dx[ii_vel_ice[srt_vel]]
  u_vel_sorted   = u_dx[srt_vel]
  vel_elev_min = sur_vel_sorted[0]
  vel_elev_max = sur_vel_sorted[n_vel_ice - 1l]
  jj_vel = where(elev ge vel_elev_min and elev le vel_elev_max, cjj_vel)
  if cjj_vel gt 0 then $
    u_flowmodel[jj_vel] = interpol(u_vel_sorted, sur_vel_sorted, elev[jj_vel])

  ; Kinematic vertical velocity -- needs the previous year's flowline
  ; surface, not available at ye=0.
  if ye gt 0l and cjj_vel gt 0 then begin
    dhdt_dx = sur_dx - flow_sur_hist[*, ye - 1l]   ; m/year, full flowline array
    w_dx = bal_dx[ii_vel_ice] + u_dx * grad_vel_dx[ii_vel_ice] - dhdt_dx[ii_vel_ice]
    w_vel_sorted = w_dx[srt_vel]
    w_flowmodel[jj_vel] = interpol(w_vel_sorted, sur_vel_sorted, elev[jj_vel])
  endif
endif
