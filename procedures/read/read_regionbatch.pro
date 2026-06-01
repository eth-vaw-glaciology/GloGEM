compile_opt idl2

fn=dir+'region_batch.dat' & anz=file_lines(fn)-1
tt=strarr(anz) & region_loop_data=strarr(5,anz) & s=strarr(1)
openr,1,fn & readf,1,s & readf,1,tt & close,1
for i=0,anz-1 do begin
   a=strsplit(tt[i],' ',/extract) & for j=0,4 do region_loop_data[j,i]=a[j]
endfor
