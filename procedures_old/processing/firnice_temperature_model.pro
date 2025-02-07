PRO FIRNICE_TEMPERATURE_MODEL,gl,fit_layers,fit_dens,fit_dz, rf_dsc, tgs,tl_fit,te_fit,geothermal_flux, cair,cice,kair,kice, sno,mel,thick,slope,firn, firnice_batch,firnice_write,firnice_maxdepth, fit_water,fact_permeability,elev_firnicetemp,firnice_profile,ye,tran,m

ii=where(gl ne noval,ci)
for i=0,ci-1 do begin

; generate local, and actualized arrays for layer heat capacity, condictivity and density
dens_fit=dblarr(total(fit_layers))+900  
a=fix(sno(ii(i))/(fit_dens(1)/1000.)) ; number of snow layers
if a gt 18 then a=18            ; preventing too many layers for extreme snow depth (??)
; replacing top of density profile with snow values
for j=0,a-1 do dens_fit(j)=fit_dens(j)
; replacing top of density profile with firn values for the firn area
if firn(ii(i)) eq 1 then for j=min([a,5]),17 do dens_fit(j)=fit_dens(j) ; to be verified...

cap_fit=(1-dens_fit/1000.)*cair+dens_fit/1000.*cice
cond_fit=(1-dens_fit/1000.)*kair+dens_fit/1000.*kice

a=min(abs(thick(ii(i))-fit_dz(1,*)),ind)
if firnice_batch eq 'y' then a=min(abs(firnice_maxdepth(0)-fit_dz(1,*)),ind)  ; run to actual depth of profile in batch/validation-mode
tt=min([ind+1,total(fit_layers)])  ; either run to bedrock, or to max of layers

   for h=0,rf_dsc-1 do begin

      ; heat conduction
      for j=1,tt-2 do begin

         tl_fit(ii(i),0)=min([0,tgs(ii(i))]) ; temperature of topmost layer corresponding to air temperature or melting point!
         ; temperature of bottommost layer warmed up by geothermal heat flux (cumulative energy over one time step over a )
         ttgeot=tl_fit(ii(i),tt-1)+geothermal_flux*(3600*24*30.5/rf_dsc)/cice       ; /fit_dz(0,tt-1) ; unclear how to attribute a layer thickness for collecting flux (1m at the moment...)
         
         tl_fit(ii(i),tt-1)=min([ttgeot,(fit_dz(1,tt-1)*0.9/10.)*(-0.00742)])    ; cannot be higher than pressure melting point
         
         te_fit(ii(i),j)=tl_fit(ii(i),j)+((rf_dt*cond_fit(j)/(cap_fit(j))*(tl_fit(ii(i),j-1)-tl_fit(ii(i),j))/fit_dz(0,j)^2.)- $
             (rf_dt*cond_fit(j)/(cap_fit(j))*(tl_fit(ii(i),j)-tl_fit(ii(i),j+1))/fit_dz(0,j)^2.))/2. ; division by 2 to be removed?! result becomes unstable without ?!?
         tl_fit(ii(i),j)=te_fit(ii(i),j)

         ; set back any temperatures to pressure melting point
         if tl_fit(ii(i),j) gt (fit_dz(1,j)*0.9/10.)*(-0.00742) then tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742)

      endfor
   endfor

; setting all bedrock temperatures to lowermost computed layer (to avoid constant warming from beneath)
tl_fit(ii(i),tt-1:total(fit_layers))=tl_fit(ii(i),tt-2)

fit_water=mel(ii(i))+plg(ii(i))  ; liquid water available from surface (melt+rain)

; latent heat release over firn/snow surface (entirely permeable)
if firn(ii(i)) eq 1 then begin

for j=1,tt-2 do begin ; loop through all considered layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
 ;  if j eq 10 and ii(i) eq 245 then print, m,c,fit_water,tl_fit(ii(i),10)
endfor

endif else begin

; latent heat release over ice surface, incl. seasonal snow (mainly impermeable)

kk=where(dens_fit lt 900,ck)
for j=1,ck do begin ; loop through all SNOW layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
endfor

; reduce liquid water input through glacier ice by a factor proportional to local characteristics (thickness / slope ~flow speed)
f=(slope(ii(i))^2*fact_permeability(0))*(thick(ii(i))*fact_permeability(1))
if f gt 0.5 then f=0.5     ; setting maximum value for overall reduction factor - to be assessed 
if f lt 0.0001 then f=0.0001     ; setting minimum value for overall reduction factor - to be assessed 
fit_water=fit_water*f      ; reducing amount of water entering glacier ice

for j=ck+1,tt-2 do begin ; loop through all ICE layers from top, and update temperatures
   c=(-1)*(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*cap_fit(j)*fit_dz(0,j)/Lh_rf ; cold content in layer below pressure melting point
   if fit_water gt c then begin   ; temperate layer if cold reservoir used, remaining water being transferred
      tl_fit(ii(i),j)=(fit_dz(1,j)*0.9/10.)*(-0.00742) & fit_water=fit_water-c
   endif else begin  
      if c gt 0 and fit_water gt 0 then tl_fit(ii(i),j)=tl_fit(ii(i),j)-(tl_fit(ii(i),j)-((fit_dz(1,j)*0.9/10.)*(-0.00742)))*(fit_water/c)   
      fit_water=fit_water-c
   endelse
;   if j eq 10 and ii(i) eq 20 then print, m,c,fit_water,tl_fit(ii(i),20),f
endfor

endelse

; prepare for output
if firnice_write(0) eq 'y' then begin
         ; maximum temperature in layer during one year
   elev_firnicetemp(0,ye,ii(i))=max([elev_firnicetemp(0,ye,ii(i)),tl_fit(ii(i),2)])  ; 2m
   elev_firnicetemp(1,ye,ii(i))=max([elev_firnicetemp(1,ye,ii(i)),tl_fit(ii(i),10)]) ; 10m 
   elev_firnicetemp(2,ye,ii(i))=max([elev_firnicetemp(2,ye,ii(i)),tl_fit(ii(i),18)]) ; 50m 
   elev_firnicetemp(3,ye,ii(i))=max([elev_firnicetemp(3,ye,ii(i)),tl_fit(ii(i),30)]) ; bedrock
endif

if firnice_write(1) eq 'y' then begin
   for j=0,n_elements(firnice_profile)-1 do begin
      if ii(i) eq firnice_profile_ind(0,j) then begin
         a=tl_fit(firnice_profile_ind(0,j),1:total(fit_layers)) & a(tt-2:total(fit_layers)-1)=snoval
         printf,51+j,ye+tran(0),m,a,fo='(2i4,'+string(total(fit_layers),fo='(i2)')+'f8.3)'
      endif
   endfor
endif

endfor


end
