; *************************************************************
; rmean
;
; Compute a running (moving) mean of a 1-D array over a specified
; window width.
;
; Forces the window width to be odd, then for each element collects
; all indices within the half-width on either side and replaces the
; element with their mean. Used in GloGEM to smooth temperature
; variability time series and topographic attributes such as slope
; and aspect along glacier elevation bands.
; *************************************************************

function RMEAN, array, width, dim
compile_opt idl2
if (N_PARAMS() lt 3) then dim=0
if (width mod 2) eq 0 then width=width+1
w2=long(width)/2
s=size(array) & res=array
n=s[dim+1] & ind=indgen(n)

for i=0l,n-1 do begin
    ii=where(ind ge i-w2 and ind le i+w2)
    res[i]=mean(array[ii])
endfor
RETURN, res
END  ; {rmean}
