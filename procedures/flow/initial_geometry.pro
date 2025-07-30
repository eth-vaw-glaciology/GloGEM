; Define the observed geometry and generate the initial state

; ; First ice covered cell (for the observed geometry at inventory date):
compile_opt idl2
for i = 0, xnum - 1 do begin
  if thick_dx_init[i] gt 0 then begin
    first_icp = i
    break
  endif
endfor

; ; Observed volume per grid and surface elevation
dist_dx_init = fltarr(xnum)
obs_vol = fltarr(xnum)
obs_sur_init = fltarr(xnum)
for i = 0, xnum - 1 do begin
  dist_dx_init[i] = ((i + 1) / float(xnum)) * domainsize
  obs_vol[i] = thick_dx_init[i] * width_dx_init[i] * dx
  obs_sur_init[i] = sur_dx_init[i]
endfor
obs_vol_flowlinemodel = total(obs_vol)
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel

; ; Observed surface width
width_surface_dx_init = fltarr(xnum)
if width_flag eq 1 or width_flag eq 2 then begin
  for i = 0, xnum - 1 do begin
    width_surface_dx_init[i] = width_dx_init[i]
    if width_surface_dx_init[i] eq 0 then begin
      width_surface_dx_init[i] = mean(width_dx_init[first_icp : first_icp + 10])
    endif
  endfor
endif

; ;  Observed bedrock and ice thickness
obs_vol_trapezium = 0.0
obs_th_init = fltarr(xnum)
width_base_dx_init = fltarr(xnum)
width_mid_dx_init = fltarr(xnum)
width_mid_obs_dx_init = fltarr(xnum)
a_dx_init = fltarr(xnum)
b_dx_init = fltarr(xnum)
c_dx_init = fltarr(xnum)
D_dx_init = fltarr(xnum)
lambda_dx_init = fltarr(xnum)

for i = xnum - 1, 0, -1 do begin
  if width_flag lt 2 then begin
    obs_th_init[i] = thick_dx_init[i]
    lambda_dx_init[i] = 0
    width_base_dx_init[i] = width_surface_dx_init[i]
  endif else if width_flag eq 2 then begin
    lambda_dx_init[i] = lambda_standard
    if width_dx_init[i] eq 0 then begin
      obs_th_init[i] = 0
      width_base_dx_init[i] = width_surface_dx_init[i]
    endif else if width_dx_init[i] gt 0 then begin
      a_dx_init[i] = -dx * lambda_dx_init[i] / 2
      b_dx_init[i] = width_surface_dx_init[i] * dx
      c_dx_init[i] = -1 * (obs_vol[i])
      D_dx_init[i] = b_dx_init[i] ^ 2 - 4 * a_dx_init[i] * c_dx_init[i]
      if D_dx_init[i] ge 0 then begin
        obs_th_init[i] = (-b_dx_init[i] + sqrt(D_dx_init[i])) / (2 * a_dx_init[i])
      endif else begin
        obs_th_init[i] = !values.f_nan
      endelse
    endif
    if finite(obs_th_init[i]) then begin
      width_base_dx_init[i] = width_surface_dx_init[i] - lambda_dx_init[i] * obs_th_init[i]
      if width_base_dx_init[i] lt width_surface_dx_init[i] / 3 then begin
        width_base_dx_init[i] = width_surface_dx_init[i] / 3
        obs_th_init[i] = obs_vol[i] / (dx * (width_surface_dx_init[i] + width_base_dx_init[i]) / 2)
        lambda_dx_init[i] = (width_surface_dx_init[i] - width_base_dx_init[i]) / obs_th_init[i]
      endif
    endif else begin
      width_base_dx_init[i] = width_surface_dx_init[i] / 3
      obs_th_init[i] = obs_vol[i] / (dx * (width_surface_dx_init[i] + width_base_dx_init[i]) / 2)
      lambda_dx_init[i] = (width_surface_dx_init[i] - width_base_dx_init[i]) / obs_th_init[i]
    endelse
  endif
  width_mid_dx_init[i] = (width_surface_dx_init[i] + width_base_dx_init[i]) / 2
  obs_vol_trapezium = obs_vol_trapezium + obs_th_init[i] * width_mid_dx_init[i] * dx
  bed_dx_init[i] = obs_sur_init[i] - obs_th_init[i]
  width_mid_obs_dx_init[i] = width_base_dx_init[i] + 0.5 * lambda_dx_init[i] * obs_th_init[i]
endfor

print, 'obs_vol_trapezium = ', obs_vol_trapezium

; ;  Initial state for modelling
if flag_startobs eq 0 then begin
  for i = 0, xnum - 1 do begin
    sur_dx_init[i] = bed_dx_init[i]
    thick_dx_init[i] = 0
  endfor
endif else if flag_startobs eq 1 then begin
  for i = 0, xnum - 1 do begin
    sur_dx_init[i] = obs_sur_init[i]
    thick_dx_init[i] = sur_dx_init[i] - bed_dx_init[i]
  endfor
endif else if flag_startobs eq 2 then begin
  ; Nothing needs to be done
endif

; ;  Set boundary conditions
bed_dx_init[0] = bed_dx_init[2]
bed_dx_init[1] = bed_dx_init[2]
bed_dx_init[xnum - 1] = bed_dx_init[xnum - 2]

obs_sur_init[0] = bed_dx_init[2]
obs_sur_init[1] = bed_dx_init[2]

thick_dx_init[0] = 0
thick_dx_init[1] = 0

; ; Points needed to check if ice is leaving the domain
if sur_dx_init[1] lt sur_dx_init[xnum - 1] then begin
  domain_exit_index = 2
endif else begin
  domain_exit_index = xnum - 3
  print, 'domain_exit_index = ', domain_exit_index
endelse

; ; print length of width_dx_init and width_surface_dx_init
; print, 'length of width_dx_init: ', n_elements(width_dx_init)
; print, 'length of width_surface_dx_init: ', n_elements(width_surface_dx_init)

; ; Diagnoistic print outs to check the initial geometry
; print, 'width_dx_init: ', width_dx_init
; print, 'first_icp = ', first_icp
; print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel
; print, 'obs_vol_trapezium = ', obs_vol_trapezium
; print, 'obs_th_init = ', obs_th_init
; print, 'obs_sur_init = ', obs_sur_init
; print, 'bed_dx_init = ', bed_dx_init
; print, 'width_surface_dx_init = ', width_surface_dx_init
; print, 'width_base_dx_init = ', width_base_dx_init
; print, 'width_mid_dx_init = ', width_mid_dx_init
; print, 'width_mid_obs_dx_init = ', width_mid_obs_dx_init
; print, 'lambda_dx_init = ', lambda_dx_init
; print, 'thick_dx_init = ', thick_dx_init
; print, 'sur_dx_init = ', sur_dx_init
; print, 'domain_exit_index = ', domain_exit_index
