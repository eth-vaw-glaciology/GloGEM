; *************************************************************
; y_s
;
; Convert a fractional y position (0–1) to an absolute data
; coordinate within the current IDL plot window.
;
; Uses the system variable !y.crange to linearly interpolate the
; fractional value y to the corresponding data-space y coordinate,
; allowing plot annotations to be placed at proportional positions
; independent of the axis range.
; *************************************************************

function Y_S, y
compile_opt idl2
  a=-1 & a=[!y.crange[0]+(!y.crange[1]-!y.crange[0])*y]
  return, a[0]
end
