compile_opt idl2

if bias_correction eq 'y' then begin
   print, 'Performing bias correction of GCM data...'
   if bias_correction_method eq 1 then begin
      @procedures/processing/bias_correction_delta.pro
   endif else if bias_correction_method eq 2 then begin
      @procedures/processing/bias_correction_qm.pro
   endif
endif else begin
   print, 'No bias correction of GCM data...'
endelse
  
; write Bias-file
if write_file eq 'y' then printf,5,rmid,bias[0,*],bias[1,*],bias[2,*],fo='(2f9.3,36f8.3)'

if meltmodel ne '1' then begin
   mrad=dblarr(12) & mtt=indgen(12)+1
   for i=1,12 do begin
      hh=where(mtt eq i) & mrad[i-1]=rrad[hh[0],cc[0],bb[0]]
   endfor
endif

; time series with Bias-corrected GCM-data
temp=dblarr((years+1)*365.)
prec=temp
rad=temp
cyear=temp
cday=temp
cmon=temp
n=0l

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
