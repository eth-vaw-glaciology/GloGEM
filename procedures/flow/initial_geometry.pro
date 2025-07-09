; Define the observed geometry and generate the initial state

; ; First ice covered cell (for the observed geometry at inventory date):
compile_opt idl2
for i = 0, xnum - 1 do begin
  if th_x_input[i] gt 0 then begin
    first_icp = i
    break
  endif
endfor

; ; Observed volume per grid and surface elevation
x_dist = fltarr(xnum)
obs_vol = fltarr(xnum)
obs_sur = fltarr(xnum)
for i = 0, xnum - 1 do begin
  x_dist[i] = ((i + 1) / float(xnum)) * domainsize
  obs_vol[i] = th_x_input[i] * width_x_input[i] * dx
  obs_sur[i] = sur_x_input[i] ; In some cases 'obs_sur' is needed for SMB calculations (when this is based on observed geometry and not on modelled geometry)
endfor
obs_vol_flowlinemodel = total(obs_vol) ; can be slightly different than 'volume_Huss_1d_fixeddistance', because of very slight smoothing at the end of 'load_glacier'
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel

; ; Observed surface width
width_surface = fltarr(xnum)
if width_flag eq 1 or width_flag eq 2 then begin ; Rectangle or trapezium
  for i = 0, xnum - 1 do begin
    width_surface[i] = width_x_input[i]
    if width_surface[i] eq 0 then begin
      width_surface[i] = mean(width_x_input[first_icp : first_icp + 10]) ; For pre-frontal region: impose the average surface width of 10 lowest glacier covered cells
    endif
  endfor
endif

; ;  Observed bedrock and ice thickness
; Notice that here, in case of trapezium (width_flag==2) --> ice thickness
; and bedrock elevation will be modified (vs. data from Matthias): to
; ensure that the volume, area and surface elevation are conserved:
obs_vol_trapezium = 0.0
obs_th = fltarr(xnum)
width_base = fltarr(xnum)
width_mid = fltarr(xnum)
width_mid_obs = fltarr(xnum)
a = fltarr(xnum)
b = fltarr(xnum)
c = fltarr(xnum)
D = fltarr(xnum)

for i = xnum - 1, 0, -1 do begin ; In inverse direction (needed for triangle transect)
  if width_flag lt 2 then begin ; Constant width or rectangle shape
    obs_th[i] = th_x_input[i]
    lambda_x[i] = 0
    width_base[i] = width_surface[i]
  endif else if width_flag eq 2 then begin ; Trapezium shape
    lambda_x[i] = lambda_standard
    if width_x_input[i] eq 0 then begin ; for cells without ice: make sure that obs_th equals zero
      obs_th[i] = 0
      width_base[i] = width_surface[i]
    endif else if width_x_input[i] gt 0 then begin ; ice covered cell
      a[i] = -dx * lambda_x[i] / 2
      b[i] = width_surface[i] * dx
      c[i] = -1 * (obs_vol[i])
      D[i] = b[i] ^ 2 - 4 * a[i] * c[i]

      ; Calculate thickness with quadratic formula
      if D[i] ge 0 then begin
        obs_th[i] = (-b[i] + sqrt(D[i])) / (2 * a[i])
      endif else begin
        ; If D was negative, we'll get a complex number
        ; This will be handled below when we check if obs_th is finite
        obs_th[i] = !values.f_nan
      endelse
    endif

    ; Width at the base and eventually correct lambda_x:
    if finite(obs_th[i]) then begin ; Similar to MATLAB's isreal() check
      width_base[i] = width_surface[i] - lambda_x[i] * obs_th[i]
      if width_base[i] lt width_surface[i] / 3 then begin
        width_base[i] = width_surface[i] / 3
        obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base[i]) / 2)
        lambda_x[i] = (width_surface[i] - width_base[i]) / obs_th[i]
      endif
    endif else begin ; D was smaller than zero --> cannot reproduce the observed volume
      width_base[i] = width_surface[i] / 3
      obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base[i]) / 2)
      lambda_x[i] = (width_surface[i] - width_base[i]) / obs_th[i]
    endelse
  endif

  ; To be done in every case (independent of width_flag)
  width_mid[i] = (width_surface[i] + width_base[i]) / 2
  obs_vol_trapezium = obs_vol_trapezium + obs_th[i] * width_mid[i] * dx
  bed_x[i] = obs_sur[i] - obs_th[i]
  width_mid_obs[i] = width_base[i] + 0.5 * lambda_x[i] * obs_th[i] ; Needed for hypsometry plots
endfor

