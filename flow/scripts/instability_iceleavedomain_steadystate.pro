; This function checks whether an instability occurs, whether ice is
; leaving the domain, whether a steady state is reached, or whether there
; is no ice left. If this is the case --> breakindex will be equal to 1 and
; in the 'glacier.pro' the time-loop will be interrupted and left

function instability_iceleavedomain_steadystate, glacier_id, th, smb_sinus_flag, vol_hist, counter_diag, ss_criterion, time, start_year, glacier_length, domain_exit_index, vol, obs_vol_flowlinemodel, mb_type_flag
  compile_opt idl2

  breakindex = 0

  ; Check for numerical instability
  if ~finite(mean(th)) or mean(th) eq !values.f_infinity then begin
    print, 'Numerical instability! Glacier id = ', glacier_id
    breakindex = 1
    vol = !values.f_nan ; in case mean(th) eq Infinity --> give it NaN value, for volume_calibration
    return, breakindex
  endif

  ; Check if ice is leaving the domain (but not for sinusoidal forcing)
  if th[domain_exit_index] gt 0 and smb_sinus_flag eq 0 then begin
    print, 'Ice is leaving the domain! Glacier id = ', glacier_id
    th[*] = !values.f_nan

    ; Volume is smaller than 5x observed volume (likely that no 'explosion' occurred...)
    if vol lt 5 * obs_vol_flowlinemodel then begin
      ; Can't assign string 'out' to a numeric variable
      ; Either use a special numeric value like -999 or create a status variable
      vol = -999 ; Use a special numeric code for "out" condition
    endif else begin
      ; Likely that a kind of explosion occurred (i.e. numerical instability)
      vol = !values.f_nan
    endelse

    breakindex = 1
    return, breakindex
  endif

  ; Check for steady state
  if counter_diag gt 2 and mb_type_flag ne 6 then begin
    ; Volume change less than [ss criterion] % and not for sinusoidal mode
    if abs((vol_hist[counter_diag - 1] - vol_hist[counter_diag - 2]) / vol_hist[counter_diag - 1]) lt ss_criterion / 100.0 $
      and smb_sinus_flag eq 0 and time gt start_year + 50 + sqrt(glacier_length) then begin
      print, 'Steady state reached!'
      breakindex = 1
    endif

    ; Check for ice-free condition
    if vol eq 0 then begin
      print, 'Ice free!'
      breakindex = 1
    endif
  endif

  return, breakindex
end
