; *************************************************************
; x_s
;
; Convert a fractional x position (0–1) to an absolute data
; coordinate within the current IDL plot window.
;
; Uses the system variable !x.crange to linearly interpolate the
; fractional value x to the corresponding data-space x coordinate,
; allowing plot annotations to be placed at proportional positions
; independent of the axis range.
; *************************************************************

function X_S, x
compile_opt idl2
  a=-1 & a=[!x.crange[0]+(!x.crange[1]-!x.crange[0])*x]
  return, a[0]
end
