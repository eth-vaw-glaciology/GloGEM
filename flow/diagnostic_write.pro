; Calculate and save a few values. Not at every time step, this is
; performed at every 'dtdiag' time steps (typically once a year)
compile_opt idl2

counter_diag = counter_diag + 1
print, 'Time = ', string(floor(time), format = '(I0)'), ' (exact time is ', string(time, format = '(F0.2)'), ')' ; When this is not printed on screen: slightly faster (ca. 5-10%): so could potentially comment this out

; ; Calculate a few things:

; Length:
glacier_length = 0.0
for i = xnum - 3, 0, -1 do begin ; Glacier length: start from top --> go down
  if th[i] eq 0 then begin
    glacier_length = ((xnum - 2 - i) + 1) * dx
    break
  endif
endfor

; Area:
glacier_area = 0.0
for i = 0, xnum - 1 do begin
  if th[i] gt 0 then begin
    glacier_area = glacier_area + dx * width_surface[i]
  endif
endfor

; Volume:
vol = 0.0
for i = 0, xnum - 1 do begin
  if width_flag eq 0 then begin
    vol = vol + dx * th[i] * 700 ; in m^3 (need to assume the width)
  endif else if (width_flag eq 1) or (width_flag eq 2) or (width_flag eq 3) then begin
    vol = vol + dx * th[i] * width_mid[i] ; in m^3
  endif
endfor

; SMB:
sum_smb = 0.0
counter = 0.0
;
if width_flag eq 0 then begin ; Same width over entire glacier
  width_surface = replicate(1.0, n_elements(sur))
  width_mid = replicate(1.0, n_elements(sur))
endif

for i = 1, xnum - 2 do begin
  if th[i] gt 0 then begin
    counter = counter + width_surface[i]
    sum_smb = sum_smb + bal[i] * width_surface[i]
  endif
endfor

; Max diffusivity
for i = 0, xnum - 1 do begin
  if df[i] gt df_max then begin
    df_max = df[i]
  endif
endfor

; Flux divergence plot: how to plot the flux divergence (--> will be used in 'plot_final.pro')
for i = 0, xnum - 2 do begin
  fluxdiv_plot[i] = (term1[i] + term2[i]) / width_surface[i] ; cf. see continuity equation
endfor
fluxdiv_plot2 = fluxdiv_plot
for i = 2, xnum - 2 do begin ; Do not show where it nears zero: visually nicer
  if (fluxdiv_plot[i] eq 0) or (fluxdiv_plot[i - 1] eq 0) or (fluxdiv_plot[i - 2] eq 0) then begin
    fluxdiv_plot2[i] = !values.f_nan
  endif
endfor

; Velocity (average: vertically integrated)
for i = 1, xnum - 2 do begin
  if th[i] gt 0 then begin
    vel[i] = -df[i] * grad[i] / th[i]
  endif
endfor

; Update the first and last ice covered point (icp) (needed for plotting in 'plot_final.pro')
first_icp = 0
for i = 0, xnum - 1 do begin
  if th[i] gt 0 then begin
    first_icp = i
    break
  endif
endfor

last_icp = 0
for i = xnum - 1, 0, -1 do begin
  if th[i] gt 0 then begin
    last_icp = i
    break
  endif
endfor

if total(th) gt 0 then begin ; Need at least one ice covered point
  if first_icp lt first_icp_min then first_icp_min = first_icp
  if last_icp gt last_icp_max then last_icp_max = last_icp
endif

; ; Fill the '*_hist' files:
area_hist[counter_diag - 1] = glacier_area
aflow_hist[counter_diag - 1] = aflow
bal_hist[counter_diag - 1, 0 : xnum - 1] = bal[0 : xnum - 1]
bal_mean_hist[counter_diag - 1] = sum_smb / counter
df_max_hist[counter_diag - 1] = max(df)
dt_hist[counter_diag - 1] = dt
fluxdiv_plot_hist[counter_diag - 1, 0 : xnum - 2] = fluxdiv_plot2[0 : xnum - 2]
time_hist[counter_diag - 1] = time
length_hist[counter_diag - 1] = glacier_length
th_hist[counter_diag - 1, 0 : xnum - 1] = th[0 : xnum - 1]
vol_hist[counter_diag - 1] = vol / 1e9 ; /1e9: from m^3 to km^3
