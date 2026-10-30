; *************************************************************
; firnice_thermal_forcing
;
; Energy inputs of the thermal model for this month: the monthly mean band air temperature
; tgs_th and the melt mel_th and rain plg_th whose refreezing heats the firn. With
; firnice_forcing_toff = 'y' (default) they are the mass balance's tgs, mel and plg. With 'n'
; they come from the same formulas as accumulation.pro and meltmodel.pro (degree-day model '1',
; monthly, sub-monthly variability), on the air temperature without t_offset.
; With firnice_orient = 'table' the melt is multiplied per band by the orientation factor of
; setup_firnice_orient.pro, at this month's air temperature anomaly.
; With firnice_thermal_air = 'freeair' the air is fa_tm, the free air at the bands (with air_temperature =
; 'freeair' blended below the cell's ground), set by the caller.
; Writes no mass-balance variable. Called after accumulation.pro and meltmodel.pro (needs pg,
; tgs, sur), in the month loop and in firnice_reference_forcing.pro.
; *************************************************************

compile_opt idl2

if firnice_forcing_toff ne 'n' then begin
  tgs_th = tgs & mel_th = mel & plg_th = plg
endif else begin
  if firnice_thermal_air eq 'freeair' then ftw_tm = fa_tm else ftw_tm = tgs - t_offset
  ; the spin-up's reference forcing only: firnice_spinup_dT (firnice_reference_forcing.pro sets ftw_dsp)
  if n_elements(ftw_dsp) gt 0 then ftw_tm = ftw_tm + ftw_dsp
  ; air for the rain split and the melt: with firnice_thermal_lapse = 'stations' the station lapse
  ; rate above the climate cell, as the thermal surface gets it (firnice_temperature_model.pro);
  ; tgs_th stays ftw_tm, the surface adds its own shift
  ftw_tl = ftw_tm
  if firnice_thermal_lapse eq 'stations' then $
    ftw_tl = ftw_tm + (((elev - hclim) > 0d) < zth_cap) * (dtdz_icetemp[m - 1] - dtdz[m - 1])
  ; state of precipitation, as accumulation.pro (rain before the snow multiplier)
  ftw_ps = dblarr(nb)
  ftw_i = where(ftw_tl lt T_thres - 1, ftw_c)
  if ftw_c gt 0 then ftw_ps[ftw_i] = pg[ftw_i]
  ftw_i = where(ftw_tl gt T_thres - 1 and ftw_tl lt T_thres + 1, ftw_c)
  if ftw_c gt 0 then ftw_ps[ftw_i] = pg[ftw_i] * (-(ftw_tl[ftw_i] - T_thres - 1.) / 2.)
  plg_th = pg - ftw_ps
  ; positive-degree mean with sub-monthly variability, as meltmodel.pro
  ftw_tg = ftw_tl
  if time_resolution eq 'monthly' and submonth_variability eq 'y' and meltmodel ne '3' and $
     firnice_daily_anomalies eq '' then begin
    ftw_a = dblarr(mon_len[m - 1])
    for ftw_k = 0, mon_len[m - 1] - 1 do ftw_a[ftw_k] = ftw_tl[0] + variab[m - 1, ftw_k] - mean(variab[m - 1, 0 : mon_len[m - 1] - 1])
    for ftw_j = 0, nb - 1 do begin
      ftw_b = ftw_a + (ftw_tl[ftw_j] - ftw_tl[0])
      ftw_i = where(ftw_b gt 0, ftw_c)
      if ftw_c gt 0 then ftw_pdd = total(ftw_b[ftw_i]) else ftw_pdd = 0.
      if ftw_pdd gt 0 then ftw_tg[ftw_j] = ftw_pdd / mon_len[m - 1]
    endfor
  endif
  ; firnice_daily_anomalies: this month's real daily anomalies instead of the list (halved in Nov-Mar, as the
  ; list); in the spin-up's reference year the degree-days averaged over the reference period's months.
  ; The positive-degree mean is taken over the days the file has (its leap years lack 31 December).
  if firnice_daily_anomalies ne '' then begin
    ftw_n = mon_len[m - 1]
    if da_ref then ftw_ix = reform(da_refix[m - 1, *]) else ftw_ix = [da_tix[da_it]]
    ftw_nix = n_elements(ftw_ix)
    ftw_d = reform(da_node[0 : ftw_n - 1, ftw_ix], ftw_n, ftw_nix)
    ftw_w = dblarr(ftw_n, ftw_nix)
    ftw_vf = (m le 3 or m ge 11) ? 0.5d : 1d
    for ftw_r = 0, ftw_nix - 1 do begin
      ftw_ok = where(finite(ftw_d[*, ftw_r]), ftw_cd, complement = ftw_no, ncomplement = ftw_cn)
      if ftw_cd lt ftw_n - 1 then message, 'firnice_daily_anomalies: only ' + strtrim(ftw_cd, 2) + ' days in month ' + $
          strtrim(m, 2) + ' of ' + strtrim(da_year[ftw_ix[ftw_r]], 2)
      ftw_d[ftw_ok, ftw_r] = ftw_vf * (ftw_d[ftw_ok, ftw_r] - mean(ftw_d[ftw_ok, ftw_r]))
      if ftw_cn gt 0 then ftw_d[ftw_no, ftw_r] = -1d30
      ftw_w[ftw_ok, ftw_r] = 1d / ftw_cd
    endfor
    for ftw_j = 0, nb - 1 do begin
      ftw_pdd = total(((ftw_tl[ftw_j] + ftw_d) > 0d) * ftw_w) / ftw_nix
      if ftw_pdd gt 0 then ftw_tg[ftw_j] = ftw_pdd
    endfor
  endif
  ; melt per surface type (snow, firn, ice), as meltmodel '1'
  mel_th = dblarr(nb)
  ftw_i = where(sur eq 1 and ftw_tg gt t_melt, ftw_c)
  if ftw_c gt 0 then mel_th[ftw_i] = DDFsnow * ftw_tg[ftw_i] * mon_len[m - 1] / 1000.
  ftw_i = where(sur eq 2 and ftw_tg gt t_melt, ftw_c)
  if ftw_c gt 0 then mel_th[ftw_i] = (0.5 * DDFice + 0.5 * DDFsnow) * ftw_tg[ftw_i] * mon_len[m - 1] / 1000.
  ftw_i = where(sur eq 0 and ftw_tg gt t_melt, ftw_c)
  if ftw_c gt 0 then mel_th[ftw_i] = DDFice * ftw_tg[ftw_i] * mon_len[m - 1] / 1000.
  if firnice_write_melth eq 'y' and mb_book then begin
    melth_log[ye, m - 1, *] = mel_th & tairth_log[ye, m - 1, *] = ftw_tl
  endif
  ; orientation factor at this month's anomaly from 1981-2020, linear in dT, held at the table's ends
  if firnice_orient eq 'table' then begin
    ftw_nd = n_elements(forient_dt)
    ftw_x = ((ftw_tl - forient_tref[*, m - 1]) > forient_dt[0]) < forient_dt[ftw_nd - 1]
    ftw_k = (value_locate(forient_dt, ftw_x) > 0) < (ftw_nd - 2)
    ftw_w = (ftw_x - forient_dt[ftw_k]) / (forient_dt[ftw_k + 1] - forient_dt[ftw_k])
    ftw_n = lindgen(nb)
    mel_th = mel_th * (forient[ftw_n, ftw_k] + ftw_w * (forient[ftw_n, ftw_k + 1] - forient[ftw_n, ftw_k]))
  endif
  tgs_th = ftw_tm
endelse
