; Final plotting!

; ; In for a movie? --> get the popcorn ready!
compile_opt idl2
if display_end_flag gt 2 then begin ; flow line movie
  ; Create window
  if display_end_flag eq 3 or display_end_flag eq 4 then begin
    win_size = [35, 30]
  endif else begin
    win_size = [60, 30]
  endelse

  w1 = window(dimensions = win_size * 37.8, buffer = 0) ; IDL uses pixels, approx 37.8 pixels per cm

  for i = 0, counter_diag - 1 do begin
    wait, 0.0005 * dtdiag

    ; Clear any previous plots
    w1.erase

    ; Set up the layout based on display flag
    if display_end_flag ge 5 then begin
      ; Main layout for glacier plot
      pos1 = [0.05, 0.05, 0.65, 0.95] ; Left, bottom, right, top in normalized coordinates
    endif else begin
      pos1 = [0.05, 0.05, 0.95, 0.95]
    endelse

    ; Plot glacier surface (blue area)
    surface_data = bed + th_hist[i, *]
    p1 = polygon(x / 1000, surface_data, /data, /fill_background, $
      fill_color = [0, 204, 255], target = w1, position = pos1)

    ; Plot bedrock (gray area)
    bed_min = min(bed) - 50
    bedrock_x = [x / 1000, reverse(x / 1000)]
    bedrock_y = [bed, replicate(bed_min, n_elements(bed))]
    p2 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
      fill_color = [240, 240, 240], target = w1, position = pos1)

    ; Plot observed geometry (dashed line)
    p3 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, target = w1, position = pos1, $
      /overplot)

    ; Add legend
    leg_text = 'Observed glacier geometry (in ' + string(inventory_date_id, format = '(I0)') + ', at inventory date)'
    l = legend(target = p3, leg_text, position = [0.1, 0.9], /normal)

    ; Add axes labels and title
    ax = p1.axes
    ax[0].title = 'Distance (km)'
    ax[1].title = 'Elevation (km)'
    p3.title = 'Year ' + string(floor(time_hist[i]), format = '(I0)')

    ; Set axis limits
    p3.xrange = [dx, (domainsize - dx)] / 1000
    p3.yrange = [min(bed) - 20, max(bed) + 100]

    ; Set font size
    p3.font_size = 22

    ; Add additional subplots if needed
    if display_end_flag ge 5 then begin
      ; Volume and SMB history subplot
      pos2 = [0.70, 0.52, 0.95, 0.95]

      ; Plot volume history
      p4 = plot(time_hist[0 : i], vol_hist[0 : i], 'black', thick = 2, $
        yrange = [min(vol_hist[0 : counter_diag - 1]) * 0.98, max(vol_hist[0 : counter_diag - 1]) * 1.02], $
        xrange = [start_year, time], position = pos2, /current, margin = [0.1, 0.1, 0.1, 0.1])
      p4.xtitle = 'Time (a)'
      p4.ytitle = 'Volume (km³)'
      p4.font_size = 22

      ; Create second y axis for SMB
      p5 = plot(time_hist[0 : i], bal_mean_hist[0 : i], 'red', thick = 2, $
        yrange = [min(bal_mean_hist[0 : counter_diag - 1]) * 0.98, max(bal_mean_hist[0 : counter_diag - 1]) * 1.02], $
        /current, /overplot)
      ax2 = axis('Y', location = 'right', target = p5, color = 'red', $
        title = 'Specific SMB (m ice eq. a⁻¹)')

      ; SMB and flux divergence subplot
      pos3 = [0.70, 0.05, 0.95, 0.48]

      ; Plot SMB
      p6 = plot(x[1 : xnum - 2] / 1000, bal_hist[i, 1 : xnum - 2], 'blue', thick = 2, $
        yrange = [min(bal_hist), max(bal_hist)], $
        xrange = [dx, (domainsize - dx)] / 1000, position = pos3, /current)
      p6.xtitle = 'Distance (km)'
      p6.ytitle = 'SMB (m i.e a⁻¹)'
      p6.font_size = 22

      ; Plot flux divergence on second y-axis
      p7 = plot(x[1 : xnum - 2] / 1000, -fluxdiv_plot_hist[i, 1 : xnum - 2], 'red', '--', thick = 2, $
        /current, /overplot)
      ax3 = axis('Y', location = 'right', target = p7, color = 'red', $
        title = '- Flux divergence (m a⁻¹)')
    endif

    ; Save frames if needed
    if display_end_flag eq 4 or display_end_flag eq 6 then begin
      filename = '../output/' + region + '/figures_rcm/chain' + $
        string(chain, format = '(I02)') + '/calibration' + $
        string(calibration_method, format = '(I0)') + '/' + $
        string(glacier_id, format = '(I05)') + '_geom_year'

      if time_hist[i] eq 0 then begin
        filename += '000000.png'
      endif else if time_hist[i] lt 10 then begin
        filename += '00000' + string(floor(time_hist[i]), format = '(I0)') + '.png'
      endif else if time_hist[i] lt 100 then begin
        filename += '0000' + string(floor(time_hist[i]), format = '(I0)') + '.png'
      endif else if time_hist[i] lt 1000 then begin
        filename += '000' + string(floor(time_hist[i]), format = '(I0)') + '.png'
      endif else if time_hist[i] lt 10000 then begin
        filename += '00' + string(floor(time_hist[i]), format = '(I0)') + '.png'
      endif

      w1.save, filename, resolution = 80
    endif
  endfor
