; *************************************************************
; store_output_variables
;
; Store daily/monthly output variables for a time step
; *************************************************************

compile_opt idl2

if ar_gl ne 0 then discharge_gl[ccmon-1]=(total(mel*area)+total(plg*area)-total(refr*area))/ar_gl
if time_resolution eq 'monthly' then begin
   balmo[ccmon-1]=total((psg-mel+refr)*area)/ar_gl & melmo[ccmon-1]=total(mel*area)/ar_gl
   accmo[ccmon-1]=total(psg*area)/ar_gl & refrmo[ccmon-1]=total(refr*area)/ar_gl
   precmo[ccmon-1]=total((psg+plg)*area)/ar_gl
endif else begin
   ; for entire catchment
   accday[ccmon-1]=total((psg)*area_ini)/total(area_ini) & refrday[ccmon-1]=total(refr*area_ini)/total(area_ini)
   rainday[ccmon-1]=total((plg)*area_ini)/total(area_ini)
   snowmeltday[ccmon-1]=total((snowmel)*area_ini)/total(area_ini) & icemeltday[ccmon-1]=total((icemel)*area)/total(area_ini)
   jj=where(sno eq 0 and gl ne noval,cj)
   if cj gt 0 then begin
      snowlineday[ccmon-1]=gl[jj[cj-1]]
   endif else begin
      positive_values = gl[where(gl ge 0)]
      snowlineday[ccmon-1]=positive_values[0]
   endelse
endelse
