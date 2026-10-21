; *************************************************************
; snowline_extension
;
; Snow pack on the ground bands below the glacier front (snowline_ext_depth), for the snowline.
; Each step does what glogem.pro, accumulation.pro and meltmodel.pro ('1') do on bands without ice, with the
; glacier's own parameters: old snow removed once a year, snowfall, degree-day melt of the snow. One difference:
; precipitation is that of the inventory front (sx_zp), not extrapolated further down (where it would reach zero
; 10000/dPdz m below the climate grid point), and never below zero.
; Called after the snow update of the glacier bands, so ccmon already points to the next step.
; *************************************************************

compile_opt idl2

if sx_n gt 0 then begin

  ; new mass-balance year (finalize_annual_massbalance.pro: snostor=sno, sur=noval on bands without ice)
  if ye ne sx_ye then begin
    sx_snostor = sx_sno & sx_sur[*] = noval & sx_ye = ye
  endif

  ; old snow
  if bal_month eq dd_thresholds[2] then if m eq 1 then sx_sno = sx_sno - sx_snostor
  if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[1] then sx_sno = sx_sno - sx_snostor
  sx_jj = where(sx_sno lt 0, sx_cj) & if sx_cj gt 0 then sx_sno[sx_jj] = 0

  ; temperature and snowfall
  sx_tg = temp[jjclim[0] + ccmon - 1] + (sx_elev - hclim) * dtdz[m - 1] + t_offset
  sx_pc = prec[jjclim[0] + ccmon - 1] * c_prec / 1000.
  sx_pg = (sx_pc + sx_pc * ((sx_zp - hclim) / 10000.) * dpdz) > 0
  sx_psg = dblarr(sx_n)
  sx_jj = where(sx_tg lt T_thres - 1, sx_cj)
  if sx_cj gt 0 then sx_psg[sx_jj] = sx_pg[sx_jj]
  sx_jj = where(sx_tg gt T_thres - 1 and sx_tg lt T_thres + 1, sx_cj)
  if sx_cj gt 0 then sx_psg[sx_jj] = sx_pg[sx_jj] * (-(sx_tg[sx_jj] - T_thres - 1.) / 2.)
  sx_psg = sx_psg * snow_multiplier

  ; sub-monthly temperature variability, relative to the glacier's lowest band (meltmodel.pro)
  if time_resolution eq 'monthly' and submonth_variability eq 'y' then begin
    sx_a = dblarr(mon_len[m - 1])
    for sx_i = 0, mon_len[m - 1] - 1 do sx_a[sx_i] = tgs[0] + variab[m - 1, sx_i] - mean(variab[m - 1, 0 : mon_len[m - 1] - 1])
    ; all bands at once: days x bands, positive degree-days summed over the days
    sx_b = rebin(sx_a, mon_len[m - 1], sx_n) + rebin(reform(sx_tg - tgs[0], 1, sx_n), mon_len[m - 1], sx_n)
    sx_pdd = total(sx_b > 0, 1)
    sx_ii = where(sx_pdd gt 0, sx_ci)
    if sx_ci gt 0 then sx_tg[sx_ii] = sx_pdd[sx_ii] / mon_len[m - 1]
  endif

  ; melt: snow; ice only in the first step of a run, where sur starts at 0 as in glogem.pro
  sx_mel = dblarr(sx_n)
  sx_ii = where(sx_sur eq 1 and sx_tg gt t_melt, sx_ci)
  if sx_ci gt 0 then sx_mel[sx_ii] = DDFsnow * sx_tg[sx_ii] * mon_len[m - 1] / 1000.
  sx_ii = where(sx_sur eq 0 and sx_tg gt t_melt, sx_ci)
  if sx_ci gt 0 then sx_mel[sx_ii] = DDFice * sx_tg[sx_ii] * mon_len[m - 1] / 1000.

  ; snow update and surface type
  sx_sno = sx_sno + sx_psg - sx_mel
  sx_jj = where(sx_sno gt 0, sx_cj) & if sx_cj gt 0 then sx_sur[sx_jj] = 1
  sx_jj = where(sx_sno lt 0, sx_cj) & if sx_cj gt 0 then sx_sno[sx_jj] = 0
  sx_jj = where(sx_sno eq 0, sx_cj) & if sx_cj gt 0 then sx_sur[sx_jj] = noval

endif
