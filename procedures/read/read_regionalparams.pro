PRO READ_regionalparams, dir,reanalysis,dir_region,clim_subregion,size_range_overwrite, c_calving,c_prec,c1_tolerance,t_offset,toff_grid,toff_grid0,p_thres,size_range,time_resolution
  
  fn=dir+'regional_parameters_'+reanalysis+'.dat'
  if time_resolution eq 'monthly' then b=6 else b=10 & anz=file_lines(fn)-b
   ss=strarr(b) & da=strarr(anz) & openr,1,fn & readf,1,ss & readf,1,da & close,1
   tt=strarr(anz) & tt2=strarr(anz) & cc=dblarr(anz) & dptt=cc & tott=cc & cprtt=dblarr(3,anz) & toff_gr=tt2
   p_threshold=cc & size_range_ovw=dblarr(2,anz)
   for i=0l,anz-1 do begin
      a=strsplit(da(i),' ',/extract) & tt(i)=a(0)  & tt2(i)=a(1)
      cc(i)=double(a(2)) & for j=0,2 do cprtt(j,i)=double(a(3+j)) & dptt(i)=double(a(6)) & tott(i)=double(a(7)) & toff_gr(i)=a(8)
      if time_resolution eq 'daily' then begin
         p_threshold(i)=double(a(9)) & for j=0,1 do size_range_ovw(j,i)=double(a(10+j))
      endif
   endfor
   ii=where(dir_region eq tt,ci)
   if ci eq 1 then begin
      c_calving=cc(ii(0)) &   c_prec=cprtt(0,ii(0))
      c1_tolerance(0)=cprtt(1,ii(0)) & c1_tolerance(1)=cprtt(2,ii(0)) & dPdz=dptt(ii(0))
      t_offset=tott(ii(0)) & toff_grid=toff_gr(ii(0)) & toff_grid0=toff_gr(ii(0))
      if time_resolution eq 'daily' then begin
         p_thres=p_threshold(ii(0))
         if size_range_overwrite eq 'y' then size_range=size_range_ovw(*,ii(0))
      endif
   endif else begin
      jj=where(clim_subregion eq tt2(ii))
      c_calving=cc(ii(jj(0))) &   c_prec=cprtt(0,ii(jj(0)))
      c1_tolerance(0)=cprtt(1,ii(jj(0))) & c1_tolerance(1)=cprtt(2,ii(jj(0)))
      dPdz=dptt(ii(jj(0)))  & t_offset=tott(ii(jj(0))) & toff_grid=toff_gr(ii(jj(0))) & toff_grid0=toff_gr(ii(jj(0)))
      if time_resolution eq 'daily' then begin
         p_thres=p_threshold(ii(jj(0)))
         if size_range_overwrite eq 'y' then size_range=size_range_ovw(*,ii(jj(0)))
      endif
   endelse

end
