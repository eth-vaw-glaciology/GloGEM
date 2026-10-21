function replace_heatwaves, tempre, year, doy, mon, percent, min_duration, MODE=mode, TVALUE=tvalue
  ; ------------------------------------------------------------
  ; Replacement options (MODE keyword, default 2):
  ;   1 = mean of that day (+/- 3 days) over fixed 1991-2020
  ;   2 = mean of that day (+/- 3 days) over moving 30-year block
  ;   3 = fixed temperature value given by TVALUE
  ; ------------------------------------------------------------
  if n_elements(mode) eq 0 then mode = 2
  if (mode lt 1) or (mode gt 3) then message, 'MODE must be 1, 2 or 3'
  if (mode eq 3) and (n_elements(tvalue) eq 0) then $
     message, 'MODE=3 requires a TVALUE'
  n = n_elements(tempre)
  ; ------------------------------------------------------------
  ; Detect heatwave days using moving 30-year 95th percentile
  ; ------------------------------------------------------------
  is_hot = bytarr(n)
  for ii = 0L, n-1L do begin
     if finite(tempre[ii]) and $
        (mon[ii] ge 3) and (mon[ii] le 10) then begin
        yr = year[ii]
      d  = doy[ii]
      ; Moving 30-year block
      ; Example: 2025 uses 1996-2025
      ; Before 1971, use fixed 1941-1970
      if yr lt 1971 then begin
        clim_start = 1941
        clim_end   = 1970
      endif else begin
        clim_start = yr - 29
        clim_end   = yr
      endelse
      window_half = 3
      win = ((d - window_half + indgen(2*window_half + 1) - 1) mod 365) + 1
      idx_win_valid = where((win ge 60) and (win le 304), nwin)
      if nwin gt 0 then begin
         win = win[idx_win_valid]
         inwin = bytarr(n)
         for ww = 0L, n_elements(win)-1L do begin
            idxw = where(doy eq win[ww], cw)
            if cw gt 0 then inwin[idxw] = 1B
         endfor
         idx_clim = where((year ge clim_start) and (year le clim_end) and $
                          (mon ge 3) and (mon le 10) and $
                          (inwin eq 1B) and $
                          finite(tempre), count_clim)
      endif else begin
         count_clim = 0
      endelse
      if count_clim gt 0 then begin
         thresh95 = my_percentile(tempre[idx_clim], percent / 100.0)
         if tempre[ii] gt thresh95 then is_hot[ii] = 1B
      endif
   endif
  endfor
  ; ------------------------------------------------------------
  ; Keep only heatwaves lasting at least min_duration days
  ; ------------------------------------------------------------
  is_heatwave = bytarr(n)
  i = 0L
  while i lt n do begin
    if is_hot[i] eq 1B then begin
      j = i
      while (j lt n) and (is_hot[j] eq 1B) do j++
      if (j - i) ge min_duration then begin
        is_heatwave[i:j-1] = 1B
      endif
      i = j
    endif else begin
      i++
    endelse
  endwhile
  ; ------------------------------------------------------------
  ; Replace heatwave days according to MODE
  ; ------------------------------------------------------------
  tempre_new = tempre
  idx_hw = where(is_heatwave eq 1B, count_hw)
  replaced_counter = 0L
  if count_hw gt 0 then begin
    for k = 0L, count_hw-1L do begin
      ii = idx_hw[k]
      ; Fixed temperature value
      if mode eq 3 then begin
        tempre_new[ii] = tvalue
        replaced_counter++
        continue
      endif
      yr = year[ii]
      d  = doy[ii]
      if mode eq 1 then begin
        ; Fixed 1991-2020 reference period
        clim_start = 1991
        clim_end   = 2020
      endif else if yr lt 1971 then begin
        clim_start = 1941
        clim_end   = 1970
      endif else begin
        clim_start = yr - 29
        clim_end   = yr
      endelse
      window_half = 3
      win = ((d - window_half + indgen(2*window_half + 1) - 1) mod 365) + 1
      idx_win_valid = where((win ge 60) and (win le 304), nwin)
      if nwin gt 0 then begin
         win = win[idx_win_valid]
         inwin = bytarr(n)
         for ww = 0L, n_elements(win)-1L do begin
            idxw = where(doy eq win[ww], cw)
            if cw gt 0 then inwin[idxw] = 1B
         endfor
         idx_clim = where((year ge clim_start) and (year le clim_end) and $
                          (mon ge 3) and (mon le 10) and $
                          (inwin eq 1B) and $
                          finite(tempre), count_clim)
      endif else begin
         count_clim = 0
      endelse
      if count_clim gt 0 then begin
         tempre_new[ii] = mean(tempre[idx_clim], /nan)
         replaced_counter++
      endif
   endfor
  endif
  ; -----------------------------------------------------------
  ; Outputs
  ; ------------------------------------------------------------
  n_replaced = replaced_counter
  replaced_idx = idx_hw
  print, 'Replaced days = ', n_replaced, ' (mode ', strtrim(mode, 2), ')'
  return, tempre_new
end