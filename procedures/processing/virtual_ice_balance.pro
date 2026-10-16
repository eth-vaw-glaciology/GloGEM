; *************************************************************
; virtual_ice_balance
;
; Monthly mass balance every elevation band would have if its surface were
; glacier ice (band_extension='y'). glogem.pro uses it for the bands without
; ice: the balance below today's front that the flow model and the
; elevation-band output (IGM forcing) need.
;
; It repeats GloGEM's band model for an ice surface, with its own snow cover
; (sno_v), surface type (sur_v: 1 snow, 2 firn, 0 ice) and firn cover
; (firn_v): the same accumulation (psg) and temperature (tg), the same melt
; as meltmodel.pro (degree-day model), the same snow update and January snow
; carry-over as glogem.pro. Not included: refreezing. On a glacier band
; without refreezing it gives the band's own balance.
; Called right after meltmodel.pro.
; *************************************************************

compile_opt idl2

; snow left from the previous year counts as firn, as for sno in glogem.pro
if bal_month eq dd_thresholds[2] then if m eq 1 then sno_v = sno_v - snostor_v
if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sno_v = sno_v - snostor_v
sno_v = sno_v > 0

mel_v = dblarr(nb)
v_ii = where(sur_v eq 1 and tg gt t_melt, v_ci)   ; snow
if v_ci gt 0 then mel_v[v_ii] = DDFsnow * tg[v_ii] * mon_len[m - 1] / 1000.
v_ii = where(sur_v eq 2 and tg gt t_melt, v_ci)   ; firn
if v_ci gt 0 then mel_v[v_ii] = (0.5 * DDFice + 0.5 * DDFsnow) * tg[v_ii] * mon_len[m - 1] / 1000.
v_ii = where(sur_v eq 0 and tg gt t_melt, v_ci)   ; ice
if v_ci gt 0 then mel_v[v_ii] = DDFice * tg[v_ii] * mon_len[m - 1] / 1000.

bal_v = bal_v + psg - mel_v

; snow cover and surface type for the next month
sno_v = (sno_v + psg - mel_v) > 0
sur_v = dblarr(nb)
sur_v[where(firn_v eq 1, /null)] = 2
sur_v[where(sno_v gt 0, /null)] = 1
