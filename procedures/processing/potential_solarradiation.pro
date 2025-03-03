PRO potential_solarradiation,nb,da,slope,decl_sun,latutudes,g,sw_rad

   sw_rad=dblarr(nb,12) & z=dblarr(12) & phi0=dblarr(12) & aspect=da(8,*)

   ; smooth aspect/slope -  prevent discontinuities in surface mb - does it work?
   ii=where(aspect ne 0,ci)
   if ci gt 0 then begin
      tt=dblarr(ci) & for i=0,ci-1 do tt(i)=aspect(ii(i)) & tt2=rmean(rmean(tt,11),3) & for i=0,ci-1 do aspect(ii(i))=round(tt2(i))
      tt=dblarr(ci) & for i=0,ci-1 do tt(i)=slope(ii(i)) & & tt2=rmean(rmean(tt,11),3) & for i=0,ci-1 do slope(ii(i))=tt2(i)
   endif
   ii=where(aspect eq 0,ci) & if ci gt 0 then aspect(ii)=1

   if dir_region eq 'LowLatitudes' then begin    ; check if sun perpendicular and correct
      if min(abs(latitudes(g)-decl_sun),ind) lt 0.05 then begin
         if decl_sun(ind)-latitudes(g) lt 0 then a=0.05 else a=-0.05
      endif else a=0.
   endif else a=0.
   for i=0,11 do z(i)=acos(sin((latitudes(g)+a)/180.*3.14159)*sin(decl_sun(i)/180.*3.14159)+ $
     cos((latitudes(g)+a)/180.*3.14159)*cos(decl_sun(i)/180.*3.14159))*180./3.14159
   for i=0,11 do phi0(i)=cos(z(i)/180.*3.14159)
   ii=where(phi0 lt 0.01,ci) & if ci gt 0 then phi0(ii)=0.01   ; prevent division by zero and inversion of pattern
   for j=0,nb-1 do for i=0,11 do sw_rad(j,i)=mrad(i)*(cos(slope(j)/180.*3.14159)*cos(z(i)/180.*3.14159)+ $
      sin(slope(j)/180.*3.14159)*sin(z(i)/180.*3.14159)*cos((180-asp_class(aspect(j)-1))/180.*3.14159))/phi0(i)
	ii=where(sw_rad lt 0,ci) & if ci gt 0 then sw_rad(ii)=0

end
