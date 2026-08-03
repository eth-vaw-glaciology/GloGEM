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
