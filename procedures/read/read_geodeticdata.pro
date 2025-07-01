pro read_geodeticdata, dir, dir_region, region_loop_data, calibrate_glacierspecific_period, calimb_bn, calimb_p0, calimb_p1, calimb_gid
  compile_opt idl2

  ii = where(dir_region eq region_loop_data[2, *])
  fn = dir + 'geodetic/aggregated_' + calibrate_glacierspecific_period + '/' + strcompress(region_loop_data[1, ii], /remove_all) + '_mb_glspec.dat'
  anz = file_lines(fn) - 3
  anz = anz[0]
  calimb_gid = strarr(anz)
  tt = strarr(anz)
  calimb_idname = dblarr(anz) + 9
  a = strsplit(calibrate_glacierspecific_period, '_', /extract)
  calimb_p0 = dblarr(anz) + double(a[0])
  calimb_p1 = dblarr(anz) + double(a[1]) - 1
  tt2 = dblarr(6, anz)
  b = strarr(anz)
  s = strarr(3)
  openr, 1, fn
  readf, 1, s
  readf, 1, b
  close, 1
  for i = 0l, anz - 1 do begin
    a = strsplit(b[i], ' ', /extract)
    tt[i] = a[0]
    for j = 0, 5 do tt2[j, i] = a[1 + j]
  endfor
  for i = 0l, anz - 1 do calimb_gid[i] = strmid(tt[i], 9, 5)
  calimb_bn = tt2[3, *]
  ; filtering geodetic mass balances - replace strange values with regional mean IF area smaller than 20 km2 (trusting large glaciers)
  ii = where(tt2[5, *] eq 1, ci)
  jj = where(tt2[5, *] eq 2, cj)
  if (cj eq 0) then calimb_bn[ii[ci - 1]] = total(tt2[0, ii] * calimb_bn[ii]) / total(tt2[0, ii])
  ; excluding values beyond 2 standard deviations
  a = stdev(calimb_bn[ii])
  jj = where(calimb_bn[ii] lt mean(calimb_bn[ii]) - 2 * a and tt2[0, ii] lt 20, cj)
  if cj gt 0 then calimb_bn[ii[jj]] = calimb_bn[anz - 1]
  jj = where(calimb_bn[ii] gt mean(calimb_bn[ii]) + 2 * a and tt2[0, ii] lt 20, cj)
  if cj gt 0 then calimb_bn[ii[jj]] = calimb_bn[anz - 1]
end
