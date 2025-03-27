PRO READ_HYPSOMETRYFILE,fn,gg,g,a_gl,nb,da,advance,adv_calving,adv_addband,adv_addband0,hmin, dir_data_alt, region
  
  nb=file_lines(fn)-5
  s=strarr(5) & da=dblarr(12,nb)
  openr,1,fn & readf,1,s & readf,1,da & close,1

; performing a check on consensus thickness data and replace with
; HF2012(updated) if needed
if min(da(1,*)) lt -300 or abs(a_gl(gg(g))-total(da(3,*)))*100./a_gl(gg(g)) gt 50 then begin
   fn=dir_data_alt+'/'+region+'/'+id(gg(g))+'.dat' & a=findfile(fn)
   nb=file_lines(fn)-5 & s=strarr(5) & da=dblarr(12,nb)
   openr,1,fn & readf,1,s & readf,1,da & close,1
endif
   
; add bands at glacier tongue
if advance eq 'y' and nb gt 3 then begin
    adv_addband=adv_addband0
   if adv_calving lt 0 then adv_hmin=adv_calving else adv_hmin=10.
   if hmin(gg(g))-adv_addband*10. lt adv_hmin then adv_addband=fix((hmin(gg(g))-adv_hmin)/10)
   adv_addband=max([0,adv_addband])
   nb0=nb & nb=nb+adv_addband & tt=da & da=dblarr(12,nb) & da(*,nb-nb0:nb-1)=tt(*,0:nb0-1)
   for i=nb-nb0-1,0,-1 do da(1,i)=da(1,i+1)-10.
endif

end
