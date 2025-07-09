; ----------------------------------------------------------------------- ;
; ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)---- ;
; ------------ Adaptation into idl by: Janosch Beer (2025) -------------- ;
; ------- glacierflow function: time-evolution of the glacier   --------- ;
; ----------------------------------------------------------------------- ;

compile_opt idl2

time = ye ; get the current time in years -> note the time step within the glogemflow model is smaller & adaptive

; Loop over the time steps from start year to end year
while time lt tran[1] do begin
  ; ------------------------------------------ ;
  ; Update the time and the time step
  @procedures/flow/update_time_dt

  ; ------------------------------------------ ;
  ; Load & apply surface mass balance (SMB) from GloGEM
  if (time - next_time_mb) ge 0 then begin
    @procedures/flow/massbal
    next_time_mb = next_time_mb + dtmb
  endif

  ; ------------------------------------------ ;
  ; Diffusivity factor calculation
  @procedures/flow/diffusivity

  ; ------------------------------------------ ;
  ; Ice thickness change calculation (i.e. solve continuity equation)
  @procedures/flow/ice_thickness

  ; ------------------------------------------ ;
  ; Write diagnostic output
  ; @procedures/flow/diagnostic_write

  print, 'Time step (years): ', time
  break
endwhile

; ------------------------------------------ ;
; Update vertical grid geometry
; @procedures/flow/update_vertical_grid
@procedures/flow/conservative_volume_vertical_grid_update
