compile_opt idl2

for j = 0, 2 do begin
  fun = fltarr(xnum)
  for i = 2, xnum - 1 do begin
    fun[i] = ((df_x[i - 1] + df_x[i]) / 2.0) * ((sur[i] - sur[i - 1]) / dx)
  endfor

  for i = 1, xnum - 2 do begin
    fluxdiv_x[i] = ((fun[i + 1] - fun[i]) / dx)
    grad_x[i] = ((sur[i + 1] - sur[i - 1]) / (2 * dx))
    term1[i] = fluxdiv_x[i] * width_mid[i]
    term2[i] = ((width_mid[i + 1] - width_mid[i - 1]) / (2 * dx)) * grad_x[i] * df_x[i]
    term3[i] = (term1[i] + term2[i]) / width_surface[i]
    if ~finite(term3[i]) then term3[i] = 0
    th_x[i] = th_x[i] + (1.0 / 3.0) * dt * (term3[i] + bal_x[i])
  endfor

  i = where(th_x lt 0, count)
  if count gt 0 then th_x[i] = 0
  th_x[xnum - 1] = th_x[xnum - 2]

  @variables_renew
endfor
