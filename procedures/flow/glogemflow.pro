; ----------------------------------------------------------------------- ;
; ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)---- ;
; ------------ Adaptation into idl by: Janosch Beer (2025) -------------- ;
; ------- glacierflow function: time-evolution of the glacier   --------- ;
; ----------------------------------------------------------------------- ;

compile_opt idl2

; ------------------------------------------ ;
; Update the time and the time step
@procedures/flow/update_time_dt

; ------------------------------------------ ;
; Load surface mass balance (SMB) from GloGEM
@procedures/flow/load_smb

; ------------------------------------------ ;
; Diffusivity factor calculation
@procedures/flow/diffusivity

; ------------------------------------------ ;
; Ice thickness change calculation (i.e. solve continuity equation)
@procedures/flow/ice_thickness
