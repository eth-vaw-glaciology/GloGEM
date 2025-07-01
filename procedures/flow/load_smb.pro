;---------------------------------

; This file loads the modeledelled SMB data computed by GloGEM & converts it to the horizontally equidistant grid using interpolation.

;---------------------------------
compile_opt idl2

surf_elev_eq = (glacier_geom[*, 1] + glacier_geom[*, 2]) / 2 ; Reference surface elevation (m) of vertical grid
bal_x = interpol(bal, surf_elev_eq, sur_x) ; Interpolate the SMB balance to the new grid

; check results
; Print, 'bal = ', bal
; Print, 'bal_x = ', bal_x
