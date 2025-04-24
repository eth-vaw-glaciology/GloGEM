; Define the observed geometry and generate the initial state

; ; First ice covered cell (for the observed geometry at inventory date):
compile_opt idl2
for i = 0, xnum - 1 do begin
  if th_input[i] gt 0 then begin
    first_icp = i
    break
  endif
endfor

; ; Observed volume per grid and surface elevation
x = fltarr(xnum)
obs_vol = fltarr(xnum)
obs_sur = fltarr(xnum)
for i = 0, xnum - 1 do begin
  x[i] = ((i + 1) / float(xnum)) * domainsize
  obs_vol[i] = th_input[i] * width_input[i] * dx
  obs_sur[i] = sur_input[i] ; In some cases 'obs_sur' is needed for SMB calculations (when this is based on observed geometry and not on modelled geometry)
endfor
obs_vol_flowlinemodel = total(obs_vol) ; can be slightly different than 'volume_Huss_1d_fixeddistance', because of very slight smoothing at the end of 'load_glacier'
print, 'obs_vol_flowlinemodel = ', obs_vol_flowlinemodel

; ; Observed surface width
width_surface = fltarr(xnum)
if width_flag eq 1 or width_flag eq 2 then begin ; Rectangle or trapezium
  for i = 0, xnum - 1 do begin
    width_surface[i] = width_input[i]
    if width_surface[i] eq 0 then begin
      width_surface[i] = mean(width_input[first_icp : first_icp + 10]) ; For pre-frontal region: impose the average surface width of 10 lowest glacier covered cells
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
    obs_th[i] = th_input[i]
    lambda[i] = 0
    width_base[i] = width_surface[i]
  endif else if width_flag eq 2 then begin ; Trapezium shape
    lambda[i] = lambda_standard
    if width_input[i] eq 0 then begin ; for cells without ice: make sure that obs_th equals zero
      obs_th[i] = 0
    endif else if width_input[i] gt 0 then begin ; ice covered cell
      a[i] = -dx * lambda[i] / 2
      b[i] = width_surface[i] * dx
      c[i] = -1 * (obs_vol[i])
      D[i] = b[i] ^ 2 - 4 * a[i] * c[i]
      obs_th[i] = (-b[i] + sqrt(D[i])) / (2 * a[i])
    endif

    ; Width at the base and eventually correct lambda:
    if imaginary(obs_th[i]) eq 0 then begin ; Check if result is real
      width_base[i] = width_surface[i] - lambda[i] * obs_th[i]
      if width_base[i] lt width_surface[i] / 3 then begin
        width_base[i] = width_surface[i] / 3
        obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base[i]) / 2)
        lambda[i] = (width_surface[i] - width_base[i]) / obs_th[i]
      endif
    endif else begin ; D was smaller than zero --> cannot reproduce the observed volume for this cell with the imposed lambda (i.e. would need negative basal width). Determine the new lambda
      width_base[i] = width_surface[i] / 3
      obs_th[i] = obs_vol[i] / (dx * (width_surface[i] + width_base[i]) / 2)
      lambda[i] = (width_surface[i] - width_base[i]) / obs_th[i]
    endelse
  endif

  ; To be done in every case (independent of width_flag)
  width_mid[i] = (width_surface[i] + width_base[i]) / 2
  obs_vol_trapezium = obs_vol_trapezium + obs_th[i] * width_mid[i] * dx
  bed[i] = obs_sur[i] - obs_th[i]
  width_mid_obs[i] = width_base[i] + 0.5 * lambda[i] * obs_th[i] ; Needed for hypsometry plots
endfor

print, 'obs_vol_trapezium = ', obs_vol_trapezium ; Should be equal to obs_vol_flowlinemodel !

; ;
if display_during_flag eq 1 then begin ; typically not displayed, but may be useful for debugging
  window, 0
  plot, th_input, title = 'th', xtitle = '', ytitle = '', /xstyle, /ystyle
  oplot, obs_th, color = 100
  xyouts, 0.7, 0.9, 'th input', /normal
  xyouts, 0.7, 0.85, 'obs th', color = 100, /normal

  window, 1
  plot, sur_input, title = '', xtitle = '', ytitle = '', /xstyle, /ystyle
  oplot, bed

  window, 2
  plot, atan(lambda / 2) * !radeg, title = '', xtitle = '', ytitle = '', /xstyle, /ystyle
  ylim = [0, max(atan(lambda / 2) * !radeg) * 1.01]
  plot, atan(lambda / 2) * !radeg, title = '', xtitle = '', ytitle = '', /xstyle, /ystyle, yrange = ylim
endif

; ;  Initial state for modelling
if flag_startobs eq 0 then begin ; Start from situation without ice
  for i = 0, xnum - 1 do begin
    sur[i] = bed[i]
    th[i] = 0 ; not really needed, as is defined as an array with only zeros. But just for clarity
  endfor
endif else if flag_startobs eq 1 then begin ; Start from observed state at inventory date
  for i = 0, xnum - 1 do begin
    sur[i] = obs_sur[i]
    th[i] = sur[i] - bed[i]
  endfor
endif else if flag_startobs eq 2 then begin ; Start from modelled state (can be steady state or transient)
  ; Nothing needs to be done, 'sur' and 'th' were already loaded in 'geom_files_load_and_transform.pro'
endif

; ;  Set boundary conditions (could potentially be removed it seems)
bed[0] = bed[2]
bed[1] = bed[2]
bed[xnum - 1] = bed[xnum - 2]

obs_sur[0] = bed[2]
obs_sur[1] = bed[2]

th[0] = 0
th[1] = 0

; ;
if display_during_flag eq 1 then begin ; typically not displayed, but may be useful for debugging
  window, 3
  plot, width_base, title = 'width', xtitle = '', ytitle = '', /xstyle, /ystyle
  oplot, width_mid, color = 100
  oplot, width_surface, color = 200
  xyouts, 0.7, 0.9, 'width_base', /normal
  xyouts, 0.7, 0.85, 'width_mid', color = 100, /normal
  xyouts, 0.7, 0.8, 'width_surface', color = 200, /normal
endif

; ; Points needed to check if ice is leaving the domain (if so, the time loop will be stopped, see glacier.pro). Depends on the flow direction (i.e. from 'left to right' or 'from right to left')
if sur[1] lt sur[xnum - 1] then begin ; Ice flow from 'right to left'
  domain_exit_index = 2
endif else begin ; Ice flow from 'left to right'
  domain_exit_index = xnum - 3
  print, 'domain_exit_index = ', domain_exit_index
endelse
