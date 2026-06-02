compile_opt idl2

noval=-9999

; First do bias correction of the GCM
;if bias_correction_method eq 1 then begin
;   @procedures/processing/bias_correction_delta.pro
;else if (bias_correction_method eq 2) then begin
;   @procedures/processing/bias_correction_qm.pro
;else begin
;   print,'No valid bias correction method selected! Please check input.pro'
;   stop
;endif

; calculate monthly bias in the past
bias=dblarr(3,12)    ; (0) temp, (1) prec, (2) temperature variability in month

; computation of bias stays at monthly resolution!
hh=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1])

for m=1,12 do begin
   
; for some reason reanalysis temperature appear to be completely wrong
; in a few years... filtering here and later
   dd=where(ryear ge rea_eval[0] and ryear le rea_eval[1] and rmon eq m and tempre gt -50)
   kk=where(gcm_year ge rea_eval[0] and gcm_year le rea_eval[1] and gcm_mon eq m)      
   bias[0,m-1]=mean(tempgcm[kk])-mean(tempre[dd])    ; monthly temperature bias
   bias[1,m-1]=mean(precgcm[kk])/mean(prec_orig[dd])
   bias[2,m-1]=stdev(tempre[dd])/stdev(tempgcm[kk])

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
temp=dblarr((years+1)*365.) & prec=temp & rad=temp & cyear=temp & cday=temp & cmon=temp & n=0l

; Precompute constants
tran_offset = tran[0]
max_ryear = max(ryear)
n = 0

; Precompute indices for re-analysis and GCM data
for i = 0, years do begin
   current_year = i + tran_offset - 1
   ; Use re-analysis data if available
   if current_year le max_ryear then begin
      ; Precompute indices for the current year
      hh = where(ryear eq current_year, ci)
      if ci gt 0 then begin
         ; Process all days at once
         rday_indices = indgen(365)
         hh_day = hh[rday_indices]
         cyear[n:n+364] = current_year
         cday[n:n+364] = rday_indices + 1
         cmon[n:n+364] = rmon[hh_day]
         temp[n:n+364] = tempre[hh_day]
         prec[n:n+364] = precre[hh_day]
         if meltmodel ne '1' then rad[n:n+364] = mrad[m-1]
         n = n + 365
      endif
   endif else begin
      ; Use projections for future years
      kk = where(gcm_year eq current_year, ck)
      if ck gt 0 then begin
         ; Process all days at once
         gcm_day_indices = indgen(365)
         kk_day = kk[gcm_day_indices]
         cyear[n:n+364] = current_year
         cday[n:n+364] = gcm_day_indices + 1
         cmon[n:n+364] = gcm_mon[kk_day]
         temp[n:n+364] = tempgcm[kk_day] - bias[0, gcm_mon[kk_day] - 1]
         prec[n:n+364] = precgcm[kk_day] / bias[1, gcm_mon[kk_day] - 1]
         if meltmodel ne '1' then rad[n:n+364] = mrad[m-1]
         n = n + 365
      endif
   endelse
endfor

; Apply filters in bulk
ii = where(temp lt -50, ci)
if ci gt 0 then temp[ii] = 0
ii = where(prec lt p_thres, ci)
if ci gt 0 then prec[ii] = 0

; --------------------
; adapt temperature variability of GCM to re-analysis
; NOT implemented (or feasible?) in daily model version!!
if variability_bias_longterm eq 'y' then begin

   ; smoothed monthly temperature time series
   tm_smooth=dblarr(12,years+1)
   for i=0,years do begin
      for m=0,11 do begin
         ii=where(cmon eq m+1 and cyear eq tran[0]+i)
         tm_smooth[m,i]=mean(temp[ii])
      endfor
   endfor
   for m=0,11 do begin
      tt=dblarr(years+1) & for i=0,years do tt[i]=tm_smooth[m,i]
      tm_smooth[m,*]=rmean(rmean(tt,5),25)
   endfor
   for i=0,years do for m=0,11 do temp[12*i+m]=tm_smooth[m,i]+(temp[12*i+m]-tm_smooth[m,i])*bias[2,m]

endif
