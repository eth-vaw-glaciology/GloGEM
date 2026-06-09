; *************************************************************
; my_percentile
;
; Compute a percentile value from a data array using linear
; interpolation between sorted elements.
;
; Sorts the input array, maps the fractional quantile q (0–1) to a
; real-valued index, and returns the linearly interpolated value
; between the two bracketing elements. Used for quantile-mapping bias
; correction of GCM temperature distributions.
; *************************************************************

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
