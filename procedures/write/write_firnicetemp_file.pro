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
   for i=0,n_elements(firnice_profile)-1 do free_lun,fit_prof_lun[i]
endif

if firnice_write[2] eq 'y' then begin
   ; One row per (year, band) that the temperature model actually touched.
   ; Bands never visited keep fit_field_cnt = 0 and are skipped, so the file
   ; contains only real data and the reader needs no no-value sentinel handling.
   nfit_w = long(total(fit_layers))
   for iy=0,years-1 do begin
      for ib=0,nb-1 do begin
         if fit_field_cnt[iy,ib] le 0d0 then continue
         prof = reform(fit_field_sum[iy,ib,*]) / fit_field_cnt[iy,ib]
         printf,90,iy+tran[0],elev0[ib],fit_field_th[iy,ib],long(fit_field_tt[iy,ib]),prof, $
                fo='(i6,i7,f9.2,i5,'+strcompress(string(nfit_w,fo='(i3)'),/remove_all)+'f8.3)'
      endfor
   endfor
   close,90

   if enable_advection eq 'y' then begin
      for iy=0,years-1 do begin
         for ib=0,nb-1 do begin
            if fit_vel_cnt[iy,ib] le 0d0 then continue
            uu = reform(fit_u_sum[iy,ib,*]) / fit_vel_cnt[iy,ib]
            ww = reform(fit_w_sum[iy,ib,*]) / fit_vel_cnt[iy,ib]
            printf,91,iy+tran[0],elev0[ib],long(fit_vel_tt[iy,ib]),uu,ww, $
                   fo='(i6,i7,i5,'+strcompress(string(2*nfit_w,fo='(i3)'),/remove_all)+'f10.3)'
         endfor
      endfor
      close,91
   endif
endif

if enable_advection eq 'y' and advection_write eq 'y' then begin
   for i=0,n_elements(elev_adv_horiz[0,*])-1 do printf,70,elev0[i],elev_adv_horiz[*,i],fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,70
   for i=0,n_elements(elev_adv_vert[0,*])-1  do printf,71,elev0[i],elev_adv_vert[*,i], fo='(i6,'+strcompress(string(years,fo='(i3)'),/remove_all)+'f8.3)' &  close,71
endif
