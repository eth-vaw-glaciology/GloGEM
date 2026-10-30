; *************************************************************
; virtual_ice_balance
;
; Monthly mass balance every band of the domain (initialise_band_extension.pro: the extension bands
; below the glacier, then the glacier's bands) would have if its surface were glacier ice
; (band_extension='y'). store_band_extension.pro writes it for the bands without ice.
;
; It repeats GloGEM's band model for an ice surface, with its own snow cover (sno_v), surface type
; (sur_v: 1 snow, 2 firn, 0 ice), firn cover (firn_v) and refreezing state (rf_cold_v, rf_ind_v):
; the same accumulation, the same melt as meltmodel.pro (degree-day model), the same snow update and
; January snow carry-over as glogem.pro.
; Every band is computed at its output row's elevation (elev0), also where the glacier's surface has moved.
; Parameters: the glacier's own down to its front; below it they blend linearly into the regional
; medians over band_blend_depth (weight w_v). Where w_v > 0 or the band is not at the glacier's own
; elevation, temperature and snowfall are recomputed with the (blended) offset and precipitation factor,
; as accumulation.pro and the sub-monthly step of meltmodel.pro do.
; Refreezing: bands with ice keep their own (refreezing_parametrised.pro); bands without ice get the
; same expression among themselves.
; On a glacier band at its own elevation it gives the band's own balance.
; Called after the refreezing step and before the snow update.
; *************************************************************

compile_opt idl2

; inputs on the domain, at the elevations of the output rows (elev0): the extension bands, and glacier
; bands whose surface has moved (changing geometry), take the temperature glogem.pro gives a band at that
; elevation (accumulation.pro advanced ccmon already); their snowfall is recomputed below (v_rc)
v_ice = reform(gl ne noval, nb) & v_tgs = reform(tgs, nb) & v_tg = reform(tg, nb)
v_psg = reform(psg, nb) & v_refr = reform(refr, nb) & v_elev = reform(elev0, nb)
v_rc = reform(elev ne elev0, nb)
v_ii = where(v_rc, v_ci)
if v_ci gt 0 then v_tgs[v_ii] = temp[jjclim[0] + ccmon - 1] + (v_elev[v_ii] - hclim) * dtdz[m - 1] + t_offset
if bx_n gt 0 then begin
  v_tgs = [temp[jjclim[0] + ccmon - 1] + (bx_elev - hclim) * dtdz[m - 1] + t_offset, v_tgs]
  v_tg = [v_tgs[0 : bx_n - 1], v_tg] & v_psg = [dblarr(bx_n), v_psg] & v_refr = [dblarr(bx_n), v_refr]
  v_elev = [bx_elev, v_elev] & v_ice = [bytarr(bx_n), v_ice] & v_rc = [replicate(1b, bx_n), v_rc]
endif

; snow left from the previous year counts as firn, as for sno in glogem.pro
if bal_month eq dd_thresholds[2] then if m eq 1 then sno_v = sno_v - snostor_v
if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sno_v = sno_v - snostor_v
sno_v = sno_v > 0

; temperature (tg_v after the sub-monthly step, tgr_v before it) and snowfall
tg_v = v_tg & tgr_v = v_tgs & psg_v = v_psg
v_bl = where(w_v gt 0 or v_rc eq 1, v_cbl)
if v_cbl gt 0 then begin
  tgr_v[v_bl] = v_tgs[v_bl] + toff_v[v_bl] - t_offset
  tg_v[v_bl] = tgr_v[v_bl]
  if time_resolution eq 'monthly' and submonth_variability eq 'y' then begin
    v_a = variab[m - 1, 0 : mon_len[m - 1] - 1] - mean(variab[m - 1, 0 : mon_len[m - 1] - 1])
    for v_k = 0l, v_cbl - 1 do begin
      v_pdd = total((tgr_v[v_bl[v_k]] + v_a) > 0)
      if v_pdd gt 0 then tg_v[v_bl[v_k]] = v_pdd / mon_len[m - 1]
    endfor
  endif
  v_pc = prec[jjclim[0] + ccmon - 1] * cprec_v[v_bl] / 1000.   ; accumulation.pro advanced ccmon already
  v_pg = v_pc + v_pc * ((v_elev[v_bl] - hclim) / 10000.) * dpdz
  v_ps = dblarr(v_cbl)
  v_s = where(tgr_v[v_bl] lt T_thres - 1, v_cs)
  if v_cs gt 0 then v_ps[v_s] = v_pg[v_s]
  v_s = where(tgr_v[v_bl] gt T_thres - 1 and tgr_v[v_bl] lt T_thres + 1, v_cs)
  if v_cs gt 0 then v_ps[v_s] = v_pg[v_s] * (-(tgr_v[v_bl[v_s]] - T_thres - 1.) / 2.)
  psg_v[v_bl] = v_ps * snow_multiplier
endif

mel_v = dblarr(nv)
v_ii = where(sur_v eq 1 and tg_v gt t_melt, v_ci)   ; snow
if v_ci gt 0 then mel_v[v_ii] = ddfs_v[v_ii] * tg_v[v_ii] * mon_len[m - 1] / 1000.
v_ii = where(sur_v eq 2 and tg_v gt t_melt, v_ci)   ; firn
if v_ci gt 0 then mel_v[v_ii] = (0.5 * ddfi_v[v_ii] + 0.5 * ddfs_v[v_ii]) * tg_v[v_ii] * mon_len[m - 1] / 1000.
v_ii = where(sur_v eq 0 and tg_v gt t_melt, v_ci)   ; ice
if v_ci gt 0 then mel_v[v_ii] = ddfi_v[v_ii] * tg_v[v_ii] * mon_len[m - 1] / 1000.

; refreezing as refreezing_parametrised.pro
refr_v = dblarr(nv)
if time_resolution eq 'monthly' then rf_cold_v = rf_cold_v + tg_v else rf_cold_v = rf_cold_v + tg_v / 30.
if refreezing_parametrised eq 'y' and n_elements(scaling_annual_temp) gt 0 then begin
  v_ii = where(v_ice eq 1, v_ci)
  if v_ci gt 0 then refr_v[v_ii] = v_refr[v_ii]
  v_ii = where(v_ice eq 0 and (mel_v gt rf_melcrit / 4.) and (rf_cold_v lt -50) and $
               (rf_ind_v lt rf_melcrit * scaling_annual_temp * firn_v), v_ci)
  if v_ci gt 0 then begin
    rf_ind_v[v_ii] = rf_ind_v[v_ii] + mel_v[v_ii]
    ; the same expression as refreezing_parametrised.pro: one minimum over all refreezing bands
    refr_v[v_ii] = min([[mel_v[v_ii], rf_melcrit * scaling_annual_temp * firn_v[v_ii]]], dimension=1)
  endif
endif

bal_v = bal_v + psg_v - mel_v + refr_v

; snow cover and surface type for the next month
sno_v = (sno_v + psg_v - mel_v) > 0
sur_v = dblarr(nv)
sur_v[where(firn_v eq 1, /null)] = 2
sur_v[where(sno_v gt 0, /null)] = 1
