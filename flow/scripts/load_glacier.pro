; Load the glacier geometry by Matthias (defined per elevation band) and
; transform to be compatible to our 1-D equidistant model grid

function load_glacier, glacier_id, region, dx, frontal_length, display_during_flag
  compile_opt idl2

  ; ; Read in the data
  glacier_geom = import_glacier_geometry('../input/' + region + '/flowline_geom/' + string(glacier_id, format = '(I05)') + '.dat')

  ; ; Sometimes there is no mass in the lowest elevation bands --> remove these bands
  i = where(glacier_geom[*, 5] eq 0, count)
  if count gt 0 then begin
    glacier_geom = glacier_geom[where(glacier_geom[*, 5] ne 0), *]
  endif

  ; ; (potentially) plot some figures illustrating this data (normally never plotted, but was useful for initial debugging)
  if display_during_flag eq 1 then begin
    ; ;
    WINDOW, 0
    PLOT, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2, thick = 2
    oplot, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2 - glacier_geom[*, 5], thick = 2
    xyouts, 0.5, 0.05, 'Distance (m)', /normal, alignment = 0.5
    xyouts, 0.05, 0.5, 'Elevation (m a.s.l)', /normal, alignment = 0.5, orientation = 90

    ; ;
    WINDOW, 1
    !p.multi = [0, 1, 2]
    PLOT, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2, thick = 2, xtitle = '', ytitle = 'Elevation (m a.s.l)'
    oplot, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2 - glacier_geom[*, 5], thick = 2

    PLOT, glacier_geom[*, 7], glacier_geom[*, 4], thick = 2, xtitle = 'Distance (m)', ytitle = 'Area (km^2)'
    !p.multi = 0

    ; ;
    WINDOW, 2
    !p.multi = [0, 1, 2]
    PLOT, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2, thick = 2, xtitle = '', ytitle = 'Elevation (m a.s.l)'
    oplot, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2 - glacier_geom[*, 5], thick = 2

    PLOT, glacier_geom[*, 7], glacier_geom[*, 6], thick = 2, xtitle = 'Distance (m)', ytitle = 'Width (m)'
    !p.multi = 0

    ; ;
    WINDOW, 3
    !p.multi = [0, 1, 2]
    PLOT, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2, thick = 2, xtitle = '', ytitle = 'Elevation (m a.s.l)'
    oplot, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2 - glacier_geom[*, 5], thick = 2

    PLOT, glacier_geom[*, 7], (glacier_geom[*, 4] * 1e6) * glacier_geom[*, 5], thick = 2, xtitle = 'Distance (m)', ytitle = 'Volume (m^3)'
    !p.multi = 0
  endif

  ; ; Determine the original horizontal resolution in data Matthias (not equidistant, as is derived from elevation bands and slope between them!)
  length_glacier_geom = n_elements(glacier_geom[*, 0])
  dx_original = fltarr(length_glacier_geom)
  for i = 1, length_glacier_geom - 1 do begin
    dx_original[i] = glacier_geom[i, 7] - glacier_geom[i - 1, 7]
  endfor

  ; ; Other potential figure to be displayed, showing the variation in the spatial resolution in data Matthias (again, may be useful for debugging)
  if display_during_flag eq 1 then begin
    WINDOW, 4
    PLOT, dx_original, thick = 2, ytitle = 'Horizontal resolution of data Matthias (m)'
  endif

  ; ; Interpolation to a regular (i.e. equidistant) grid:
  if dx eq 0 then begin ; If dx is not defined: 100 grid cells over domain --> this is normally always used (for all simulations in the paper)
    dx = round(glacier_geom[length_glacier_geom - 1, 7] / 100)
  endif
  print, 'dx = ', dx

  grid_cells = floor(glacier_geom[length_glacier_geom - 1, 7] / dx)

  x = findgen(grid_cells) * dx + dx

  glacier_geom_lookup_x = glacier_geom[*, 7] ; m
  glacier_geom_lookup_sur = (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2 ; m
  glacier_geom_lookup_width = glacier_geom[*, 6] ; m
  glacier_geom_lookup_th = glacier_geom[*, 5] ; m

  i = where(glacier_geom_lookup_width eq 0, count) ; Remove elevation bands with no ice
  if count gt 0 then begin
    good_indices = where(glacier_geom_lookup_width ne 0)
    glacier_geom_lookup_x = glacier_geom_lookup_x[good_indices]
    glacier_geom_lookup_sur = glacier_geom_lookup_sur[good_indices]
    glacier_geom_lookup_width = glacier_geom_lookup_width[good_indices]
    glacier_geom_lookup_th = glacier_geom_lookup_th[good_indices]
  endif

  sur_x = interpol(glacier_geom_lookup_sur, glacier_geom_lookup_x, x)
  width_x = interpol(glacier_geom_lookup_width, glacier_geom_lookup_x, x)
  i = where(x lt glacier_geom_lookup_x[0], count)
  if count gt 0 then width_x[i] = glacier_geom_lookup_width[0] ; Width for cells lower than first point on Huss grid: same as width first point Huss grid

  th_x = interpol(glacier_geom_lookup_th, glacier_geom_lookup_x, x)
  i = where(x lt glacier_geom_lookup_x[0], count)
  if count gt 0 then th_x[i] = glacier_geom_lookup_th[0] ; Thickness for cells lower than first point on Huss grid: same as thickness first point Huss grid
  bed_x = sur_x - th_x

  ; ; Additional figures displaying the interpolated data (normally never plotted, but was useful for initial debugging)
  if display_during_flag eq 1 then begin
    WINDOW, 5
    PLOT, glacier_geom[*, 7], glacier_geom[*, 6], thick = 2, xtitle = 'Horizontal distance (m)', $
      ytitle = 'Width (m)', title = 'Original vs Interpolated Data'
    oplot, x, width_x, thick = 2, color = 100

    WINDOW, 6
    PLOT, glacier_geom[*, 7], glacier_geom[*, 5], thick = 2, xtitle = 'Horizontal distance (m)', $
      ytitle = 'Thickness (m)', title = 'Original vs Interpolated Data'
    oplot, x, th_x, thick = 2, color = 100

    WINDOW, 7
    PLOT, glacier_geom[*, 7], (glacier_geom[*, 2] + glacier_geom[*, 3]) / 2, thick = 2, xtitle = 'Horizontal distance (m)', $
      ytitle = 'Surface elevation (m)', title = 'Original vs Interpolated Data'
    oplot, x, sur_x, thick = 2, color = 100
  endif

  ; ; Check how much the volume and area have changed:
  volume_Huss_1d = total((glacier_geom[*, 3] * 1e6) * glacier_geom[*, 4])
  print, 'volume_Huss_1d = ', volume_Huss_1d
  volume_Huss_1d_fixeddistance = total(width_x * th_x * dx)
  print, 'volume_Huss_1d_fixeddistance = ', volume_Huss_1d_fixeddistance
  area_Huss_1d = total(glacier_geom[*, 3] * 1e6)
  print, 'area_Huss_1d = ', area_Huss_1d
  area_Huss_1d_fixeddistance = total(width_x * dx)
  print, 'area_Huss_1d_fixeddistance = ', area_Huss_1d_fixeddistance
  i = where(th_x gt 1, count)
  length_fixeddistance = count * dx

  ; ; Add geometric information for parts lower than glacier at inventory date
  extra_grids = ceil((x[n_elements(x) - 1] * frontal_length) / dx) ; downstream of present-day glacier
  x_concat = findgen(extra_grids) * dx + x[n_elements(x) - 1] + dx ; will be placed upstream of present-day glacier
  th_concat = fltarr(extra_grids) ; downstream of present-day glacier
  width_concat = fltarr(extra_grids) ; downstream of present-day glacier

  ; load the bedrock in pre-frontal region (spacing = 125 m between each point):
  restore, '../input/' + region + '/dem_extended/prefrontal_elev_' + string(glacier_id, format = '(I05)') + '.sav' ; Loads 'lowest_point_save'
  prefrontal_elev = fltarr(n_elements(lowest_point_save[2 : *, 2]), 2)
  prefrontal_elev[*, 0] = lowest_point_save[2 : *, 2]
  prefrontal_elev[*, 1] = findgen(n_elements(prefrontal_elev[*, 0])) * 125 + 125

  highest_elev_pre_frontal = prefrontal_elev[0, 0]
  lowest_elev_pre_frontal = prefrontal_elev[n_elements(prefrontal_elev[*, 0]) - 1, 0]
  highest_x_pre_frontal = prefrontal_elev[0, 1]
  lowest_x_pre_frontal = prefrontal_elev[n_elements(prefrontal_elev[*, 0]) - 1, 1]
  slope = (highest_elev_pre_frontal - lowest_elev_pre_frontal) / (lowest_x_pre_frontal - highest_x_pre_frontal)

  ; Add point where elevation would be zero
  zero_elev_point = fltarr(1, 2)
  zero_elev_point[0, 0] = 0
  zero_elev_point[0, 1] = lowest_elev_pre_frontal / slope + lowest_x_pre_frontal ; Distance at which elevation would be equal to zero (based on slope prefrontal area)
  prefrontal_elev = [prefrontal_elev, zero_elev_point]

  ; Add the frontal elevation (where it is ice covered) also:
  prefrontal_elev_final = fltarr(n_elements(prefrontal_elev[*, 0]) + 1, 2)
  prefrontal_elev_final[0, 0] = sur_x[0]
  prefrontal_elev_final[0, 1] = 0
  prefrontal_elev_final[1 : *, *] = prefrontal_elev

  ; Surface elevation in pre-frontal region:
  sur_concat = fltarr(extra_grids)
  for i = extra_grids - 1, 0, -1 do begin
    distance_from_front = (extra_grids - i) * dx
    ; Determine the surface elevation based on 'prefrontal_elev_final' array with interp1:
    sur_concat[i] = interpol(prefrontal_elev_final[*, 0], prefrontal_elev_final[*, 1], distance_from_front)
  endfor

  ; (Very slightly) adapt this transition to make it smooth:
  slope_bed = bed_x[1] - bed_x[0]
  bias = (bed_x[0] - slope_bed) - sur_concat[n_elements(sur_concat) - 1]
  sur_concat = sur_concat + bias

  x_input = [x_concat, x]
  sur_input = [sur_concat, sur_x]
  th_input = [th_concat, th_x]
  width_input = [width_concat, width_x] ; values for the pre-frontal width (i.e. width_concat) are filled in later, in 'initial_geometry.pro'

  ; ; Apply a little smoothing, but make sure you do not create any new pre-frontal ice. i.e. Do not smooth frontal area
  smooth_range = 2
  i = where(th_input gt 0, count)
  if count gt 0 then front_pos = min(i) else front_pos = 0
  th_input_smooth = smooth(th_input, smooth_range)
  sur_input_smooth = smooth(sur_input, smooth_range)
  if front_pos + smooth_range lt n_elements(th_input) then begin
    th_input[front_pos + smooth_range : *] = th_input_smooth[front_pos + smooth_range : *]
    sur_input[front_pos + smooth_range : *] = sur_input_smooth[front_pos + smooth_range : *]
  endif

  ; ; Yet another plot that may be useful for debugging:
  if display_during_flag eq 1 then begin
    WINDOW, 8
    PLOT, sur_input
    oplot, sur_input - th_input ; bedrock
  endif

  ; Return structure with all needed variables
  RETURN, {sur_input: sur_input, $
    th_input: th_input, $
    width_input: width_input, $
    x_input: x_input, $
    dx: dx, $
    volume_huss_1D_fixeddistance: volume_Huss_1d_fixeddistance, $
    area_huss_1D_fixeddistance: area_Huss_1d_fixeddistance, $
    length_fixeddistance: length_fixeddistance}
end
