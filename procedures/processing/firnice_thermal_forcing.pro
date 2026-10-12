; *************************************************************
; firnice_thermal_forcing
;
; Energy inputs of the thermal model for this month: the monthly mean band air temperature
; tgs_th and the melt mel_th and rain plg_th whose refreezing heats the firn. With
; firnice_forcing_toff = 'y' (default) they are the mass balance's tgs, mel and plg. With 'n'
; they come from the same formulas as accumulation.pro and meltmodel.pro (degree-day model '1',
; monthly, sub-monthly variability), on the air temperature without t_offset.
; Writes no mass-balance variable. Called after accumulation.pro and meltmodel.pro (needs pg,
; tgs, sur), in the month loop and in firnice_reference_forcing.pro.
; *************************************************************

compile_opt idl2

if firnice_forcing_toff ne 'n' then begin
  tgs_th = tgs & mel_th = mel & plg_th = plg
endif else begin
  ftw_tm = tgs - t_offset
  ; state of precipitation, as accumulation.pro (rain before the snow multiplier)
  ftw_ps = dblarr(nb)
  ftw_i = where(ftw_tm lt T_thres - 1, ftw_c)
  if ftw_c gt 0 then ftw_ps[ftw_i] = pg[ftw_i]
  ftw_i = where(ftw_tm gt T_thres - 1 and ftw_tm lt T_thres + 1, ftw_c)
  if ftw_c gt 0 then ftw_ps[ftw_i] = pg[ftw_i] * (-(ftw_tm[ftw_i] - T_thres - 1.) / 2.)
  plg_th = pg - ftw_ps
  ; positive-degree mean with sub-monthly variability, as meltmodel.pro
  ftw_tg = ftw_tm
  if time_resolution eq 'monthly' and submonth_variability eq 'y' and meltmodel ne '3' then begin
    ftw_a = dblarr(mon_len[m - 1])
    for ftw_k = 0, mon_len[m - 1] - 1 do ftw_a[ftw_k] = ftw_tm[0] + variab[m - 1, ftw_k] - mean(variab[m - 1, 0 : mon_len[m - 1] - 1])
    for ftw_j = 0, nb - 1 do begin
      ftw_b = ftw_a + (ftw_tm[ftw_j] - ftw_tm[0])
      ftw_i = where(ftw_b gt 0, ftw_c)
      if ftw_c gt 0 then ftw_pdd = total(ftw_b[ftw_i]) else ftw_pdd = 0.
      if ftw_pdd gt 0 then ftw_tg[ftw_j] = ftw_pdd / mon_len[m - 1]
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
  tgs_th = ftw_tm
endelse
