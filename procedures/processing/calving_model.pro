compile_opt idl2

  ii=where(thick gt 0,ci) & fa='n' 
if ci gt 6 then begin
   jj=where(bed_elev[ii] lt 0,cj)
   if min(bed_elev[ii[0:1]]) lt 0 and cj gt 1 then fa='y'
endif
q_calv=0. & dvolsurf=dvol

if frontal_ablation eq 'y' and fa eq 'y' then begin

Hf=max([alpha_f*(length[ii[0]]*1000.*length_corrfact)^0.5,-1.127*mean(bed_elev_p[ii[0:1]])])
;F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])
F=min([0,c_calving*mean(bed_elev_p[ii[0:1]])*Hf*mean(slope[ii[1:min([11,ci-1])]])])
;F=min([0,c_calving*mean(bed_elev(ii(0):ii(1)))*Hf])
;F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])

;q_front=F*mean(width(ii(0:1)))*(-1.)
frontal_width=mean(width[ii[0:1]])
ccorr_param=crit_ccorrdist/(crit_ccorrdist)^(1/ccorr_expon)
if frontal_width lt crit_ccorrdist then eff_width=frontal_width $
  else eff_width=(frontal_width)^(1/ccorr_expon)*ccorr_param
q_front=F*eff_width*(-1.)

; restricting frontal ablation to total accumulated volume to avoid
; unrealistically (climatological sense) high frontal ablation rates!!

; * implementation until Jan 2021
;if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.75
; different constraints for antarctica
;if dir_region eq 'Antarctic' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.25   
;if dir_region eq 'Greenland' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.40   
; * implementation from feb 2021 - keep threshold constant, also for future to avoid break
fcfact=1.0

tt=total(area)*max(acc)*1000000.*fcfact
; low calving losses are always possible...
if tt lt 0.2*total(area)*1000000. then tt=0.2*total(area)*1000000.
if q_front gt tt[0] then q_front=tt


q_front_spec=q_front/1000000.*dens/ar_gl
if q_front_spec lt calv_sep then f=1. else f=1-((q_front_spec-calv_sep)/q_front_spec)
dvol=dvol-(q_front*f) & q_calv=q_front-(q_front*f)
flux_calv[ye]=q_front_spec
;if single_glacier ne '' then print, 'Frontal ablation (Gt/a): ('+string(ye+tran(0),fo='(i4)')+')'+string(q_front/1000000000.,fo='(f8.4)')
;if q_front/1000000000. gt 0.1 then print, 'Frontal ablation (Gt/a): ('+id(gg(g))+')'+string(q_front/1000000000.,fo='(f8.4)')

if ye eq tran[0] then if q_front/1000000000. gt 0.0005 then printf,33, id[gg[g]],total(area),q_front/1000000000.,fo='(a,2f10.4)'

endif
