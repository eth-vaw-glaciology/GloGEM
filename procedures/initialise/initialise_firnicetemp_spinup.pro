; *************************************************************
; initialise_firnicetemp_spinup
;
; Initialise glacier retreat flags and firn/ice temperature arrays.
;
; Sets glacier_retreat to 'n' for hindcast/startyear runs, resets
; the month counter, and initialises the firn/ice temperature
; arrays using a long-term annual mean air temperature spin-up.
; *************************************************************

compile_opt idl2

if hindcast_dynamic eq 'y' then glacier_retreat='n'
if find_startyear eq 'y' then glacier_retreat='n'
if find_startyear eq 'n' then glacier_retreat='n'

ccmon=0l

te_rf=dblarr(nb,rf_layers) & tl_rf=te_rf

; initialise with long-term annual mean air temperature for efficient spin-up
tt=dblarr(nb) & ii=where(cyear lt 2020,ci)
for i=0,nb-1 do begin
   if ci gt 0 then a=temp[ii]+(elev[i]-hclim)*mean(dtdz)+t_offset $
     else a=temp+(elev[i]-hclim)*mean(dtdz)+t_offset
   tt[i]=mean(a)
endfor
te_fit=dblarr(nb,total(fit_layers)+1)
for i=0,nb-1 do te_fit[i,*]=tt[i] & tl_fit=te_fit
