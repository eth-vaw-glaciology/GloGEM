; ***************************************
; Read glacier inventory batch file 
; ***************************************
;read batch file for all glaciers to be considered 
; (taken from ice thickness data set)

compile_opt idl2

fn=dir_data+'../files/thick_'+region+'.dat' & anz=file_lines(fn)-1 & s=strarr(1) & st=strarr(anz)
openr,1,fn & readf,1,s & readf,1,st & close,1
tti=strarr(anz) & id=tti & tt=dblarr(19,anz)
for i=0l,anz-1 do begin
   a=strsplit(st[i],' ',/extract) & tti[i]=a[0] & for j=0,18 do tt[j,i]=double(a[j+1])
endfor
hmed=tt[8,*] & hmin=tt[6,*] & survey_year=tt[18,*] & volume_ini=tt[3,*] & xy=tt[0:1,*] & a_gl=tt[2,*]
lat_gl=xy[1,*] & lon_gl=xy[0,*] & tt=a_gl
for i=0l,anz-1 do id[i]=strsplit(tti[i],';',/extract)

; perform potential de-biasing of glacier areas for the Maffezzoli thicknesses
if RGIversion eq '7' then begin
   fn=dir_data+'../files_HF/thick_'+region+'.dat' & anz=file_lines(fn)-1 & s=strarr(1) & st=strarr(anz)
   openr,1,fn & readf,1,s & readf,1,st & close,1
   tti=strarr(anz) & tt=dblarr(anz) & area_correction_factor=dblarr(anz)
   for i=0l,anz-1 do begin
      a=strsplit(st[i],' ',/extract) & tti[i]=a[0] & tt[i]=double(a[3])
      area_correction_factor[i]=tt[i]/a_gl[i]
   endfor
   a_gl=tt    ; overwriting areas with those from RGIv7.0 inventory
endif else area_correction_factor=dblarr(anz)+1.
