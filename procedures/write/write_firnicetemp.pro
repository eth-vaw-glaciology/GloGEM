; *************************************************************
; write_firnicetemp
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
   fo_prof = '(2i4,'+string(total(fit_layers),fo='(i2)')+'f8.3)'
   for j=0,n_elements(firnice_profile)-1 do begin
      get_lun, _plun
      openw, _plun, firnice_dir + '/temp_ID' + firnice_profile_ID[j] + '_' + id[gg[g]] + '.dat'
      printf, _plun, fit_prof_hdr[j,0]
      printf, _plun, fit_prof_hdr[j,1]
      for r_prof=0l, fit_prof_n[j]-1 do $
         printf, _plun, fit_prof_ym[j,r_prof,0], fit_prof_ym[j,r_prof,1], reform(fit_prof_val[j,r_prof,*]), fo=fo_prof
      free_lun, _plun
   endfor
endif
