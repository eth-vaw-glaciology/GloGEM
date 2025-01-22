function CM2NORM, x0,y0, xd,yd , xscm,yscm
x=float(xscm) & y=float(yscm)
RETURN, [x0/x,y0/y,(x0+xd)/x,(y0+yd)/y]
END  ; {main}
