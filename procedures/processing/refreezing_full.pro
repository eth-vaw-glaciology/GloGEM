compile_opt idl2

  noval=-9999 & snoval=-99
  ii=where(gl ne noval,ci)
for i=0,ci-1 do begin

if mel[ii[i]] lt rf_melcrit then rf_ind[ii[i]]=1 else rf_ind[ii[i]]=0

if rf_ind[ii[i]] eq 1 then begin     ; start builing up cold reservoir

   for h=0,rf_dsc-1 do begin

      ; heat conduction
      for j=1,rf_layers-2 do begin

         tl_rf[ii[i],0]=tgs[ii[i]]
         te_rf[ii[i],j]=tl_rf[ii[i],j]+((rf_dt*cond[j]/(cap[j])*(tl_rf[ii[i],j-1]-tl_rf[ii[i],j])/rf_dz^2.)- $
             (rf_dt*cond[j]/(cap[j])*(tl_rf[ii[i],j]-tl_rf[ii[i],j+1])/rf_dz^2.))/2. ; division by 2 to be removed?! keeping it for consistency at the moment...
         tl_rf[ii[i],*]=te_rf[ii[i],*]

      endfor
   endfor

endif else begin
; ----------------------------
; evaluating cold reservoir

; refreezing over firn surface
if firn[ii[i]] eq 1 then begin

if rf_cold[ii[i]] eq 0 then for j=1,rf_layers-2 do rf_cold[ii[i]]=rf_cold[ii[i]]+(-1)*tl_rf[ii[i],j]*cap[j]*rf_dz/Lh_rf
if (mel[ii[i]]+plg[ii[i]]) lt rf_cold[ii[i]] then refr[ii[i]]=(mel[ii[i]]+plg[ii[i]]) else if rf_cold[ii[i]] gt 0 then refr[ii[i]]=rf_cold[ii[i]]
rf_cold[ii[i]]=rf_cold[ii[i]]-mel[ii[i]]-plg[ii[i]]
if rf_cold[ii[i]] lt 0 then rf_cold[ii[i]]=snoval
if rf_cold[ii[i]] eq snoval then tl_rf[ii[i],*]=0  ; temperate firn if cold reservoir used

endif else begin
; refreezing over ice surface

pp=0.3   ; add a bit more as water can also refreeze directly at bare-ice surface
smax=round(sno[ii[i]]/(dens_rf[0]/1000.)/rf_dz+pp) & if sno[ii[i]] gt 0 and smax eq 0 then smax=1 & if smax eq 0 then rf_cold[ii[i]]=snoval
if smax gt rf_layers-1 then smax=rf_layers-1
if rf_cold[ii[i]] eq 0 then for j=1,smax do rf_cold[ii[i]]=rf_cold[ii[i]]+(-1)*tl_rf[ii[i],j]*cap[j]*rf_dz/Lh_rf
if (mel[ii[i]]+plg[ii[i]]) lt rf_cold[ii[i]] then refr[ii[i]]=(mel[ii[i]]+plg[ii[i]]) else if rf_cold[ii[i]] gt 0 then refr[ii[i]]=rf_cold[ii[i]]
rf_cold[ii[i]]=rf_cold[ii[i]]-mel[ii[i]]-plg[ii[i]]
if rf_cold[ii[i]] lt 0 then rf_cold[ii[i]]=snoval
if rf_cold[ii[i]] eq snoval then tl_rf[ii[i],*]=0    ; temperate firn if cold reservoir used

endelse

endelse    ; use cold reservoir

endfor

if ar_gl ne 0 then refre[ye]=refre[ye]+total(refr*area)/ar_gl
