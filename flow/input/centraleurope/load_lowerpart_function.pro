function load_lowerpart_function, glacier_id, dist, min_dist_to_previous
  compile_opt idl2

  glacier_id = string(glacier_id, format = '(I05)')

  ; ; Surface elevation (DEM)
  t_start = systime(/seconds)

  ; Read the DEM grid - both header and data in one operation
  main_dir = '~/Library/Mobile Documents/com~apple~CloudDocs/PhD/projects/GloGEM/'
  dem_file = main_dir + 'flow/input/centraleurope/dem_extended/dem_' + glacier_id + '.grid'

  ; Open the file once to read everything
  openr, lun, dem_file, /get_lun

  ; First read the header lines
  header_lines = strarr(6)
  readf, lun, header_lines

  ; Parse header values directly
  ncols = double(strmid(header_lines[0], 10))
  nrows = double(strmid(header_lines[1], 10))
  xllcorner = double(strmid(header_lines[2], 10))
  yllcorner = double(strmid(header_lines[3], 10))
  cellsize = float(strmid(header_lines[4], 10))
  utmzone = fix(strmid(header_lines[5], 10))

  ; Now read the actual data values
  data = fltarr(ncols, nrows)
  for i = 0, nrows - 1 do begin
    line = fltarr(ncols)
    readf, lun, line
    data[*, i] = line
  endfor

  ; Close the file
  free_lun, lun

  ; Transform matrix to array for processing
  data_array = reform(data, ncols * nrows)
  i = where(finite(data_array) eq 0, count)
  if count gt 0 then data_array[i] = data_array[where(finite(data_array) eq 1, /null)]

  ; Reshape to 2D array without transposing
  dem2d = reform(data_array, [ncols, nrows])

  ; Handle extreme negative values
  i = where(dem2d lt -1000, count)
  if count gt 0 then dem2d[i] = !values.f_nan ; Replace with NaN

  ; ; Glacier mask (thickness)
  t_start = systime(/seconds)

  ; Read the thickness grid - both header and data in one operation
  thickness_file = main_dir + 'flow/input/centraleurope/thickness_extended/thick_' + glacier_id + '.agr'

  ; Open the file once to read everything
  openr, lun, thickness_file, /get_lun

  ; First read the header lines
  header_lines = strarr(6)
  readf, lun, header_lines

  ; Transform matrix to array for processing
  thickness_data = fltarr(ncols, nrows)
  for i = 0, nrows - 1 do begin
    line = fltarr(ncols)
    readf, lun, line
    thickness_data[*, i] = line
  endfor

  ; Close the file
  free_lun, lun

  ; Reshape to 2D array without transposing
  thickness2d = reform(thickness_data, [ncols, nrows])

  ; ; Plots
  thickness2d_plot = thickness2d
  i = where(thickness2d_plot eq 0, count)
  if count gt 0 then thickness2d_plot[i] = !values.f_nan

  ; ; Reconstruct the bedrock for the lower parts:
  ; Start by finding the position and elevation of front
  s = size(thickness2d, /dimensions)
  rows = s[0]
  cols = s[1]
  counter = 0
  lowest_point_candidate = fltarr(1000, 3) ; Pre-allocate with reasonable size

  for i = 1, rows - 2 do begin
    for j = 1, cols - 2 do begin
      if thickness2d[i, j] gt 0 then begin ; There is ice
        if thickness2d[i - 1, j + 1] eq 0 || thickness2d[i - 1, j] eq 0 || thickness2d[i - 1, j - 1] eq 0 || $
          thickness2d[i, j + 1] eq 0 || thickness2d[i, j - 1] eq 0 || $
          thickness2d[i + 1, j + 1] eq 0 || thickness2d[i + 1, j] eq 0 || thickness2d[i + 1, j - 1] eq 0 then begin
          ; Check if counter exceeds the current size of the array
          if counter ge n_elements(lowest_point_candidate) / 3 then begin
            ; Dynamically resize the array by adding more rows
            lowest_point_candidate = [lowest_point_candidate, fltarr(1000, 3)]
          endif
          ; Must be a point at the edge of domain
          lowest_point_candidate[counter, 0] = i
          lowest_point_candidate[counter, 1] = j
          lowest_point_candidate[counter, 2] = dem2d[i, j]
          counter++
        endif
      endif
    endfor
  endfor

  ; Trim to actual size
  lowest_point_candidate = lowest_point_candidate[0 : counter - 1, *]

  ; Find minimum point
  min_val = min(lowest_point_candidate[*, 2], min_idx)
  lowest_point = fltarr(3)
  lowest_point[0] = lowest_point_candidate[min_idx, 0]
  lowest_point[1] = lowest_point_candidate[min_idx, 1]
  lowest_point[2] = lowest_point_candidate[min_idx, 2]

  ; Initialize lowest_point_save (needed for later)
  lowest_point_save = fltarr(1000, 3) ; Pre-allocate with reasonable size
  lowest_point_save[0, *] = lowest_point ; First row
  lowest_point_save[1, *] = lowest_point ; Second row

  ; Set fixed window dimensions - this will be consistent for all glaciers
  fixed_width = 600
  fixed_height = 500

  ; Create a visualization window with fixed dimensions
  w = window(dimensions = [fixed_width, fixed_height], title = 'Flowline front: ' + glacier_id)

  ; Create a copy of thickness2d for display and convert zeros to NaN
  display_thickness = thickness2d
  i = where(display_thickness eq 0, count)
  if count gt 0 then display_thickness[i] = !values.f_nan

  ; Find the area with actual glacier data to focus the plot
  valid_idx = where(finite(display_thickness), valid_count)
  if valid_count gt 0 then begin
    ; Convert flat indices to 2D coordinates
    valid_x = valid_idx mod rows
    valid_y = valid_idx / rows

    ; Calculate bounds with padding
    pad = 15 ; Padding in pixels around glacier
    x_min = max([min(valid_x) - pad, 0])
    x_max = min([max(valid_x) + pad, rows - 1])
    y_min = max([min(valid_y) - pad, 0])
    y_max = min([max(valid_y) + pad, cols - 1])

    ; Display the glacier thickness map focused on glacier area
    ; The IMAGE function will automatically scale the data to fill the display area
    img = image(display_thickness, rgb_table = 33, /current, $
      axis_style = 2, $
      font_size = 12, $
      xtitle = 'X Index', ytitle = 'Y Index', $
      xrange = [x_min, x_max], yrange = [y_min, y_max], $
      dimensions = [fixed_width - 100, fixed_height - 100], $ ; Force image size
      margin = [0.15, 0.15, 0.15, 0.15]) ; Consistent margins
  endif else begin
    ; Fallback if no valid data found
    img = image(display_thickness, rgb_table = 33, /current, $
      axis_style = 2, $
      font_size = 12, $
      xtitle = 'X Index', ytitle = 'Y Index', $
      dimensions = [fixed_width - 100, fixed_height - 100], $ ; Force image size
      margin = [0.15, 0.15, 0.15, 0.15]) ; Consistent margins
  endelse

  ; Add contour lines of dem2d to highlight elevation gradients
  c = contour(dem2d, /overplot, c_color = 'black', c_thick = 1, n_levels = 14, rgb_table = 0)

  ; Plot the first lowest point with a symbol - use larger symbol for visibility
  p = plot([lowest_point[0]], [lowest_point[1]], /overplot, $
    symbol = 'circle', sym_color = 'red', sym_filled = 1, $
    sym_size = 1)

  ; Add a colorbar with fixed font size
  cb = colorbar(target = img, title = 'Thickness (m)', $
    orientation = 1, textpos = 1, font_size = 12)

  ; Initialize arrays for tracking points and lines
  point_plots = list(p)
  line_plots = list()

  ; Counter already initialized earlier
  counter2 = 2 ; Initialize to 2 since we already have 2 points in lowest_point_save

  while lowest_point[0] - dist gt 0 && lowest_point[0] + dist lt rows && $
    lowest_point[1] - dist gt 0 && lowest_point[1] + dist lt cols do begin
    counter2++
    ; print, 'counter2 = ', counter2

    counter = 0
    lowest_point_candidate = fltarr(1000, 3) ; Reset candidate array

    for i = lowest_point[0] - dist, lowest_point[0] + dist do begin
      for j = lowest_point[1] - dist, lowest_point[1] + dist do begin
        distance = round(sqrt((i - lowest_point[0]) ^ 2 + (j - lowest_point[1]) ^ 2))

        ; Calculate distances to previous points
        if counter2 eq 3 then begin
          distances_to_previous = [99999] ; For first attempt, no previous points
        endif else begin
          distances_to_previous = fltarr(counter2 - 2)
          for k = 0, counter2 - 3 do begin
            distances_to_previous[k] = round(sqrt((i - lowest_point_save[k, 0]) ^ 2 + (j - lowest_point_save[k, 1]) ^ 2))
          endfor
        endelse

        if distance eq dist && n_elements(distances_to_previous) gt 0 && $
          min(distances_to_previous) gt min_dist_to_previous then begin
          if finite(dem2d[i, j]) eq 0 then continue
          lowest_point_candidate[counter, 0] = i
          lowest_point_candidate[counter, 1] = j
          lowest_point_candidate[counter, 2] = dem2d[i, j]
          counter++
        endif
      endfor
    endfor

    ; If no candidates found, exit the loop
    if counter eq 0 then break

    ; Trim to actual size
    lowest_point_candidate = lowest_point_candidate[0 : counter - 1, *]

    ; Find minimum point
    min_val = min(lowest_point_candidate[*, 2], min_idx)
    lowest_point[0] = lowest_point_candidate[min_idx, 0]
    lowest_point[1] = lowest_point_candidate[min_idx, 1]
    lowest_point[2] = lowest_point_candidate[min_idx, 2]
    ; print, 'lowest_point = ', lowest_point

    lowest_point_save[counter2 - 1, *] = lowest_point

    ; Add new point to the plot - use larger symbol for visibility
    p = plot([lowest_point[0]], [lowest_point[1]], /overplot, $
      symbol = 'circle', sym_color = 'red', sym_filled = 1, $
      sym_size = 1)
    point_plots.add, p

    ; Add connecting line between points for better visualization
    if counter2 gt 2 then begin
      l = plot([lowest_point_save[counter2 - 2, 0], lowest_point[0]], $
        [lowest_point_save[counter2 - 2, 1], lowest_point[1]], $
        /overplot, color = 'red', thick = 1.5)
      line_plots.add, l
    endif

    ; Force display update
    w.refresh
    wait, 0.1 ; Pause for visualization
  endwhile

  ; Ensure the directory exists
  save_dir = 'flow/input/centraleurope/dem_extended/'
  if ~file_test(save_dir, /directory) then file_mkdir, save_dir

  ; Save the results as a .sav file
  save_file = save_dir + 'prefrontal_elev_' + string(glacier_id, format = '(I05)') + '.sav'
  ; Trim lowest_point_save to the actual number of points
  lowest_point_save = lowest_point_save[0 : counter2 - 1, *]
  save, lowest_point_save, filename = save_file
  print, 'Saved results to: ' + save_file

  ; Save the figure from the while loop
  output_file = save_dir + string(glacier_id, format = '(I05)') + '_flowline_front.png'
  w.save, output_file, /png
  print, 'Saved figure to: ' + output_file

  RETURN, 1
end
