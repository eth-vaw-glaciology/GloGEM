; Renew the variables while solving the continuity equation
; (which is performed in three intermediate steps)
compile_opt idl2

sur_x[1 : xnum - 1] = bed_x[1 : xnum - 1] + th_x[1 : xnum - 1]
width_surface = width_base + lambda * th_x
width_mid = (width_base + width_surface) / 2.0