print, 'obs_vol_trapezium = ', obs_vol_trapezium ; Should be equal to obs_vol_flowlinemodel !

; ;
if display_during_flag eq 1 then begin ; typically not displayed, but may be useful for debugging
  ; Create a new graphics window for ice thickness
  w1 = window(dimensions = [800, 600])
  p1 = plot(x_input, th_x_input, /current, $
    title = 'Ice Thickness', $
    xtitle = 'Distance (m)', ytitle = 'Thickness (m)', $
    xrange = [min(x_input), max(x_input)], $
    color = 'blue', thick = 3.0)
  ; Create a second plot for observed ice thickness
  p4 = plot(x_input, obs_th, /overplot, $
    color = 'red', thick = 2.0)

  ; Create a new graphics window for surface and bedrock elevation
  w2 = window(dimensions = [800, 600])
  p2 = plot(x_input, sur_x_input, /current, $
    title = 'Surface and Bedrock Elevation', $
    xtitle = 'Distance (m)', ytitle = 'Elevation (m)', $
    xrange = [min(x_input), max(x_input)], $
    color = 'green', thick = 3.0)
  p5 = plot(x_input, bed_x, /overplot, $
    color = 'brown', thick = 2.0)

  ; Create a new graphics window for lambda_x angle
  w3 = window(dimensions = [800, 600])
  lambda_angle = atan(lambda_x / 2) * !radeg
  ylim = [0, max(lambda_angle) * 1.01]
  p3 = plot(x_input, lambda_angle, /current, $
    title = 'Lambda Angle', $
    xtitle = 'Distance (m)', ytitle = 'Angle (degrees)', $
    xrange = [min(x_input), max(x_input)], $
    yrange = [0, 45], $
    color = 'purple', thick = 3.0)
endif

; ;  Initial state for modelling
if flag_startobs eq 0 then begin ; Start from situation without ice
  for i = 0, xnum - 1 do begin
    sur_x[i] = bed_x[i]
    th_x[i] = 0 ; not really needed, as is defined as an array with only zeros. But just for clarity
  endfor
endif else if flag_startobs eq 1 then begin ; Start from observed state at inventory date
  for i = 0, xnum - 1 do begin
    sur_x[i] = obs_sur[i]
    th_x[i] = sur_x[i] - bed_x[i]
  endfor
endif else if flag_startobs eq 2 then begin ; Start from modelled state (can be steady state or transient)
  ; Nothing needs to be done, 'sur_x' and 'th_x' were already loaded in 'geom_files_load_and_transform.pro'
endif

; ;  Set boundary conditions (could potentially be removed it seems)
bed_x[0] = bed_x[2]
bed_x[1] = bed_x[2]
bed_x[xnum - 1] = bed_x[xnum - 2]

obs_sur[0] = bed_x[2]
obs_sur[1] = bed_x[2]

th_x[0] = 0
th_x[1] = 0

; ;
if display_during_flag eq 1 then begin ; typically not displayed, but may be useful for debugging
  ; Create a new graphics window for width comparison
  w4 = window(dimensions = [800, 600])
  p1 = plot(x_input, width_base, /current, $
    title = 'Width Comparison', $
    xtitle = 'Distance (m)', ytitle = 'Width (m)', $
    xrange = [min(x_input), max(x_input)], $
    color = 'blue', thick = 3.0)
  p2 = plot(x_input, width_mid, /overplot, $
    color = 'green', thick = 2.0)
  p3 = plot(x_input, width_surface, /overplot, $
    color = 'red', thick = 2.0)
endif

; ; Points needed to check if ice is leaving the domain (if so, the time loop will be stopped, see glacier.pro). Depends on the flow direction (i.e. from 'left to right' or 'from right to left')
if sur_x[1] lt sur_x[xnum - 1] then begin ; Ice flow from 'right to left'
  domain_exit_index = 2
endif else begin ; Ice flow from 'left to right'
  domain_exit_index = xnum - 3
  print, 'domain_exit_index = ', domain_exit_index
endelse

; Diagnoistic print outs to check the initial geometry
print, 'first_icp = ', first_icp
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel
print, 'obs_vol_trapezium = ', obs_vol_trapezium
print, 'obs_th = ', obs_th
print, 'obs_sur = ', obs_sur
print, 'bed_x = ', bed_x
print, 'width_base = ', width_base
print, 'width_mid = ', width_mid
print, 'width_mid_obs = ', width_mid_obs
print, 'lambda_x = ', lambda_x
print, 'th_x = ', th_x
print, 'sur_x = ', sur_x
print, 'domain_exit_index = ', domain_exit_index
