function X_S, x
  a=-1 & a=[!x.crange(0)+(!x.crange(1)-!x.crange(0))*x]
  return, a(0)
end
