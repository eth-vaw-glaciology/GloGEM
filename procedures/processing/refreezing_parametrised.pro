compile_opt idl2

; ----- simple and fast refreezing model

ii = where(gl ne noval, ci)
for i = 0, ci - 1 do begin

   ; taking a lower threshold for initialising than for full refreezing model
   ; refreezing occurs only in firn area
   ; an upper bound for refreezing is defined (how to exactly set?)
   ; refreezing dependent on cumulative air temperature over winter season
   rf_cold[ii[i]] = rf_cold[ii[i]] + tg[ii[i]]
   scaling_annual_temp = abs(mean(rf_cold)) / 30.
   if mel[ii[i]] gt rf_melcrit / 4. and rf_cold[ii[i]] lt -50 and rf_ind[ii[i]] lt rf_melcrit * scaling_annual_temp * firn[ii[i]] then begin  
      rf_ind[ii[i]] = rf_ind[ii[i]] + mel[ii[i]]
      refr[ii[i]] = min([mel[ii[i]], rf_melcrit * scaling_annual_temp * firn[ii[i]]])
   endif

endfor

; if min(rf_cold) lt -10 then stop
if ar_gl ne 0 then refre[ye] = refre[ye] + total(refr * area) / ar_gl