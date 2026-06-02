; ***************************************
; Calculate catchment discharge
; ***************************************

compile_opt idl2

difarea=area_iniconst-area & ii=where(difarea lt 0,ci) & if ci gt 0 then difarea[ii]=0
ii=where(area_iniconst gt 0,ci) & dd=0
for i=0l,ci-1 do begin
   if sur[ii[i]] eq 1 then dd=dd+mel[ii[i]]*area_iniconst[ii[i]]+plg[ii[i]]*area_iniconst[ii[i]]-refr[ii[i]]*area_iniconst[ii[i]]-corrdis[ii[i]]*difarea[ii[i]] $
   else begin
      if area_iniconst[ii[i]] lt area[ii[i]] then a=area_iniconst[ii[i]] else a=area[ii[i]]
      dd=dd+mel[ii[i]]*a+plg[ii[i]]*area_iniconst[ii[i]]-refr[ii[i]]*a
   endelse
endfor
discharge[ccmon-1]=dd/area_cat