; Define constants, initialize counters, variables and parameters and set their size

; ; Constants
compile_opt idl2
g = 9.81 ; Gravitational acceleration in m/s^2
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

; Geometry:
domainsize = x_input[n_elements(x_input) - 1] ; in meter; from 'x_input', which was generated in 'load_glacier'
first_icp_min = 9999
; lambda_standard = tan(0 * !DTOR) + tan(0 * !DTOR) ; sensitivity test in paper --> saved in 'calibration 3' folder (manually)
lambda_standard = tan(45 * !dtor) + tan(45 * !dtor) ; i.e. lamda = 2
; lambda_standard = tan(80 * !DTOR) + tan(80 * !DTOR) ; sensitivity test in paper --> saved in 'calibration 4' folder (manually)

last_icp_max = 0 ; last ice covered point (icp) (index)
xnum = floor(domainsize / dx) ; number of grid cells
if xnum gt n_elements(width_input) then begin
  xnum = xnum - 1
endif

; SMB:
ela_ss = 0

; ; Size variables that will (in most cases) be updated (i.e. overwritten) at every (few) time step(s)
bal = fltarr(xnum) ; Mass balance
bed = fltarr(xnum) ; Bedrock elevation
df = fltarr(xnum) ; Diffusivity factor
fluxdiv = fltarr(xnum) ; Flux divergence
fluxdiv_plot = fltarr(xnum) ; Flux divergence to be plotted
fluxdiv_plot2 = fltarr(xnum) ; Flux divergence to be plotted
grad = fltarr(xnum) ; Surface gradient
lambda = fltarr(xnum) ; Lambda: angle trapezium describing the glacier cross section
if flag_startobs ne 2 then begin ; If start from modelled geometry, don't want to set the surface elevation to zero
  sur = fltarr(xnum) ; Surface elevation
endif
term1 = fltarr(xnum) ; Part of the continuity equation (see 'ice_thickness.pro'), also used for fluxdiv_plot, in 'diagnostic_write.pro'
term2 = fltarr(xnum) ; Part of the continuity equation (see 'ice_thickness.pro'), also used for fluxdiv_plot, in 'diagnostic_write.pro'
if flag_startobs ne 2 then begin ; If start from modelled geometry, don't want to set the ice thickness to zero
  th = fltarr(xnum) ; Ice thickness
endif
vel = fltarr(xnum) ; Velocities

; ; Size prognostic variables that are written out every dtdiag timesteps (typically used to have overview at end of the run)

; scalars:
aflow_hist = fltarr(ceil(nyears / dtdiag))
area_hist = fltarr(ceil(nyears / dtdiag))
bal_mean_hist = fltarr(ceil(nyears / dtdiag))
time_hist = fltarr(ceil(nyears / dtdiag))
dt_hist = fltarr(ceil(nyears / dtdiag))
df_max_hist = fltarr(ceil(nyears / dtdiag))
height_front_hist = fltarr(ceil(nyears / dtdiag))
length_hist = fltarr(ceil(nyears / dtdiag))
vol_hist = fltarr(ceil(nyears / dtdiag))

; vectors:
bal_hist = fltarr(ceil(nyears / dtdiag), xnum)
fluxdiv_plot_hist = fltarr(ceil(nyears / dtdiag), xnum)
th_hist = fltarr(ceil(nyears / dtdiag), xnum)
