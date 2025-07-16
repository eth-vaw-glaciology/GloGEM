; Update the maximum time step allowed (dt_max), the time step itself (dt)
; and the time indeces ('t' and 'time')

; Note that this is specific for Alps and was found with some 'trial and
; error'. Will need other values for other regions in the world (e.g. with
; longer glaciers)
compile_opt idl2

dt_max = time / (dx * 2) ; Maximum allowed dt (dt will never be larger than this, even if the CFL criterion would allow for it). Small in the beginning --> increases with time
if dt_max lt 0.1 then begin
  dt_max = 0.1 ; Maximum time step should at least be 0.1 years (because otherwise very small in the beginning --> takes too long)
endif else if dt_max gt dtmb then begin ; Don't want the time step to be larger than the time step of DTMB (typically 1 year)
  dt_max = dtmb
endif

if dt_flag eq 0 and t gt 2 then begin ; Adapt the time step:
  ; Print diagnostics to understand why dt is so small and stays the same
  print, 'Diagnostics for dt calculation:'
  print, '  dx = ', dx
  print, '  dtfactor = ', dtfactor
  print, '  max(df_dx) = ', max(df_dx)
  print, '  Raw dt calculation = ', (dx ^ 2 / (max(df_dx))) * dtfactor
  print, '  dt_max = ', dt_max
  print, '  Previous dt = ', dt

  dt = (dx ^ 2 / (max(df_dx))) * dtfactor ; CFL type of criterion, multiplied with the 'dtfactor'
  if dt gt dt_max then dt = dt_max ; If needed: impose limit on the dt

  print, '  Updated dt = ', dt
endif

t = t + 1 ; timestep (integer)
time = time + dt ; time (in years)

; print, 'Time step: ', dt, ' years'

; if dt_flag eq 0 and t gt 2 then begin
; ; Add detailed diagnostics
; max_df = max(df_dx)
; ; print, 'max(df_dx) = ', max_df
; ; print, 'dx^2 = ', dx ^ 2
; ; print, 'dtfactor = ', dtfactor
; ; print, 'dx^2/max(df_dx) = ', dx ^ 2 / max_df
; ; print, 'Raw dt calculation = ', (dx ^ 2 / max_df) * dtfactor

; dt = (dx ^ 2 / (max(df_dx))) * dtfactor
; if dt gt dt_max then dt = dt_max

; ; print, 'Final dt = ', dt
; ; print, 'dt_max = ', dt_max
; endif
