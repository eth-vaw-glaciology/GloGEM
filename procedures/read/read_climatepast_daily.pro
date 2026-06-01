compile_opt idl2


fn=dir_clim+'reanalysis/daily/'+reanalysis+'/'+dir_region+'/clim_'+gxs+'_'+gys+'.dat'
anz=file_lines(fn)-3 & da=dblarr(7,anz) & tt=strarr(3)
openr,1,fn & readf,1,tt & readf,1,da & close,1
tempre=da[4,*] & precre=da[5,*] & ryear=da[0,*] & rday=da[2,*] & rmon=da[1,*] & dtdz=da[6,*]/100.
a=strsplit(tt[1],':',/extract) & hclim=double(a[1])
prec_orig=precre  ; storing full precipitation array (with many wet days) for bias correction
cyear=ryear & cday=rday & temp=tempre & prec=precre

; removing low daily precipitation amounts
ii=where(prec lt p_thres,ci) & if ci gt 0 then prec[ii]=0
