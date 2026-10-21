function replace_snowdays, temp, prec, ryear, rday, percent, ndays
  ; Remove snowfall events based on rolling ndays total
  ; percent = top percentage of events to replace
  ; ndays   = length of event window (e.g. 1, 3, 5 ...)
  percent = percent / 100.0
  if n_params() lt 6 then ndays = 1L
  n = n_elements(temp)
  if (n_elements(prec) ne n) or (n_elements(ryear) ne n) or $
     (n_elements(rday) ne n) then $
     message, 'All input arrays must have the same length.'

  if ndays lt 1 then message, 'ndays must be >= 1'
  ref_start = 1991
  ref_end   = 2020
  ; Daily snowfall climatology over reference period
  clim_prec = dblarr(365) + !values.f_nan
  for d = 1, 365 do begin
    idx = where((rday eq d) and $
                (ryear ge ref_start) and $
                (ryear le ref_end) and $
                (temp lt 1) and finite(prec), count)
    if count gt 0 then $
      clim_prec[d-1] = mean(double(prec[idx]))
  endfor
  ; Rolling ndays snowfall totals
  nt = n - ndays + 1
  if nt lt 1 then $
    message, 'Time series too short for selected ndays.'
  event_total = dblarr(nt) + !values.f_nan
  for i = 0, nt-1 do begin
    p = prec[i:i+ndays-1]
    t = temp[i:i+ndays-1]
    good = where(finite(p), ngood)
    if ngood eq ndays then begin
      ; Require at least one snow day in window
      if min(t) lt 1 then $
        event_total[i] = total(p)
    endif
  endfor
  ; Valid events
  event_idx = where(finite(event_total), nevent)
  if nevent lt 1 then $
    message, 'No snowfall events found.'
  ; Top X percent events
  n_top = long(floor(percent * nevent))
  if n_top lt 1 then n_top = 1
  isort = sort(event_total[event_idx])
  top_events = event_idx[isort[nevent - n_top : nevent - 1]]
  ; Flag days to replace
  replace_flag = bytarr(n)
  for j = 0, n_top-1 do begin
    i = top_events[j]
    replace_flag[i:i+ndays-1] = 1B
  endfor
  ; Replace with climatology
  prec_new = prec
  replace_idx = where(replace_flag eq 1B, nreplace)
  for j = 0, nreplace-1 do begin
    ii = replace_idx[j]
    d  = rday[ii]
    if finite(clim_prec[d-1]) then $
      prec_new[ii] = clim_prec[d-1]
  endfor
  print, 'Window length (days): ', ndays
  print, 'Number of replaced events: ', n_top
  print, 'Number of replaced days: ', nreplace
  return, prec_new
end