endif

; Evolution of variables over time
if display_end_flag gt 1 then begin
  ; Figure for volume and SMB history
  w2 = window(dimensions = [40 * 37.8, 20 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Plot volume history - left y-axis
  p8 = plot(time_hist[0 : counter_diag - 1], vol_hist[0 : counter_diag - 1], 'black', thick = 2, $
    xtitle = 'Time (a)', ytitle = 'Volume (km³)', font_size = 16, target = w2)

  ; Plot SMB history - right y-axis
  p9 = plot(time_hist[0 : counter_diag - 1], bal_mean_hist[0 : counter_diag - 1], 'red', thick = 2, $
    /current, /overplot)
  ax2 = axis('Y', location = 'right', target = p9, color = 'red', $
    title = 'Specific SMB (m ice eq. a⁻¹)')

  p8.grid_style = 1 ; Equivalent to grid minor

  ; Figure for diffusivity factor and timestep
  w3 = window(dimensions = [40 * 37.8, 20 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Plot diffusivity factor - left y-axis
  p10 = plot(time_hist[0 : counter_diag - 1], df_max_hist[0 : counter_diag - 1], 'black', thick = 2, $
    xtitle = 'Time (a)', ytitle = 'Maximum diffusivity factor (m² a⁻¹)', $
    yrange = [0.9 * min(df_max_hist), 1.1 * max(df_max_hist)], font_size = 16, target = w3)

  ; Add horizontal limit line
  p11 = plot([start_year, time], [df_lim, df_lim], 'black', '--', thick = 2, /overplot)

  ; Plot timestep - right y-axis
  p12 = plot(time_hist[0 : counter_diag - 1], dt_hist[0 : counter_diag - 1], 'red', thick = 2, $
    /current, /overplot)
  ax3 = axis('Y', location = 'right', target = p12, color = 'red', $
    title = 'δt (a)', yrange = [0.9 * min(dt_hist), 1.1 * max(dt_hist)])

  p10.grid_style = 1 ; Equivalent to grid minor

  ; ; Final situation plots

  ; Surface mass balance and flux divergence plot
  w4 = window(dimensions = [35 * 37.8, 30 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Plot surface and bedrock (left y-axis)
  ; Create glacier surface
  surface_x = [x / 1000, reverse(x / 1000)]
  surface_y = [sur, replicate(min(bed) - 50, n_elements(bed))]
  p13 = polygon(surface_x, surface_y, /data, /fill_background, $
    fill_color = [0, 204, 255], target = w4)

  ; Create bedrock
  bedrock_x = [x / 1000, reverse(x / 1000)]
  bedrock_y = [bed, replicate(min(bed) - 50, n_elements(bed))]
  p14 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
    fill_color = [240, 240, 240], target = w4, /overplot)

  ; Plot observed profile
  p15 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, /overplot)

  p15.yrange = [min(bed) - 20, max(bed) + 100]
  p15.ytitle = 'Elevation (m)'

  ; Plot SMB and flux divergence (right y-axis)
  p16 = plot(x[first_icp : last_icp] / 1000, bal[first_icp : last_icp], 'g', thick = 2, /overplot)
  p17 = plot(x[first_icp : last_icp] / 1000, -fluxdiv_plot[first_icp : last_icp], 'r', '--', thick = 3, /overplot)
  p18 = plot([0, domainsize] / 1000, [0, 0], 'k', '--', /overplot)

  ax4 = axis('Y', location = 'right', target = p16, $
    title = 'SMB / flux divergence (m a⁻¹)')

  leg = legend(target = [p16, p17], ['Surface mass balance', '- Flux divergence'], $
    position = [0.7, 0.9], /normal)

  p15.xrange = [dx, (domainsize - dx)] / 1000
  p15.xtitle = 'Distance (km)'
  p15.font_size = 16
  p15.grid_style = 1 ; Equivalent to grid minor

  ; Mean velocity plot
  w5 = window(dimensions = [35 * 37.8, 30 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Determine velocity direction based on bed slope
  if bed[0] lt bed[n_elements(bed) - 1] then begin
    vel_plot = -vel
  endif else begin
    vel_plot = vel
  endelse

  ; Plot surface and bedrock (left y-axis)
  ; Create glacier surface
  surface_x = [x / 1000, reverse(x / 1000)]
  surface_y = [sur, replicate(min(bed) - 50, n_elements(bed))]
  p19 = polygon(surface_x, surface_y, /data, /fill_background, $
    fill_color = [0, 204, 255], target = w5)

  ; Create bedrock
  bedrock_x = [x / 1000, reverse(x / 1000)]
  bedrock_y = [bed, replicate(min(bed) - 50, n_elements(bed))]
  p20 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
    fill_color = [240, 240, 240], target = w5, /overplot)

  ; Plot observed profile
  p21 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, /overplot)

  p21.yrange = [min(bed) - 20, max(bed) + 100]
  p21.ytitle = 'Elevation (m)'

  ; Plot velocity (right y-axis)
  p22 = plot(x[first_icp : last_icp] / 1000, vel_plot[first_icp : last_icp], 'r', thick = 2, /overplot)

  ax5 = axis('Y', location = 'right', target = p22, color = 'red', $
    title = 'Mean velocity (m a⁻¹) (vertically integrated)')

  p21.xrange = [dx, (domainsize - dx)] / 1000
  p21.xtitle = 'Distance (km)'
  p21.font_size = 16
  p21.grid_style = 1 ; Equivalent to grid minor

  ; Diffusivity plot
  w6 = window(dimensions = [35 * 37.8, 30 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Plot surface and bedrock (left y-axis)
  ; Create glacier surface
  surface_x = [x / 1000, reverse(x / 1000)]
  surface_y = [sur, replicate(min(bed) - 50, n_elements(bed))]
  p23 = polygon(surface_x, surface_y, /data, /fill_background, $
    fill_color = [0, 204, 255], target = w6)

  ; Create bedrock
  bedrock_x = [x / 1000, reverse(x / 1000)]
  bedrock_y = [bed, replicate(min(bed) - 50, n_elements(bed))]
  p24 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
    fill_color = [240, 240, 240], target = w6, /overplot)

  ; Plot observed profile
  p25 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, /overplot)

  p25.yrange = [min(bed) - 20, max(bed) + 100]
  p25.ytitle = 'Elevation (m)'

  ; Plot diffusivity (right y-axis)
  p26 = plot(x[first_icp : last_icp] / 1000, df[first_icp : last_icp], 'r', thick = 2, /overplot)

  ax6 = axis('Y', location = 'right', target = p26, color = 'red', $
    title = 'Diff (m² a⁻¹)')

  p25.xrange = [dx, (domainsize - dx)] / 1000
  p25.xtitle = 'Distance (km)'
  p25.font_size = 16
  p25.grid_style = 1 ; Equivalent to grid minor

  ; Volume by elevation band plot
  w7 = window(dimensions = [35 * 37.8, 30 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

  ; Plot surface and bedrock (left y-axis)
  ; Create glacier surface
  surface_x = [x / 1000, reverse(x / 1000)]
  surface_y = [sur, replicate(min(bed) - 50, n_elements(bed))]
  p27 = polygon(surface_x, surface_y, /data, /fill_background, $
    fill_color = [0, 204, 255], target = w7)

  ; Create bedrock
  bedrock_x = [x / 1000, reverse(x / 1000)]
  bedrock_y = [bed, replicate(min(bed) - 50, n_elements(bed))]
  p28 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
    fill_color = [240, 240, 240], target = w7, /overplot)

  ; Plot observed profile
  p29 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, /overplot)

  p29.yrange = [min(bed) - 20, max(bed) + 100]
  p29.ytitle = 'Elevation (m)'

  ; Plot volume per elevation band (right y-axis)
  p30 = plot(x / 1000, th * width_mid * dx, 'r', thick = 2, /overplot)
  p31 = plot(x / 1000, obs_th * width_mid_obs * dx, 'r', '--', thick = 2, /overplot)

  ax7 = axis('Y', location = 'right', target = p30, color = 'red', $
    title = 'Volume for this elevation band')

  p29.xrange = [dx, (domainsize - dx)] / 1000
  p29.xtitle = 'Distance (km)'
  p29.font_size = 16
  p29.grid_style = 1 ; Equivalent to grid minor
endif

; ; Hypsometric info
matrix = fltarr(5000)
matrix_obs = fltarr(5000)
for j = 0, n_elements(width_mid) - 1 do begin
  bed_round100 = round(bed[j] / 100.0) * 100
  ; Modelled geometry
  if bed_round100 ge 0 and bed_round100 lt 5000 then begin
    matrix[bed_round100] += th[j] * width_mid[j] * dx
    ; Observed geometry (at inventory date)
    matrix_obs[bed_round100] += obs_th[0, j] * width_mid_obs[j] * dx
  endif
endfor

; ; Final overview plot (can be saved, isn't that amazing?)
w8 = window(dimensions = [50 * 37.8, 30 * 37.8], margin = [0.10, 0.10, 0.10, 0.10], buffer = 0)

; Main plot
pos1 = [0.05, 0.05, 0.85, 0.95] ; Main plot position

; Plot surface and bedrock
; Create glacier surface
surface_x = [x / 1000, reverse(x / 1000)]
surface_y = [sur, replicate(min(bed) - 50, n_elements(bed))]
p32 = polygon(surface_x, surface_y, /data, /fill_background, $
  fill_color = [0, 204, 255], position = pos1, target = w8)

; Create bedrock
bedrock_x = [x / 1000, reverse(x / 1000)]
bedrock_y = [bed, replicate(min(bed) - 50, n_elements(bed))]
p33 = polygon(bedrock_x, bedrock_y, /data, /fill_background, $
  fill_color = [240, 240, 240], /overplot)

; Plot observed profile
p34 = plot(x / 1000, obs_sur, ':', 'gray', thick = 2, /overplot)

; Create array for legend items
plotHandles = [p34]
legendLabels = ['Observed glacier geometry (in ' + string(inventory_date_id, format = '(I0)') + ', at inventory date)']

; Add additional lines for steady state if needed
if mb_type_flag eq 5 then begin ; For the 1950/1990 steady state
  p35 = plot([0, domainsize] / 1000, [ela_observed, ela_observed], 'g', '--', thick = 2, /overplot)
  p36 = plot([0, domainsize] / 1000, [ela_ss, ela_ss], 'r', '--', thick = 2, /overplot)

  ; Add to legend
  plotHandles = [plotHandles, p35, p36]
  legendLabels = [legendLabels, $
    'Observed ELA over 1960-1990 period = ' + string(ela_observed, format = '(F0.4)') + $
    ' m (SMB = ' + string(bal_mean_observed, format = '(F0.2)') + ' m ice eq. a⁻¹)', $
    'Imposed ELA = ' + string(ela_ss, format = '(F0.4)') + $
    ' m (applied SMB bias vs. 1960-1990 = ' + string(bias_to_be_applied, format = '(F0.2)') + ' m ice eq. a⁻¹)']
endif

; Create legend
leg = legend(target = plotHandles, legendLabels, position = [0.1, 0.9], /normal)

; Set title and axis properties
title_text = 'Modelled geometry (Glacier ID = ' + string(glacier_id, format = '(I05)') + $
  '; A = ' + string(aflow, format = '(E0.2)') + ' Pa⁻³ a⁻¹; dx = ' + $
  string(dx, format = '(I0)') + ' m)'
p34.title = title_text
p34.xrange = [dx, (domainsize - dx)] / 1000
p34.yrange = [min(bed) - 20, max(bed) + 100]
p34.xtitle = 'Distance (km)'
p34.ytitle = 'Elevation (m)'
p34.font_size = 22
p34.grid_style = 1 ; Equivalent to grid minor

; Subplot for hypsometry
pos2 = [0.87, 0.05, 0.97, 0.95] ; Hypsometry plot position
elevations = indgen(41) * 100 + 1000 ; 1000 to 5000 by 100

; Create bar chart
p37 = barplot(matrix[elevations] / 1e9, elevations, /horizontal, $
  fill_color = [200, 200, 200], linestyle = 'none', $
  position = pos2, /current)
p38 = barplot(matrix_obs[elevations] / 1e9, elevations, /horizontal, $
  fill_color = 'white', yrange = [min(bed) - 20, max(bed) + 100], $
  xrange = [0, max(matrix_obs) / 1e9 * 1.5], /current, /overplot)

p37.xtitle = 'Volume (km³)'
p37.font_size = 22
p37.grid_style = 1 ; Equivalent to grid minor

; Save figure if needed
if display_end_flag eq 1 then begin
  outpath = '../output/' + region + '/figures_rcm/chain' + $
    string(chain, format = '(I02)') + '/calibration' + $
    string(calibration_method, format = '(I0)') + '/' + $
    string(glacier_id, format = '(I05)')

  if mb_type_flag eq 5 then begin
    if calibration_method eq 1 then begin
      filename = outpath + '_1990_ss.pdf'
    endif else if calibration_method eq 2 then begin
      filename = outpath + '_1950_ss.pdf'
    endif
  endif else if mb_type_flag eq 6 then begin
    if floor(time) lt 2017 then begin
      filename = outpath + '_' + string(inventory_date_id, format = '(I0)') + '_tr.pdf'
    endif else if floor(time) eq 2017 then begin
      filename = outpath + '_2017_tr.pdf'
    endif else if floor(time) ge 2100 then begin
      filename = outpath + '_' + string(floor(time), format = '(I0)') + '_tr.pdf'
    endif
  endif

  w8.save, filename
  w8.close
endif
