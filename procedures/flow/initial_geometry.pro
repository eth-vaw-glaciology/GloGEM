; Define the observed geometry and generate the initial state

; ; First ice covered cell (for the observed geometry at inventory date):
compile_opt idl2
for i = 0, xnum - 1 do begin
  if thick_dx[i] gt 0 then begin
    first_icp = i
    break
  endif
endfor

; ; Observed volume per grid and surface elevation
dist_dx = fltarr(xnum)
obs_vol = fltarr(xnum)
obs_sur = fltarr(xnum)
for i = 0, xnum - 1 do begin
  dist_dx[i] = ((i + 1) / float(xnum)) * domainsize
  obs_vol[i] = thick_dx[i] * width_dx[i] * dx
  obs_sur[i] = sur_dx[i]
endfor
obs_vol_flowlinemodel = total(obs_vol)
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel

; ; Observed surface width
width_surface = fltarr(xnum)
if width_flag eq 1 or width_flag eq 2 then begin
  for i = 0, xnum - 1 do begin
    width_surface[i] = width_dx[i]
    if width_surface[i] eq 0 then begin
      width_surface[i] = mean(width_dx[first_icp : first_icp + 10])
    endif
  endfor
endif

; ;  Observed bedrock and ice thickness
obs_vol_trapezium = 0.0
obs_th = fltarr(xnum)
width_base_dx = fltarr(xnum)
width_mid_dx = fltarr(xnum)
width_mid_obs_dx = fltarr(xnum)
a_dx = fltarr(xnum)
b_dx = fltarr(xnum)
c_dx = fltarr(xnum)
D_dx = fltarr(xnum)
lambda_dx = fltarr(xnum)

for i = xnum - 1, 0, -1 do begin
  if width_flag lt 2 then begin
    obs_th[i] = thick_dx[i]
    lambda_dx[i] = 0
    width_base_dx[i] = width_surface[i]
  endif else if width_flag eq 2 then begin
    lambda_dx[i] = lambda_standard
    if width_dx[i] eq 0 then begin
      obs_th[i] = 0
      width_base_dx[i] = width_surface[i]
    endif else if width_dx[i] gt 0 then begin
      a_dx[i] = -dx * lambda_dx[i] / 2
      b_dx[i] = width_surface[i] * dx
      c_dx[i] = -1 * (obs_vol[i])
      D_dx[i] = b_dx[i] ^ 2 - 4 * a_dx[i] * c_dx[i]
      if D_dx[i] ge 0 then begin
        obs_th[i] = (-b_dx[i] + sqrt(D_dx[i])) / (2 * a_dx[i])
      endif else begin
        obs_th[i] = !values.f_nan
      endelse
    endif
    if finite(obs_th[i]) then begin
      width_base_dx[i] = width_surface[i] - lambda_dx[i] * obs_th[i]
      if width_base_dx[i] lt width_surface[i] / 3 then begin
        width_base_dx[i] = width_surface[i] / 3
        obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base_dx[i]) / 2)
        lambda_dx[i] = (width_surface[i] - width_base_dx[i]) / obs_th[i]
      endif
    endif else begin
      width_base_dx[i] = width_surface[i] / 3
      obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base_dx[i]) / 2)
      lambda_dx[i] = (width_surface[i] - width_base_dx[i]) / obs_th[i]
    endelse
  endif
  width_mid_dx[i] = (width_surface[i] + width_base_dx[i]) / 2
  obs_vol_trapezium = obs_vol_trapezium + obs_th[i] * width_mid_dx[i] * dx
  bed_dx[i] = obs_sur[i] - obs_th[i]
  width_mid_obs_dx[i] = width_base_dx[i] + 0.5 * lambda_dx[i] * obs_th[i]
endfor

print, 'obs_vol_trapezium = ', obs_vol_trapezium

; ;  Initial state for modelling
if flag_startobs eq 0 then begin
  for i = 0, xnum - 1 do begin
    sur_dx[i] = bed_dx[i]
    thick_dx[i] = 0
  endfor
endif else if flag_startobs eq 1 then begin
  for i = 0, xnum - 1 do begin
    sur_dx[i] = obs_sur[i]
    thick_dx[i] = sur_dx[i] - bed_dx[i]
  endfor
endif else if flag_startobs eq 2 then begin
  ; Nothing needs to be done
endif

; ;  Set boundary conditions
bed_dx[0] = bed_dx[2]
bed_dx[1] = bed_dx[2]
bed_dx[xnum - 1] = bed_dx[xnum - 2]

obs_sur[0] = bed_dx[2]
obs_sur[1] = bed_dx[2]

thick_dx[0] = 0
thick_dx[1] = 0

; ; Points needed to check if ice is leaving the domain
if sur_dx[1] lt sur_dx[xnum - 1] then begin
  domain_exit_index = 2
endif else begin
  domain_exit_index = xnum - 3
  print, 'domain_exit_index = ', domain_exit_index
endelse

; Diagnoistic print outs to check the initial geometry
print, 'first_icp = ', first_icp
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel
print, 'obs_vol_trapezium = ', obs_vol_trapezium
print, 'obs_th = ', obs_th
print, 'obs_sur = ', obs_sur
print, 'bed_dx = ', bed_dx
print, 'width_base_dx = ', width_base_dx
print, 'width_mid_dx = ', width_mid_dx
print, 'width_mid_obs_dx = ', width_mid_obs_dx
print, 'lambda_dx = ', lambda_dx
print, 'thick_dx = ', thick_dx
print, 'sur_dx = ', sur_dx
print, 'domain_exit_index = ', domain_exit_index
