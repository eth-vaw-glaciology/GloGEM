; Define constants, initialize counters, variables and parameters and set their size

; ; Constants
compile_opt idl2
g_grav = 9.81 ; Gravitational acceleration in m/s^2
nflow = 3 ; Flow law exponent n
rho = 900 ; Density of ice in kg/m^3

; ; Counters, variables and parameters to be initialized

; Mass transport:
df_max = 0 ; Maximum modelled diffusivity factor
df_lim = (length_fixeddistance ^ 2) / 2 ; maximum value allowed for the diffusivity factor is related to the observed glacier length at inventory date (will likely have to be modified for other regions than the Alps)

; Time:
counter_diag = 0
if dt_flag eq 0 then begin ; Dynamic time step (i.e. dt changes over time). First value to be used is based on CFL-criterion
  dt = dtfactor * dx ^ 2 / (df_lim)
endif else begin
  dt = dt_flag
endelse
dtdiag = 1 ; Time step diagnostic output (years)
dtmb = 1 ; Time step surface mass balance model
next_time_diag = start_year ; Next time that diagnostic model output will be written out: set equal to start_year --> will immediately write out
next_time_mb = start_year ; Next time that diagnostic model output will be written out: set equal to start_year --> will immediately write out
t = 0 ; number of timesteps that have occurred so far
time = start_year ; Time (in years)
print, 'length_fixeddistance = ', length_fixeddistance
print, 'df_lim = (length_fixeddistance ^ 2) / 2 = ', df_lim

; Geometry:
domainsize = dist_dx_init[n_elements(dist_dx_init) - 1]
first_icp_min = 9999
; lambda_standard = tan(0 * !DTOR) + tan(0 * !DTOR) ; sensitivity test in paper --> saved in 'calibration 3' folder (manually)
lambda_standard = tan(45 * !dtor) + tan(45 * !dtor) ; i.e. lamda = 2
; lambda_standard = tan(80 * !DTOR) + tan(80 * !DTOR) ; sensitivity test in paper --> saved in 'calibration 4' folder (manually)

last_icp_max = 0 ; last ice covered point (icp) (index)
; xnum is already set by vertical_to_horizontal_grid.pro — do NOT recalculate
; xnum = floor(domainsize / dx) ; REMOVED: was overriding the correct value

; SMB:
ela_ss = 0

; ; Size working variables (NOT geometry — geometry comes from vertical_to_horizontal_grid.pro)
df_dx = fltarr(xnum) ; Diffusivity factor
fluxdiv_dx = fltarr(xnum) ; Flux divergence
fluxdiv_plot_dx = fltarr(xnum) ; Flux divergence to be plotted
fluxdiv_plot2_dx = fltarr(xnum) ; Flux divergence to be plotted
grad_dx = fltarr(xnum) ; Surface gradient
term1 = fltarr(xnum) ; Part of the continuity equation
term2 = fltarr(xnum) ; Part of the continuity equation
term3 = fltarr(xnum) ; Part of the continuity equation
velocity = fltarr(xnum) ; Velocities
; NOTE: bed_dx_init, thick_dx_init, sur_dx_init, lambda_dx, width arrays
; are set by vertical_to_horizontal_grid.pro and initial_geometry.pro
; Do NOT reinitialize them here!

; ; Size prognostic variables that are written out every dtdiag timesteps (typically used to have overview at end of the run)

; scalars (prefixed with flow_ to avoid collision with GloGEM history arrays):
flow_aflow_hist = fltarr(ceil(nyears / dtdiag))
flow_area_hist = fltarr(ceil(nyears / dtdiag))
flow_bal_mean_hist = fltarr(ceil(nyears / dtdiag))
flow_time_hist = fltarr(ceil(nyears / dtdiag))
flow_dt_hist = fltarr(ceil(nyears / dtdiag))
flow_df_max_hist = fltarr(ceil(nyears / dtdiag))
flow_height_front_hist = fltarr(ceil(nyears / dtdiag))
flow_length_hist = fltarr(ceil(nyears / dtdiag))
flow_vol_hist = fltarr(ceil(nyears / dtdiag))

; vectors:
flow_bal_hist = fltarr(ceil(nyears / dtdiag), xnum)
flow_fluxdiv_plot_hist = fltarr(ceil(nyears / dtdiag), xnum)
flow_th_hist = fltarr(ceil(nyears / dtdiag), xnum)
