function Y_S, y
compile_opt idl2
  a=-1 & a=[!y.crange[0]+(!y.crange[1]-!y.crange[0])*y]
  return, a[0]
end
