; ***************************************
; Accumulation of the mass balance model
; ***************************************
; This procedure calculates the accumulation of the mass balance model.
; It is called by the main procedure for each year and month/day of the simulation.
; The precipitation is extrapolated with elevation (dpdz) and constrained at high elevations.
; The state of precipitation (snow or rain) is determined based on a temperature threshold T_thres.

compile_opt idl2

pc = prec[jjclim[0] + ccmon] * c_prec / 1000. ; correct quantity to m w.e.
pg = pc + pc * ((elev - hclim) / 10000.) * dpdz ; extrapolate with elevation
; constrain high elevation precipitation
jj = where(gl ne noval, cj)
if cj * step gt no_incprec[1] then begin
  ii = where(elev gt elev[jj[fix(cj * no_incprec[0])]], ci)
  if ii[0] eq 0 then a = 1 else a = 0
  for i = 0, ci - 1 do pg[ii[i]] = pg[ii[a] - 1] - pg[ii[a] - 1] * no_incprec[2] * (i / double(ci) * (1 - no_incprec[0])) ^ no_incprec[3]
endif
; state of precipitation
ii = where(tg lt T_thres - 1, ci)
if ci gt 0 then psg[ii] = pg[ii]
ii = where(tg gt T_thres - 1 and tg lt T_thres + 1, ci)
if ci gt 0 then psg[ii] = pg[ii] * (-(tg[ii] - T_thres - 1.) / 2.)
plg = pg - psg
psg = psg * snow_multiplier

if ar_gl ne 0 then accum[ye] = accum[ye] + total(psg * area) / ar_gl
if ar_gl ne 0 then rain[ye] = rain[ye] + total(plg * area) / ar_gl

ccmon = ccmon + 1
