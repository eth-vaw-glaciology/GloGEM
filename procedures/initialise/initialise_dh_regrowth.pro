; *************************************************************
; initialise_dh_regrowth
;
; Thickness limit of each band for the Δh regrowth (dh_regrowth='y', dh_regrowth.pro):
;   dhr_hmax = tau_g / (rho g sin(slope)), and never less than the inventory thickness.
; tau_g is the area-weighted dh_regrowth_tau_pct percentile of this glacier's inventory
; basal stress rho g H sin(slope), at least dh_regrowth_tau_min. The slope is the band's
; along-flow slope from the band file, averaged over the inventory bands within +-5 bands,
; at least 2 degrees; bands without inventory ice take that of the nearest inventory band.
; Also the terminus band of the inventory (mean area and thickness of its lowest
; adv_terminusfraction of bands, as the advance scheme) for bands beyond the inventory front.
; *************************************************************

compile_opt idl2

dhr_rhog = 900d0 * 9.81d0
dhr_inv = where(area_iniconst gt 0, dhr_ninv)
dhr_sl = dblarr(nb) + 10d0
dhr_iniar = 0d0 & dhr_inithi = 0d0
if dhr_ninv gt 0 then begin
  dhr_tt = (fix(dhr_ninv * adv_terminusfraction) - 1) > 0
  dhr_iniar = mean(area_iniconst[dhr_inv[0:dhr_tt]]) & dhr_inithi = mean(thick_ini[dhr_inv[0:dhr_tt]])
  for i = 0, dhr_ninv - 1 do $
    dhr_sl[dhr_inv[i]] = mean(slope[dhr_inv[where(abs(dhr_inv - dhr_inv[i]) le 5)]])
  dhr_sl = dhr_sl > 2d0
  for i = 0, nb - 1 do if area_iniconst[i] le 0 then begin
    dhr_d = min(abs(dhr_inv - i), dhr_k)
    dhr_sl[i] = dhr_sl[dhr_inv[dhr_k]]
  endif
  dhr_tb = dhr_rhog * thick_ini[dhr_inv] * sin(dhr_sl[dhr_inv] * !dpi / 180d0)
  dhr_o = sort(dhr_tb)
  dhr_c = total(area_iniconst[dhr_inv[dhr_o]], /cumulative) / total(area_iniconst[dhr_inv])
  dhr_tau = dhr_tb[dhr_o[(where(dhr_c ge dh_regrowth_tau_pct))[0]]] > dh_regrowth_tau_min
endif else dhr_tau = dh_regrowth_tau_min
dhr_hmax = (dhr_tau / (dhr_rhog * sin(dhr_sl * !dpi / 180d0))) > thick_ini
