; *************************************************************
; write_firnicetemp_file
;
; Write firn ice temperature procedure
; *************************************************************

compile_opt idl2


if firnice_write[0] eq 'y' then begin
   for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,45,elev0[i],elev_firnicetemp[0,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,45 
   for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,46,elev0[i],elev_firnicetemp[1,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,46 
   for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,47,elev0[i],elev_firnicetemp[2,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,47 
   for i=0,n_elements(elev_firnicetemp[0,0,*])-1 do printf,48,elev0[i],elev_firnicetemp[3,*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,48 
endif

if firnice_write[1] eq 'y' then begin
   for i=0,n_elements(firnice_profile)-1 do close,51+i
endif
