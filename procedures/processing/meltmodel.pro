; ***************************************
; Meltmodel of the mass balance model
; ***************************************

compile_opt idl2

; ***********  melt (positive)

; sub-monthly variability (excluded by default for daily model and energy balance model!)
if time_resolution eq 'monthly' and submonth_variability eq 'y' and meltmodel ne '3' then begin
  a = dblarr(mon_len[m - 1])
  tgs = tg
  ; superimpose variability / make sure no shift in mean T is introduced!
  for i = 0, mon_len[m - 1] - 1 do a[i] = tgs[0] + variab[m - 1, i] - mean(variab[m - 1, 0 : mon_len[m - 1] - 1])
  for j = 0, nb - 1 do begin
    b = a + (tgs[j] - tgs[0])
    ii = where(b gt 0, ci)
    if ci gt 0 then pdd = total(b[ii]) else pdd = 0.
    if pdd gt 0 then tg[j] = pdd / mon_len[m - 1]
  endfor
endif else tgs = tg
tgs_cum = tgs_cum + tgs

; ----------
case meltmodel of
  '1': begin
    ii = where(sur eq 1 and tg gt t_melt, ci) ; snow
    if ci gt 0 then begin
      mel[ii] = DDFsnow * tg[ii] * mon_len[m - 1] / 1000.
      jj = where(gl[ii] ne noval, cj)
      if cj gt 0 and ar_gl ne 0 then smelt[ye] = smelt[ye] + total(mel[ii[jj]] * area[ii[jj]]) / ar_gl
      if time_resolution eq 'daily' then snowmel[ii] = mel[ii]
    endif

    ii = where(sur eq 2 and tg gt t_melt, ci) ; Firn
    if ci gt 0 then begin
      mel[ii] = (0.5 * DDFice + 0.5 * DDFsnow) * tg[ii] * mon_len[m - 1] / 1000.
      imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl
      if time_resolution eq 'daily' then icemel[ii] = mel[ii]
    endif

    ii = where(sur eq 0 and tg gt t_melt, ci) ; Ice
    if ci gt 0 then begin
      mel[ii] = DDFice * tg[ii] * mon_len[m - 1] / 1000.
      imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl
      if time_resolution eq 'daily' then icemel[ii] = mel[ii]
    endif

    if debris_supraglacial eq 'y' then begin
      @procedures/processing/calculatedebrismelt.pro
    endif ; debris
  end

  ; ---------
  '3': begin
    ii = where(sur eq 1, ci) ; snow
    if ci gt 0 then begin
      mel[ii] = ((1. - alb_snow) * sw_rad[ii, m - 1] + C0 + C1 * tg[ii]) * 3600 * 24. * mon_len[m - 1] / 1000. / lhf
      jj = where(mel lt 0, cj)
      if cj gt 0 then mel[jj] = 0
      smelt[ye] = smelt[ye] + total(mel[ii] * area[ii]) / ar_gl
      if time_resolution eq 'daily' then snowmel[ii] = mel[ii]
    endif

    ii = where(sur eq 2, ci) ; Firn
    if ci gt 0 then begin
      mel[ii] = ((1. - alb_firn) * sw_rad[ii, m - 1] + C0 + C1 * tg[ii]) * 3600 * 24. * mon_len[m - 1] / 1000. / lhf
      jj = where(mel lt 0, cj)
      if cj gt 0 then mel[jj] = 0
      imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl
      if time_resolution eq 'daily' then icemel[ii] = mel[ii]
    endif

    ii = where(sur eq 0, ci) ; Ice
    if ci gt 0 then begin
      mel[ii] = ((1. - alb_ice) * sw_rad[ii, m - 1] + C0 + C1 * tg[ii]) * 3600 * 24. * mon_len[m - 1] / 1000. / lhf
      jj = where(mel lt 0, cj)
      if cj gt 0 then mel[jj] = 0
      imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl
      if time_resolution eq 'daily' then icemel[ii] = mel[ii]
    endif

    if debris_supraglacial eq 'y' then begin
      ii = where(sur eq 0 and tg gt t_melt and debris_thick gt 0 and debris_frac gt 0, ci) ; debris-covered ice
      if ci gt 0 then begin
        for i = 0l, ci - 1 do begin
          a = min(abs(debris_thick[ii[i]] - debris_type_th), ind) ; looking for closest value (may be improved by interpolating)
          if write_mb_elevationbands eq 'y' then debris_red_factor[ii[i]] = debris_type_red[ind]
          ; debris-covered ice + bare ice + area of ponds/cliffs
          mel[ii[i]] = (debris_frac[0, ii[i]] - debris_ponddens[ii[i]]) * debris_type_red[ind] * mel[ii[i]] + (1. - debris_frac[0, ii[i]]) * mel[ii[i]] + debris_ponddens[ii[i]] * debris_pond_enhancementfactor * mel[ii[i]]
        endfor
        imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl ; updating array from above
        if time_resolution eq 'daily' then icemel[ii] = mel[ii]
      endif
    endif
  end
endcase
