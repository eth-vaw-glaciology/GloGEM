; *****************************************
; Catchment selection
; *****************************************
; This procedure selects a specific subset of glaciers from a list (catchment) within one RGI region

if rgiregion lt 10 then a='0'+string(rgiregion,fo='(i1)') else a=string(rgiregion,fo='(i2)')
fn=dir+'catchments/RGI'+a+'_'+catchment_selection+'.dat' & an=file_lines(fn)-1 & s=strarr(an) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,s & close,1 & ss=strmid(s,9,5)

; running through full batch file and marking all glaciers to be computed and then reduce array
n=n_elements(id) & tt=dblarr(n)
for i=0l,n-1 do begin
  ii=where(id[i] eq ss,ci) & if ci gt 0 then tt[i]=1
endfor
ii=where(tt eq 1,ci)
if ci gt 0 then begin
    hmed=hmed[ii] & hmin=hmin[ii] & survey_year=survey_year[ii] & volume_ini=volume_ini[ii]
    xy=xy[*,ii] & a_gl=a_gl[ii] & id=id[ii]
endif
lat_gl=xy[1,*] & lon_gl=xy[0,*]