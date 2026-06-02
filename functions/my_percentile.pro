function MY_PERCENTILE, data, q
compile_opt idl2
data = data[sort(data)]
n = n_elements(data)
idx = q * (n - 1)
i0 = floor(idx)
i1 = i0 + 1
i1 = i1 < (n-1)
frac = idx - i0
RETURN, data[i0] + frac * (data[i1] - data[i0])
end