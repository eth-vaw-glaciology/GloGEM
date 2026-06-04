; ************************************************************************
; ************************************************************************
; READ_HYPSOMETRYFILE.pro

; read data on surface elevation and thickness specified for elevation
; bands (typically 10m) for every glacier.
; Performing some quality checks and potential corrections of the
; ice thickness distribution and selecting data set to be used
; Make some preparation to capture glacier advance (prolong bedrock
; profile in front of glacier) 

; ************************************************************************
; ************************************************************************

compile_opt idl2
  
; read default glacier geometry file
;    (RGI6.0: Farinotti et al 2019)
;    (RGI7.0: Maffezzoli et al 2026)
  nb=file_lines(fn)-5
  s=strarr(5) & da=dblarr(11,nb)
  openr,1,fn & readf,1,s & readf,1,da & close,1

  ; potentially correcting all glacier areas to offset bias in RGIv7.0 thickness data
  da[3,*]=da[3,*]*area_correction_factor[gg[g]]
  volume_ini[gg[g]]=total(da[3,*]*da[4,*])/1000.   ; also now updating initial ice volume

; performing a check on reference thickness data and replace with
; HF2012(updated) if needed
if RGIversion eq '6' then begin   ; checks relevant to RGIv6.0
   if min(da[1,*]) lt -300 or abs(a_gl[gg[g]]-total(da[3,*]))*100./a_gl[gg[g]] gt 50 then begin
      fn=dir_data_alt+'/'+region+'/'+id[gg[g]]+'.dat' & a=findfile(fn)
      nb=file_lines(fn)-5 & s=strarr(5) & da=dblarr(12,nb)
      openr,1,fn & readf,1,s & readf,1,da & close,1
   endif
endif else begin   ; checks relevant to RGIv7.0
   if a_gl[gg[g]] lt 0.25 then begin   ; very small glaciers only for now
      if RGIversion eq '6' then a='' else a='bands_'
      fn=dir_data_alt+'/'+region+'/'+a+id[gg[g]]+'.dat' & a=findfile(fn)
      nb=file_lines(fn)-5 & s=strarr(5) & da=dblarr(11,nb)
      openr,1,fn & readf,1,s & readf,1,da & close,1
      volume_ini[gg[g]]=total(da[3,*]*da[4,*])/1000. ; make sure initial volume is consistent
   endif
endelse
   
; add bands at glacier tongue
if advance eq 'y' and nb gt 3 then begin
    adv_addband=adv_addband0
   if adv_calving lt 0 then adv_hmin=adv_calving else adv_hmin=10.
   if hmin[gg[g]]-adv_addband*10. lt adv_hmin then adv_addband=fix((hmin[gg[g]]-adv_hmin)/10)
   adv_addband=max([0,adv_addband])
   nb0=nb & nb=nb+adv_addband & tt=da & da=dblarr((size(tt))[1],nb) & da[*,nb-nb0:nb-1]=tt[*,0:nb0-1]
   for i=nb-nb0-1,0,-1 do da[1,i]=da[1,i+1]-10.
endif

