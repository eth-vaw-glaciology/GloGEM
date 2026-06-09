; *************************************************************
; cm2norm
;
; Convert plot-window coordinates in centimetres to normalised
; device coordinates.
;
; Takes an origin (x0, y0) and extent (xd, yd) in centimetres together
; with the total window size (xscm, yscm) and returns a four-element
; array [x0_norm, y0_norm, x1_norm, y1_norm] suitable for positioning
; plot elements in IDL normalised coordinate space.
; *************************************************************

function CM2NORM, x0,y0, xd,yd , xscm,yscm
compile_opt idl2
x=float(xscm) & y=float(yscm)
RETURN, [x0/x,y0/y,(x0+xd)/x,(y0+yd)/y]
END  ; {main}
