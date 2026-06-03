; *************************************************************
; calving_model
;
; Calving model of the Mass balance model
; This procedure calculates frontal ablation (calving), employing a modified version of the approach proposed by Oerlemans and Nick (2005).
; It first identifies if a glacier is water-terminating by analyzing the bed elevation at the terminus (i.e., if the bed elevation is below zero).
; The height of the calving front (Hf) is calculated using the formula Hf = max(af * L^(1/2), δ * d), where af is a constant (0.7 m^(1/2)), L is the glacier length,
; δ is the ratio of water density to ice density, and d is the water depth at the glacier terminus (obtained from surface elevation and ice thickness).
; Annual frontal ablation (F) is computed as a function of Hf, water depth (d), and the effective width (w) of the calving front, using the formula F = max(0, k * d * Hf) * w.
; The parameter k is assumed to be linearly dependent on the average slope βt of the glacier terminus (defined by elevation bands between 0 and 100 m a.s.l.),
; such that k = k0 * βt. k0 is a region-specific parameter.
; The procedure also includes a constraint on the maximum frontal ablation based on the total accumulated volume of the glacier to avoid unrealistically high calving rates.
; The results are stored in the variable q_calv, representing the frontal ablation in Gt/a, and the specific frontal ablation in m/a.
; *************************************************************

compile_opt idl2

ii = where(thick gt 0, ci)
fa = 'n'
if ci gt 6 then begin
  jj = where(bed_elev[ii] lt 0, cj)
  if min(bed_elev[ii[0 : 1]]) lt 0 and cj gt 1 then fa = 'y'
endif
q_calv = 0.
dvolsurf = dvol

if frontal_ablation eq 'y' and fa eq 'y' then begin
  Hf = max([alpha_f * (length[ii[0]] * 1000. * length_corrfact) ^ 0.5, -1.127 * mean(bed_elev_p[ii[0 : 1]])])
  ; F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])
  F = min([0, c_calving * mean(bed_elev_p[ii[0 : 1]]) * Hf * mean(slope[ii[1 : min([11, ci - 1])]])])
  ; F=min([0,c_calving*mean(bed_elev(ii(0):ii(1)))*Hf])
  ; F=min([0,c_calving*mean(bed_elev(ii(0:1)))*Hf])

  ; q_front=F*mean(width(ii(0:1)))*(-1.)
  frontal_width = mean(width[ii[0 : 1]])
  ccorr_param = crit_ccorrdist / (crit_ccorrdist) ^ (1 / ccorr_expon)
  if frontal_width lt crit_ccorrdist then eff_width = frontal_width $
  else eff_width = (frontal_width) ^ (1 / ccorr_expon) * ccorr_param
  q_front = F * eff_width * (-1.)

  ; restricting frontal ablation to total accumulated volume to avoid
  ; unrealistically (climatological sense) high frontal ablation rates!!

  ; * implementation until Jan 2021
  ; if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.75
  ; different constraints for antarctica
  ; if dir_region eq 'Antarctic' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.25
  ; if dir_region eq 'Greenland' then if glacier_retreat eq 'y' then fcfact=5.0 else fcfact=0.40
  ; * implementation from feb 2021 - keep threshold constant, also for future to avoid break
  fcfact = 1.0

  tt = total(area) * max(acc) * 1000000. * fcfact
  ; low calving losses are always possible...
  if tt lt 0.2 * total(area) * 1000000. then tt = 0.2 * total(area) * 1000000.
  if q_front gt tt[0] then q_front = tt

  q_front_spec = q_front / 1000000. * dens / ar_gl
  if q_front_spec lt calv_sep then F = 1. else F = 1 - ((q_front_spec - calv_sep) / q_front_spec)
  dvol = dvol - (q_front * F)
  q_calv = q_front - (q_front * F)
  flux_calv[ye] = q_front_spec
  ; if single_glacier ne '' then print, 'Frontal ablation (Gt/a): ('+string(ye+tran(0),fo='(i4)')+')'+string(q_front/1000000000.,fo='(f8.4)')
  ; if q_front/1000000000. gt 0.1 then print, 'Frontal ablation (Gt/a): ('+id(gg(g))+')'+string(q_front/1000000000.,fo='(f8.4)')

  if ye eq tran[0] then if q_front / 1000000000. gt 0.0005 then printf, 33, id[gg[g]], total(area), q_front / 1000000000., fo = '(a,2f10.4)'
endif
