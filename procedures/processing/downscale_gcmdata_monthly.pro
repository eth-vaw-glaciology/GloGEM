; *************************************************************
; downscale_gcmdata_monthly
;
; Construct a continuous monthly climate time series by splicing
; reanalysis observations with bias-corrected GCM projections.
;
; Identifies the nearest reanalysis and GCM grid points for the
; current glacier grid cell, computes monthly additive temperature
; and multiplicative precipitation biases over the rea_eval period,
; then assembles a seamless monthly series (temp, prec, cyear, cmon)
; using reanalysis data for the observed past and bias-corrected GCM
; data for the future. Optionally rescales GCM month-to-month
; temperature variability to match the reanalysis using a running-mean
; smoothing approach.
; *************************************************************

compile_opt idl2

; find corresponding grid cell of reanalysis-file
; Closest latitude
dummy = min(abs(rlat - gmid[0]), ind_lat)
; Closest longitude
dummy = min(abs(rlon - gmid[1]), ind_lon)
rmid = [rlat[ind_lat], rlon[ind_lon]]

; ------------------------------
; meteo time series directly from re-analysis data (past)
if reanalysis_direct eq 'y' then begin

   temp=dblarr((years+1)*12) & prec=temp & cyear=temp & cmon=temp & n=0l
   for i=0,years do begin
      for m=1,12 do begin
         bb=where(rlat eq rmid[0]) & cc=where(rlon eq rmid[1]) & hh=where(ryear eq i+tran[0]-1 and rmon eq m,ci)
         cyear[n]=i+tran[0]-1 & cmon[n]=m
         if ci gt 0 then begin
            temp[n]=rtemp[hh[0],cc[0],bb[0]]
            prec[n]=rprec[hh[0],cc[0],bb[0]]
         endif
         n=n+1
      endfor
      if i eq 0 then hclim=relev[cc[0],bb[0]]
   endfor
   if meltmodel ne '1' then begin
      mrad=dblarr(12) & mtt=indgen(12)
      for i=0,11 do begin
         hh=where(rmon eq i+1) & mrad[i]=rrad[hh[0],cc[0],bb[0]]
      endfor
   endif


