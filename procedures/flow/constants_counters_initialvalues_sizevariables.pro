; Define constants, initialize counters, variables and parameters and set their size

; ; Constants
compile_opt idl2
g_grav = 9.81 ; Gravitational acceleration in m/s^2
nflow = 3 ; Flow law exponent n
rho = 900 ; Density of ice in kg/m^3

; ; Counters, variables and parameters to be initialized

; Mass transport:
df_lim = (length_fixeddistance ^ 2) / 2 ; maximum value allowed for the diffusivity factor is related to the observed glacier length at inventory date (will likely have to be modified for other regions than the Alps)

; Time:
if dt_flag eq 0 then begin ; Dynamic time step (i.e. dt changes over time). First value to be used is based on CFL-criterion
  dt = dtfactor * dx ^ 2 / (df_lim)
endif else begin
  dt = dt_flag
endelse
dtdiag = 1 ; Time step diagnostic output (years)
t = 0 ; number of timesteps that have occurred so far
time = start_year ; Time (in years)

; Geometry:
domainsize = dist_dx_init[n_elements(dist_dx_init) - 1]
lambda_standard = tan(45 * !dtor) + tan(45 * !dtor) ; i.e. lamda = 2
; xnum is set by vertical_to_horizontal_grid.pro

; ; Size working variables (NOT geometry — geometry comes from vertical_to_horizontal_grid.pro)
df_dx = fltarr(xnum) ; Diffusivity factor
; NOTE: bed_dx_init, thick_dx_init, sur_dx_init, lambda_dx, width arrays
; are set by vertical_to_horizontal_grid.pro and initial_geometry.pro
; Do NOT reinitialize them here!

; flowline balance history (prefixed with flow_ to avoid collision with GloGEM history arrays)
flow_bal_hist = fltarr(ceil(nyears / dtdiag), xnum)
