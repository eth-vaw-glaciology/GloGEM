function load_lowerpart_function, glacier_id, dist, min_dist_to_previous
  compile_opt idl2

  ; ; Surface elevation (DEM)
  t_start = systime(/seconds)
  print, 'glacier_id: ', glacier_id

  ; Read the DEM grid
  dem_file = main_dir + '/geometricdata/' + 'rgiv' + RGIversion + '/grids/' + region + '/dem/dem_' + glacier_id + '.grid'
  print, 'Reading: ', dem_file
  ; Open the file to read just the first 6 lines (header)
  openr, lun, dem_file, /get_lun
  header_lines = strarr(6)
  readf, lun, header_lines
  free_lun, lun

  ncols = fix(data[0, 0])
  nrows = fix(data[1, 0])
  dx = data[4, 1]
  xllcorner = data[2, 1]
  yllcorner = data[3, 1]
  print, 'ncols = ', ncols
  print, 'nrows = ', nrows
  print, 'dx = ', dx

  ; Transform matrix to array
  data_array = reform(transpose(data[6 : *, *]), n_elements(data[6 : *, *]))
  i = where(finite(data_array) eq 0, count)
  if count gt 0 then data_array[i] = data_array[where(finite(data_array) eq 1, /null)]

  ; From array to (correct) matrix
  data_matrix = reform(data_array, [ncols, nrows])
  dem2d = transpose(data_matrix)
  i = where(dem2d lt -1000, count)
  if count gt 0 then dem2d[i] = !values.f_nan ; Handle bugs like glacier id 1559

  ; ; Glacier mask (thickness)
  t_start = systime(/seconds)

  ; Read thickness grid
  thick_file = 'thickness_extended/thick_' + string(glacier_id, format = '(I05)') + '.agr'
  print, 'Reading: ', thick_file
  data = read_ascii(thick_file)
  data = data.field1
  print, 'Time elapsed: ', systime(/seconds) - t_start

  ; Transform matrix to array
  data_array = reform(transpose(data[6 : *, *]), n_elements(data[6 : *, *]))
  i = where(finite(data_array) eq 0, count)
  if count gt 0 then data_array[i] = data_array[where(finite(data_array) eq 1, /null)]

  ; From array to (correct) matrix
  data_matrix = reform(data_array, [ncols, nrows])
  thick2d = transpose(data_matrix)

  ; ; Plots
  thick2d_plot = thick2d
  i = where(thick2d_plot eq 0, count)
  if count gt 0 then thick2d_plot[i] = !values.f_nan

  ; ; Reconstruct the bedrock for the lower parts:
  ; Start by finding the position and elevation of front
  s = size(thick2d, /dimensions)
  rows = s[0]
  cols = s[1]
  counter = 0
  lowest_point_candidate = fltarr(1000, 3) ; Pre-allocate with reasonable size

  for i = 1, rows - 2 do begin
    for j = 1, cols - 2 do begin
      if thick2d[i, j] gt 0 then begin ; There is ice
        if thick2d[i - 1, j + 1] eq 0 || thick2d[i - 1, j] eq 0 || thick2d[i - 1, j - 1] eq 0 || $
          thick2d[i, j + 1] eq 0 || thick2d[i, j - 1] eq 0 || $
          thick2d[i + 1, j + 1] eq 0 || thick2d[i + 1, j] eq 0 || thick2d[i + 1, j - 1] eq 0 then begin
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
  print, 'lowest_point = ', lowest_point

  ; Initialize lowest_point_save (needed for later)
  lowest_point_save = fltarr(1000, 3) ; Pre-allocate with reasonable size
  lowest_point_save[0, *] = lowest_point ; First row
  lowest_point_save[1, *] = lowest_point ; Second row

  ; Create the figure
  WINDOW, 0, xsize = 800, ysize = 600, title = 'Glacier Front Analysis'
  loadct, 39

  ; Plot thickness with color
  tv_thick = bytscl(thick2d_plot)
  tvscl, tv_thick

  ; Plot the lowest point
  plots, lowest_point[1] + 0.5, lowest_point[0] + 0.5, psym = 8, color = 250, symsize = 2

  ; Add contour of DEM
  CONTOUR, dem2d, /overplot, c_labels = [1], c_colors = 255

  xyouts, 20, 20, 'Column', /device, charsize = 1.2
  xyouts, 5, 100, 'Row', /device, charsize = 1.2, orientation = 90

  counter2 = 2
  while lowest_point[0] - dist gt 0 && lowest_point[0] + dist lt rows && $
    lowest_point[1] - dist gt 0 && lowest_point[1] + dist lt cols do begin
    counter2++
    print, 'counter2 = ', counter2

    counter = 0
    lowest_point_candidate = fltarr(1000, 3) ; Reset candidate array

    for i = lowest_point[0] - dist, lowest_point[0] + dist do begin
      for j = lowest_point[1] - dist, lowest_point[1] + dist do begin
        distance = round(sqrt((i - lowest_point[0]) ^ 2 + (j - lowest_point[1]) ^ 2))

        ; Calculate distances to previous points
        if counter2 eq 3 then begin
          distances_to_previous = 99999 ; For first attempt, no previous points
        endif else begin
          distances_to_previous = fltarr(counter2 - 2)
          for k = 0, counter2 - 3 do begin
            distances_to_previous[k] = round(sqrt((i - lowest_point_save[k, 0]) ^ 2 + (j - lowest_point_save[k, 1]) ^ 2))
          endfor
        endelse

        if distance eq dist && min(distances_to_previous) gt min_dist_to_previous then begin
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
    print, 'lowest_point = ', lowest_point

    lowest_point_save[counter2 - 1, *] = lowest_point

    ; Plot the new lowest point
    plots, lowest_point[1] + 0.5, lowest_point[0] + 0.5, psym = 8, color = 250, symsize = 2
    wait, 0.1 ; Pause for visualization
  endwhile

  ; Save the results
  save_file = 'dem_extended/prefrontal_elev_' + string(glacier_id, format = '(I05)') + '.sav'
  ; Trim lowest_point_save to the actual number of points
  lowest_point_save = lowest_point_save[0 : counter2 - 1, *]
  save, lowest_point_save, filename = save_file

  ; Save the figure as PDF - IDL doesn't have direct PDF output, so save as PNG
  output_file = 'dem_extended/' + string(glacier_id, format = '(I05)') + '_flowline_front.png'
  write_png, output_file, tvrd(true = 1)
  print, 'Saved figure to: ' + output_file

  RETURN, 1
end
