; *************************************************************
; read_regionbatch
;
; Read the region batch file to obtain the list of RGI regions and
; associated metadata for the current model run.
;
; Parses region_batch.dat, splitting each whitespace-delimited row
; into five fields (region ID, region name, directory name, and
; supplementary identifiers) stored in the region_loop_data string
; array. The array is subsequently used to construct file paths and
; loop over the selected regions.
; *************************************************************

compile_opt idl2

fn=dir+'region_batch.dat' & anz=file_lines(fn)-1
tt=strarr(anz) & region_loop_data=strarr(5,anz) & s=strarr(1)
openr,1,fn & readf,1,s & readf,1,tt & close,1
for i=0,anz-1 do begin
   a=strsplit(tt[i],' ',/extract) & for j=0,4 do region_loop_data[j,i]=a[j]
endfor
