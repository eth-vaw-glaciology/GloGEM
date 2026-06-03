compile_opt idl2

; ----- simple and fast refreezing model

; Find valid indices
ii = where(gl ne noval, ci)

if ci gt 0 then begin
   ; Update rf_cold for all valid indices
   if time_resolution eq 'monthly' then begin
      rf_cold[ii] = rf_cold[ii] + tg[ii]
      scaling_annual_temp = abs(mean(rf_cold)) / 30.
   endif else begin
      rf_cold[ii] = rf_cold[ii] + tg[ii] / 30.
      scaling_annual_temp = abs(mean(rf_cold)) / 10.
   endelse

   ; Apply conditions as a mask
   valid = where((mel[ii] gt rf_melcrit / 4.) and (rf_cold[ii] lt -50) and $
                 (rf_ind[ii] lt rf_melcrit * scaling_annual_temp * firn[ii]), count)

   if count gt 0 then begin
      ; Update rf_ind and refr for valid indices
      rf_ind[ii[valid]] = rf_ind[ii[valid]] + mel[ii[valid]]
      refr[ii[valid]] = min([[mel[ii[valid]], $
                              rf_melcrit * scaling_annual_temp * firn[ii[valid]]]], dimension=1)
   endif
endif

; Update refreezing total
if ar_gl ne 0 then refre[ye] = refre[ye] + total(refr * area) / ar_gl