; ---------------------------------
; ---------------------------------
; meteo time series downscaled from GCMs or whatever (future)
endif else begin

   ; Original for .mdi files
   if GMIP4 eq 'n' then begin
      ; find closest GCM-point
      ; Closest latitude
      dummy = min(abs(gcm_lat - rmid[0]), ind_lat)
      ; Closest longitude
      dummy = min(abs(gcm_lon - rmid[1]), ind_lon)
      gcm_mid = [gcm_lat[ind_lat], gcm_lon[ind_lon]]
      ; calculate monthly bias in the past
      bias=dblarr(3,12)    ; (0) temp, (1) prec, (2) tvar
      ii=where(gcm_lat eq gcm_mid[0])
      jj=where(gcm_lon eq gcm_mid[1])
      hh=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1])
      bb=where(rlat eq rmid[0])
      cc=where(rlon eq rmid[1])
      for m=1,12 do begin
         dd=where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m)
         kk=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)
         if AMOC ne 'y' then begin
            bias[0,m-1]=mean(gcm_temp[kk,jj[0],ii[0]])-mean(rtemp[dd,cc[0],bb[0]])
            bias[1,m-1]=mean(gcm_prec[kk,jj[0],ii[0]])/mean(rprec[dd,cc[0],bb[0]])
            if variability_bias eq 'y' then begin
               bias[2,m-1]=stdev(rtemp[dd,cc[0],bb[0]])/stdev(gcm_temp[kk,jj[0],ii[0]])
            endif
         endif else begin
            bias[0,m-1]=mean(gcm_temp[kk])-mean(rtemp[dd,cc[0],bb[0]])
            bias[1,m-1]=mean(gcm_prec[kk])/mean(rprec[dd,cc[0],bb[0]])
            if variability_bias eq 'y' then begin
               bias[2,m-1]=stdev(rtemp[dd,cc[0],bb[0]])/stdev(gcm_temp[kk])
            endif
         endelse
         hclim=relev[cc[0],bb[0]]
      endfor
      ; optionally restrict temperature bias to a minimum value - if extreme
      ; biases occur in Arctic regions air temperatures can suddenly become maximal
      ; during winter time
      if min_tempbias ne noval then begin
         dd=where(bias[0,*] lt min_tempbias,cd)
         if cd gt 0 then bias[0,dd]=min_tempbias
      endif
      ; optionally restrict precipitation bias to a minimum value - if GCM yields (almost) no precipitation on average the bias will become very small resulting in extreme precipitation rates (several 100 m!) if some prec is present
      if min_precbias ne noval then begin
         dd=where(bias[1,*] lt min_precbias,cd)
         if cd gt 0 then bias[1,dd]=min_precbias
      endif

      ; write Bias-file
      if write_file eq 'y' then printf,5,rmid,bias[0,*],bias[1,*],bias[2,*],fo='(2f9.3,36f8.3)'

      if meltmodel ne '1' then begin
         mrad=dblarr(12) & mtt=indgen(12)+1
         for i=1,12 do begin
            hh=where(mtt eq i) & mrad[i-1]=rrad[hh[0],cc[0],bb[0]]
         endfor
      endif

      ; time series with Bias-corrected GCM-data
      if AMOC eq 'y' then begin
         temp=dblarr((years)*12)
      endif else begin
         temp=dblarr((years+1)*12)
      endelse
      prec=temp
      rad=temp
      cyear=temp
      cmon=temp
      n=0l

      ; Precompute constants
      tran_offset = tran[0]
      max_ryear = max(ryear)
      min_ryear = min(ryear)
      max_gcm_year = max(gcm_year) ; Get the maximum year from GCM data
      n = 0
      ; Precompute indices for re-analysis and GCM data
      for i = 0, years do begin
         current_year = i + tran_offset
         ; Stop processing if the current year exceeds the maximum GCM year
         if current_year gt max_gcm_year then break
         ; Use re-analysis data if available
         if current_year le max_ryear and current_year gt min_ryear then begin
            for m = 1, 12 do begin
               ; Precompute indices for the current year and month
               hh = where(ryear eq current_year and rmon eq m, ci)
               if ci gt 0 then begin
                  bb = where(rlat eq rmid[0])
                  cc = where(rlon eq rmid[1])
                  cyear[n] = current_year
                  cmon[n] = m
                  temp[n] = rtemp[hh[0], cc[0], bb[0]]
                  prec[n] = rprec[hh[0], cc[0], bb[0]]
                  if meltmodel ne '1' then rad[n] = mrad[m - 1]
                  n = n + 1
               endif
            endfor
         endif else begin
         ; use projections only for unmeasured future
            for m = 1, 12 do begin
               kk = where(gcm_year eq current_year and gcm_mon eq m, ck)
               if ck gt 0 then begin
                  cyear[n] = current_year
                  cmon[n] = m
                  if AMOC eq 'y' then begin
                     temp[n]=gcm_temp[kk[0]]-bias[0,m-1]
                     prec[n]=gcm_prec[kk[0]]/bias[1,m-1]
                  endif else begin
                     temp[n]=gcm_temp[kk[0],jj[0],ii[0]]-bias[0,m-1]
                     prec[n]=gcm_prec[kk[0],jj[0],ii[0]]/bias[1,m-1]
                  endelse
                  if meltmodel ne '1' then rad[n] = mrad[m - 1]
                  n = n + 1
               endif
            endfor
         endelse
      endfor
      
      ; --------------------
      ; adapt temperature variability of GCM to re-analysis
      ; Apply only to GCM/projection months, identified by cyear/cmon
      if variability_bias eq 'y' then begin
         for p = 1, 12 do begin
           pp = where(cmon[0:n-1] eq p, ch)
            if ch gt 0 then begin
               tt = temp[pp]
               tt_smooth = rmean(rmean(tt,5),25)
               ; Only correct GCM period
               rr = where(cyear[pp] gt max_ryear, cp)
               if cp gt 0 then begin
                  temp[pp[rr]] = tt_smooth[rr] + (temp[hh[rr]] - tt_smooth[rr]) * bias[2,p-1]
               endif
            endif
         endfor
      endif
      
   endif else begin 
   ; Case GMIP4 
      temp=dblarr((years+1)*12)
      prec=temp
      rad=temp
      cyear=temp
      cmon=temp
      n=0l
   
      ; find closest GCM-point
      ; Closest latitude
      dummy = min(abs(gcm_lat - rmid[0]), ind_lat)
      ; Closest longitude
      dummy = min(abs(gcm_lon - rmid[1]), ind_lon)
      gcm_mid = [gcm_lat[ind_lat], gcm_lon[ind_lon]]

      ; calculate monthly bias in the past
      bias=dblarr(3,12)    ; (0) temp, (1) prec, (2) tvar
      ii=where(gcm_lat eq gcm_mid[0])
      jj=where(gcm_lon eq gcm_mid[1])
      hh=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1])
      bb=where(rlat eq rmid[0])
      cc=where(rlon eq rmid[1])
      for m=1,12 do begin
         dd=where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m)
         kk=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)
         hclim=relev[cc[0],bb[0]]
      endfor

      ; Precompute constants
      tran_offset = tran[0]
      max_ryear = max(ryear)
      min_ryear = min(ryear)
      max_gcm_year = max(gcm_year) ; Get the maximum year from GCM data
      n = 0

      ; Precompute indices for re-analysis and GCM data
      for i = 0, years do begin
         current_year = i + tran_offset
         ; Stop processing if the current year exceeds the maximum GCM year
         if current_year gt max_gcm_year then break
         ; Use re-analysis data if available
         if current_year le max_ryear and current_year gt min_ryear then begin
            for m = 1, 12 do begin
               ; Precompute indices for the current year and month
               hh = where(ryear eq current_year and rmon eq m, ci)
               if ci gt 0 then begin
                  bb = where(rlat eq rmid[0])
                  cc = where(rlon eq rmid[1])
                  cyear[n] = current_year
                  cmon[n] = m
                  temp[n] = rtemp[hh[0], cc[0], bb[0]]
                  prec[n] = rprec[hh[0], cc[0], bb[0]]
                  if meltmodel ne '1' then rad[n] = mrad[m - 1]
                  n = n + 1
               endif
            endfor
         endif else begin
            ; Use projections for future years
            for m = 1, 12 do begin
               kk = where(gcm_year eq current_year and gcm_mon eq m, ck)
               if ck gt 0 then begin
                  cyear[n] = current_year
                  cmon[n] = m
                  temp[n] = gcm_temp[kk[0]]
                  prec[n] = gcm_prec[kk[0]]
                  if meltmodel ne '1' then rad[n] = mrad[m - 1]
                  n = n + 1
               endif
            endfor
         endelse
      endfor
   endelse
endelse
