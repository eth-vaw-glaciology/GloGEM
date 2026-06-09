; *************************************************************
; write_volume_below_sea_level
;
; Write file for volume below sea level
; *************************************************************

compile_opt idl2

for i=0,years-1 do printf,7,tran[0]+i,vol_bz[i],fo='(i4,f12.2)'
close,7
close,33
