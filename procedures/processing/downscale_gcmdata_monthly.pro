pro DOWNSCALE_GCMDATA_MONTHLY, gcm_year, gcm_mon, ryear, rmon, m, rea_eval, rmid, gmid, gcm_lat, gcm_lon, rlat, rlon, relev, years, tran, rtemp, rprec, rrad, gcm_temp, gcm_prec, min_tempbias, min_precbias, write_file, meltmodel, reanalysis_direct, variability_bias, p_thres, temp, prec, rad, cyear, cmon, nlons, nlats, hclim, cc, bb
  compile_opt idl2

  noval = -9999

  ; find corresponding grid cell of reanalysis-file
  dtt = dblarr(2, nlons[0])
  for i = 0, nlons[0] - 1 do begin
    a = min(sqrt((rlat - gmid[0]) ^ 2 + (rlon[i] - gmid[1]) ^ 2), ind)
    dtt[0, i] = a
    dtt[1, i] = ind
  endfor
  a = min(dtt[0, *], ind2)
  rmid = [rlat[ind], rlon[ind2]]

  ; ------------------------------
  ; meteo time series directly from re-analysis data (past)
  if reanalysis_direct eq 'y' then begin
    temp = dblarr((years + 1) * 12)
    prec = temp
    cyear = temp
    cmon = temp
    n = 0l
    for i = 0, years do begin
      for m = 1, 12 do begin
        bb = where(rlat eq rmid[0])
        cc = where(rlon eq rmid[1])
        hh = where(ryear eq i + tran[0] - 1 and rmon eq m, ci)
        cyear[n] = i + tran[0] - 1
        cmon[n] = m
        if ci gt 0 then begin
          temp[n] = rtemp[hh[0], cc[0], bb[0]]
          prec[n] = rprec[hh[0], cc[0], bb[0]]
        endif
        n = n + 1
      endfor
      if i eq 0 then hclim = relev[cc[0], bb[0]]
    endfor
    if meltmodel ne '1' then begin
      mrad = dblarr(12)
      mtt = indgen(12)
      for i = 0, 11 do begin
        hh = where(rmon eq i + 1)
        mrad[i] = rrad[hh[0], cc[0], bb[0]]
      endfor
    endif

    ; ---------------------------------
    ; ---------------------------------
    ; meteo time series downscaled from GCMs or whatever (future)
  endif else begin
    ; find closest GCM-point
    dtt = dblarr(2, n_elements(gcm_lon))
    for i = 0, n_elements(gcm_lon) - 1 do begin
      a = min(sqrt((gcm_lat - rmid[0]) ^ 2 + (gcm_lon[i] - rmid[1]) ^ 2), ind)
      dtt[0, i] = a
      dtt[1, i] = ind
    endfor
    a = min(dtt[0, *], ind2)
    gcm_mid = [gcm_lat[ind], gcm_lon[ind2]]

    ; calculate monthly bias in the past
    bias = dblarr(3, 12) ; (0) temp, (1) prec, (2) tvar

    ii = where(gcm_lat eq gcm_mid[0])
    jj = where(gcm_lon eq gcm_mid[1])
    hh = where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1])

    bb = where(rlat eq rmid[0])
    cc = where(rlon eq rmid[1])

    for m = 1, 12 do begin
      dd = where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m)

      kk = where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)
      bias[0, m - 1] = mean(gcm_temp[kk, jj[0], ii[0]]) - mean(rtemp[dd, cc[0], bb[0]])
      bias[1, m - 1] = mean(gcm_prec[kk, jj[0], ii[0]]) / mean(rprec[dd, cc[0], bb[0]])
      if variability_bias eq 'y' then bias[2, m - 1] = stdev(rtemp[dd, cc[0], bb[0]]) / stdev(gcm_temp[kk, jj[0], ii[0]])

      hclim = relev[cc[0], bb[0]]
    endfor

    ; optionally restrict temperature bias to a minimum value - if extreme
    ; biases occur in Arctic regions air temperatures can suddenly become maximal
    ; during winter time
    if min_tempbias ne noval then begin
      dd = where(bias[0, *] lt min_tempbias, cd)
      if cd gt 0 then bias[0, dd] = min_tempbias
    endif

    ; optionally restrict precipitation bias to a minimum value - if GCM yields (almost) no precipitation on average the bias will become very small resulting in extreme precipitation rates (several 100 m!) if some prec is present
    if min_precbias ne noval then begin
      dd = where(bias[1, *] lt min_precbias, cd)
      if cd gt 0 then bias[1, dd] = min_precbias
    endif

    ; write Bias-file
    if write_file eq 'y' then printf, 5, rmid, bias[0, *], bias[1, *], bias[2, *], fo = '(2f9.3,36f8.3)'

    if meltmodel ne '1' then begin
      mrad = dblarr(12)
      mtt = indgen(12) + 1
      for i = 1, 12 do begin
        hh = where(mtt eq i)
        mrad[i - 1] = rrad[hh[0], cc[0], bb[0]]
      endfor
    endif

    ; time series with Bias-corrected GCM-data
    temp = dblarr((years + 1) * 12)
    prec = temp
    rad = temp
    cyear = temp
    cmon = temp
    n = 0l
    for i = 0, years do begin
      ; use re-analysis data as long as available! After (AND before) use GCM data
      if i + tran[0] le max(ryear) and i + tran[0] gt min(ryear) then begin
        for m = 1, 12 do begin
          bb = where(rlat eq rmid[0])
          cc = where(rlon eq rmid[1])
          hh = where(ryear eq i + tran[0] - 1 and rmon eq m, ci)
          cyear[n] = i + tran[0] - 1
          cmon[n] = m
          if ci gt 0 then begin
            temp[n] = rtemp[hh[0], cc[0], bb[0]]
            prec[n] = rprec[hh[0], cc[0], bb[0]]
          endif else stop
          if meltmodel ne '1' then rad[n] = mrad[m - 1]
          n = n + 1
        endfor
      endif else begin
        ; use projections only for unmeasured future
        hh = where(gcm_year eq i + tran[0] - 1)
        for m = 1, 12 do begin
          cyear[n] = i + tran[0] - 1
          cmon[n] = m

          kk = where(gcm_year eq i + tran[0] - 1 and gcm_mon eq m, ck)
          ; hack for GCMs only extending to 2099 / 2298
          if ck eq 0 then kk = where(gcm_year eq i + tran[0] - 2 and gcm_mon eq m, ck)
          if ck eq 0 then kk = where(gcm_year eq i + tran[0] - 3 and gcm_mon eq m, ck)
          temp[n] = gcm_temp[kk[0], jj[0], ii[0]] - bias[0, m - 1]
          prec[n] = gcm_prec[kk[0], jj[0], ii[0]] / bias[1, m - 1]

          if meltmodel ne '1' then rad[n] = mrad[m - 1]

          n = n + 1
        endfor
      endelse
    endfor

    ; --------------------
    ; adapt temperature variability of GCM to re-analysis
    if variability_bias eq 'y' then begin
      ; smoothed monthly temperature time series
      tm_smooth = dblarr(12, years + 1)
      for i = 0, years do for m = 0, 11 do tm_smooth[m, i] = temp[12 * i + m]
      for m = 0, 11 do begin
        tt = dblarr(years + 1)
        for i = 0, years do tt[i] = tm_smooth[m, i]
        tm_smooth[m, *] = RMEAN(RMEAN(tt, 5), 25)
      endfor
      for i = 0, years do for m = 0, 11 do temp[12 * i + m] = tm_smooth[m, i] + (temp[12 * i + m] - tm_smooth[m, i]) * bias[2, m]
    endif
  endelse
end
