PRO READ_FIRNICEBATCH,dir,firnice_batch_data1,firnice_batch_data2,nffbl
compile_opt idl2

  fn=dir+'icetemperature_batch.dat' & nffbl=file_lines(fn)-1 & s=strarr(nffbl) & tt=strarr(1)
  openr,1,fn & readf,1,tt & readf,1,s & close,1
  firnice_batch_data1=dblarr(3,nffbl) & firnice_batch_data2=strarr(2,nffbl)
  for i=0,nffbl-1 do begin
     a=strsplit(s[i],',',/extract) & firnice_batch_data2[0,i]=strcompress(strmid(a[4],10,5)) & firnice_batch_data2[1,i]=strcompress(a[1],/remove_all)
     firnice_batch_data1[0,i]=double(a[2]) & firnice_batch_data1[1,i]=double(strmid(a[4],7,2)) & firnice_batch_data1[2,i]=double(a[10])
  endfor
  
end
