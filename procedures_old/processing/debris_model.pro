PRO DEBRIS_MODEL,ye

; get current long-term GEOMETRIC ELA of glacier (55% acc area, 45% abl area)
; debris is only updated BELOW this theshold, actually there should be not debris above!
if ye lt 10 then begin
   a=0
   debris_seed_meters=10.    ; annual increase in elevation range, where seeding is possible
   for i=0,nb-1 do begin
      a=a+area(i) &  medelev=i & if a gt ar_gl*0.45 then i=nb
   endfor
; if ELA is computed internally for more than 10 years, use decadal average instead of median elevation
endif else begin
   a=mean(ela(ye-10:ye-1)) & b=min(abs(elev-a),ind) & medelev=ind
  ; find ELA-dependent seeding factor based on regression of ELA-changes during the last 10 years
   debris_seed_meters=mean(mb(ye-10:ye-1))*debris_seed_bands*(-1.)
endelse


; get time interval since start of dynamic model
debris_time=0
if ye+tran(0) gt survey_year(gg(g)) then debris_time=ye+tran(0)-survey_year(gg(g))


; spatial expansion of debris and ponds/cliffs over time
;    clean-ice glacier will remain clean-ice glaciers!
;    glaciers without ponds/cliff will not get any!
if debris_expansion eq 'y' and debris_time gt 0 then begin        

; debris extension
count_seed_bands=0
   for i=0,medelev do begin
      ; case 1: debris present in band but not everywhere => extension WITHIN band
      if debris_frac(i) gt 0 and debris_frac(i) lt 1 then begin
         if bal(i) lt 0 and gl(i) ne noval then debris_frac(i)=debris_frac(i)+(debris_exp_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*max([debris_frac(i),0.25])
         ; max([debris_frac(i),0.25]) to ensure that at least a minimal number of extension is present, otherwise negilgible for small debris-fractions (to be verified)
         if debris_frac(i) gt 1 then debris_frac(i)=1
      endif
      ; case 2: no debris (yet) present in band => seeding from neighbouring bands
      ;   initial debris seed is the average of surrounding bands
      ;   per year, seed can only be laid in a number of bands defined by debris_seed_bands
      if i gt 0 and i lt nb-2 and count_seed_bands le debris_seed_meters/step then begin
         if debris_frac(i) eq 0 and max(debris_frac(i-1:i+1)) gt 0 then begin
            debris_frac(i)=(debris_frac(i-1)+debris_frac(i+1))/2
            debris_thick(i)=debris_initialband 
            count_seed_bands=count_seed_bands+1
         endif
      endif   
   endfor

; extension of ponds and cliffs (to used as no global data on ponds and cliffs are available)
count_seed_bands=0
   for i=0,medelev do begin
      ; case 1: ponds present in band => growth band
      if debris_ponddens(i) gt 0 then begin
         if bal(i) lt 0 and gl(i) ne noval then debris_ponddens(i)=debris_ponddens(i)+(debris_pond_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*max([debris_ponddens(i),0.02])
         ; max([debris_ponddens(i),0.02]) min value of 0.02 to be verified
         if debris_ponddens(i) gt debris_ponddens_max then debris_ponddens(i)=debris_ponddens_max 
      endif
      ; case 2: no ponds (yet) present in band => seeding from neighbouring bands
      ;   initial pond seed is the average of surrounding bands
      ;   per year, seed can only be laid in a number of bands defined by debris_seed_bands
      if i gt 0 and i lt nb-2 and count_seed_bands le debris_seed_meters/step  then begin
         if debris_ponddens(i) eq 0 and max(debris_ponddens(i-1:i+1)) gt 0 then begin
            debris_ponddens(i)=(debris_ponddens(i-1)+debris_ponddens(i+1))/2
            count_seed_bands=count_seed_bands+1
         endif
      endif   
   endfor

endif

if debris_thickening eq 'y' and debris_time gt 0 then begin       ; thickening of debris over time
   ; only applying debris thickening IF a debris thickness is already present
   ; i.e. not increasing a zero debris thickness!
   for i=0,medelev do begin
;      if debris_thick(i) gt 0 then debris_thick(i)=debris_thick0(i)+(debris_thick_gradient/100.)*debris_time*(elev(medelev)-elev(i))/1000. ; original code
      ; Compagno et al 2021
      if debris_frac(i) gt 0 then debris_thick(i)=debris_thick(i)+(debris_thick_gradient/100.)*bal(i)*mean(mb(ye-min([ye,10]):ye))*mean(debris_thick0(0:medelev))     
   endfor
endif

; prepare for output
if write_mb_elevationbands eq 'y' then begin
   for i=0,nb-1 do begin
      if gl(i) ne noval then begin
         elev_debthick(ye,i)=debris_thick(i) & elev_debfrac(ye,i)=debris_frac(i)
         elev_debfactor(ye,i)=debris_red_factor(i) & elev_pondarea(ye,i)=debris_ponddens(i)*area(i)
      endif
   endfor
endif


end
