; Renew the variables while solving the continuity equation
; (which is performed in three intermediate steps)
compile_opt idl2

sur[1 : xnum - 1] = bed[1 : xnum - 1] + th[1 : xnum - 1]
width_surface = width_base + lambda * th
width_mid = (width_base + width_surface) / 2.0
