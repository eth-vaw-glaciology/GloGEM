; *************************************************************
; initialise_output_arrays
;
; Initialising some output arrays
; *************************************************************

compile_opt idl2

if nb gt elev_range_p/step and plot eq 'y' then begin
   accy=baly & mely=baly & refry=baly
endif
if time_resolution eq 'daily' then begin
   if outf_names[14] ne '' then begin
      accday=dblarr(years*365.)+snoval & rainday=accday & snowmeltday=accday & refrday=accday & discharge_gl=accday & icemeltday=accday & snowlineday=accday
   endif
   discharge=dblarr(years*365.)
endif else begin
   if outf_names[14] ne '' then begin
      balmo=dblarr(years*12)+snoval & melmo=balmo & accmo=balmo & refrmo=balmo & discharge_gl=balmo & precmo=balmo
      ; monthly transient snowline (highest snow-free band per month) [m a.s.l.]
      snowlinemon=balmo
   endif
   discharge=dblarr(years*12.)
endelse
mb=dblarr(years)+snoval & wb=mb
smelt=dblarr(years) & imelt=smelt & accum=smelt & rain=smelt & refre=smelt
ela=dblarr(years)+snoval & dbdz=ela & btongue=ela & aar=ela & hmin_g=ela
area_cat=total(area)

if adv_lookup eq 'y' then adv_lookup_data=dblarr(3,nb,years)
ccmon=0l
melt_rf_sum = dblarr(nb)
refr_rf_sum = dblarr(nb)
