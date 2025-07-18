compile_opt idl2

for j = 0, 2 do begin
  fun = fltarr(xnum)
  for i = 2, xnum - 1 do begin
    fun[i] = ((df_dx[i - 1] + df_dx[i]) / 2.0) * ((sur[i] - sur[i - 1]) / dx)
  endfor

  for i = 1, xnum - 2 do begin
    fluxdiv_dx[i] = ((fun[i + 1] - fun[i]) / dx)
    grad_dx[i] = ((sur[i + 1] - sur[i - 1]) / (2 * dx))
    term1[i] = fluxdiv_dx[i] * width_mid_dx[i]
    term2[i] = ((width_mid_dx[i + 1] - width_mid_dx[i - 1]) / (2 * dx)) * grad_dx[i] * df_dx[i]
    term3[i] = (term1[i] + term2[i]) / width_surface_dx[i]
    if ~finite(term3[i]) then term3[i] = 0
    thick_dx[i] = thick_dx[i] + (1.0 / 3.0) * dt * (term3[i] + bal_dx[i])
  endfor

  i = where(thick_dx lt 0, count)
  if count gt 0 then thick_dx[i] = 0
  thick_dx[xnum - 1] = thick_dx[xnum - 2]

  @variables_renew
endfor
