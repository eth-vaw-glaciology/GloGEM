; *************************************************************
; process_hypsometry_data
;
; Process hypsometry data for the current glacier.
;
; Extracts elevation band properties from the hypsometry array,
; corrects unrealistic bed elevations, applies region-specific
; parabolic bedrock corrections, and stores initial area/volume.
; *************************************************************

compile_opt idl2

; extract elevation band variables
area=da[3,*] & elev=da[1,*]+5 & thick=da[4,*] & width=da[5,*] & slope=da[7,*]
ii=where(area gt 0 and thick eq 0,ci) & if ci gt 0 then thick[ii]=3.
bed_elev=elev-thick & step=elev[1]-elev[0] & e0=elev[0] & elev0=elev

; correct unrealistic values in lowest band
if bed_elev[0] lt 0 and thick[0] gt thick[1]+2. then begin
   thick[0]=thick[1]+2. & bed_elev=elev-thick
endif

; region-specific transversal bedrock shape corrections
if dir_region eq 'SouthernAndes' then bedrock_parabolacorr=0.35
if dir_region eq 'Greenland' then bedrock_parabolacorr=0.30

; bedrock profile corrected for parabola-shape
if min(bed_elev) lt 200 then begin
   bed_elev_p=bed_elev-bedrock_parabolacorr*thick
   for i=0,nb-1 do if width[i] gt (crit_ccorrdist/2.) then bed_elev_p[i]=bed_elev[i]-thick[i]*bedrock_parabolacorr*(crit_ccorrdist/2.)/width[i]
endif

ii=where(thick gt 0,ci) & if calibrate eq 'y' and ci eq 0 then thick=thick+1.
gl=dblarr(nb)+noval & if ci gt 0 then gl[ii]=elev[ii]
length=dblarr(nb) & for i=0,nb-1 do length[i]=(max(da[6,*])-da[6,i])/1000.
thick_ini=thick & area_ini=area
area_iniconst=area
volume0=total(thick_ini*area_ini)/1000.
tgs_cum=dblarr(nb)
