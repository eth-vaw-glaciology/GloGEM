
; Compilation of GCM temperature, precipitation

allregions='n'   ; y: run all 19 RGI regions
region=['CentralEurope']
tran=[1850,2100]  ; time period of data set
overwrite_all='y'               ; y: overwrite all files, even if they exist

; GCMs
gcm=['bcc-csm2-mr']; 
ssp=['ssp126']

; ----------------------

path='/scratch_net/vierzack04_third/lvantrich/gmip4/'
path_in='/scratch_net/vierzack04_third/lvantrich/gmip4/files/'
batch_gl='/scratch_net/iceberg_second/mhuss/global_thickness/rgi60/'
batch_data='/home/mhuss/projects/global_retreat/data/'

len=(tran(1)-tran(0)+1)
n_gcms=n_elements(gcms) & n_rcps=n_elements(rcps) 

; ---------------------

fn=batch_data+'region_batch.dat' & anz=file_lines(fn)-1
tt=strarr(anz) & region_loop_data=strarr(5,anz) & s=strarr(1)
openr,1,fn & readf,1,s & readf,1,tt & close,1

for i=0,anz-1 do begin
   a=strsplit(tt(i),' ',/extract) & for j=0,4 do region_loop_data(j,i)=a(j)
endfor

fn=batch_data+'/regions.dat' & anz=file_lines(fn)-1 & s=strarr(1) & tt=strarr(anz)
openr,1,fn & readf,1,s & readf,1,tt & close,1
reg=strarr(anz) & subreg=reg & rlons=dblarr(2,anz) & rlats=dblarr(2,anz)
for i=0,anz-1 do begin
   a=strsplit(tt(i),' ',/extract)
   reg(i)=a(1) & subreg(i)=a(2) & rlons(0,i)=double(a(3)) & rlons(1,i)=double(a(4))
   rlats(0,i)=double(a(5)) & rlats(1,i)=double(a(6))
endfor

; *******************************************
; *******************************************
; loop over regions

;for rg=0,n_reg-1 do begin
for rg=14,14 do begin
      
   if allregions eq 'y' then region_now=reg(rg) else region_now=region(0)
      sureg=subreg(rg)
      print, sureg
      
      ; get a batch-file for the position of all glaciers (and determine closest cells)
ii=where(region_now eq region_loop_data(2,*))
fn=batch_gl+'files/thick_'+region_loop_data(4,ii(0))+'.dat'
anz=file_lines(fn)-1 & ngl=anz & s=strarr(anz) & tt=strarr(1)
openr,1,fn & readf,1,tt & readf,1,s & close,1
id=strarr(anz) & xy=dblarr(2,anz)
for i=0l,anz-1 do begin
   id(i)=strmid(s(i),0,5)
   a=strsplit(s(i),' ',/extract) & for j=0,1 do xy(j,i)=double(a(1+j))
endfor
ng=anz

if sureg ne 'n' then sreg='_'+sureg else sreg=''
hh=where(region_now eq reg and sureg eq subreg,ch)
lat=rlats(*,hh(0))
lon=rlons(*,hh(0))


; *******************************
; Loop over all GCMs

print, region_now,';   ' ,gcm

; read lat / lon / time variables for one single file
id=NCDF_OPEN(path_in+'/'+gcm+'/BCC-CSM2-MR_ssp126_r1i1p1f1_tas_era5corrected.nc')
; get position of variables
tt=NCDF_INQUIRE(id)
nv=tt.nvars
vv=strarr(nv)
for i=0,nv-1 do begin
   r=NCDF_VARINQ(id,i)
   vv(i)=r.name
endfor
lala=where(vv eq 'lat')
lolo=where(vv eq 'lon')
tata=where(vv eq 'tas')
titi=where(vv eq 'time')

NCDF_VARGET,id,lolo(0),all_lons
NCDF_VARGET,id,lala(0),all_lats
NCDF_VARGET,id,titi(0),timetest
NCDF_CLOSE,id

all_lons0=all_lons
all_lats0=all_lats
ii=where(all_lons gt 180)
all_lons(ii)=all_lons(ii)-360.

nrc=0

a=findfile(path+region_now+'/'+gcm+'/'+ssp)
if a(0) eq '' then begin
   spawn,'mkdir '+path+region_now+'/'+gcm+'/'+ssp & spawn,'chmod a+rx '+path+region_now+'/'+gcm+'/'+ssp
endif

fnt=path_in+'/'+gcm+'/BCC-CSM2-MR_'+ssp+'_'+'r1i1p1f1_tas_era5corrected.nc'
fnp=path_in+'/'+gcm+'/BCC-CSM2-MR_'+ssp+'_'+'r1i1p1f1_pr_era5corrected.nc'  

a=findfile(fnt)
b=findfile(fnp)

; check if SSP file for the respective GCM is available 
if a(0) ne '' and b(0) ne '' then begin  
   
; ****************** crop region first to save computation time

   ii=where(all_lats0 ge lat(0) and all_lats0 le lat(1),ci)
   jj=where(all_lons0 ge lon(0) and all_lons0 le lon(1),cj)
   kk=-1
   if lon(0) gt lon(1) then begin
      jj=where(all_lons0 le lon(1),cj)
      kk=where(all_lons0 ge lon(0),ck)        
   endif
   if kk(0) eq -1 then n=cj else n=cj+ck

; temperature
   id=NCDF_OPEN(fnt)
   NCDF_VARGET,id,titi(0),time
   nday=n_elements(time)
   hh1=indgen(nday)
   if kk(0) eq -1 then NCDF_VARGET,id,tata(0),temp,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,nday] $
    else begin
	NCDF_VARGET,id,tata(0),tt1,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,nday]
	NCDF_VARGET,id,tata(0),tt2,offset=[kk(0),ii(0),hh1(0)],count=[ck,ci,nday]
        temp=dblarr(cj+ck,ci,nday)
        for h=0l,nday-1 do begin
           for i=0,ci-1 do begin
              temp(0:ck-1,i,h)=tt2(*,i,h)
              temp(ck:ck+cj-1,i,h)=tt1(*,i,h)
           endfor
        endfor
     endelse      
   NCDF_CLOSE,id
; calculate REAL values
   temp=temp-273.15             ; deg C
   
; precipitation
   id=NCDF_OPEN(fnp)
   if kk(0) eq -1 then NCDF_VARGET,id,tata(0),prec,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,nday] $
       else begin                            
      NCDF_VARGET,id,tata(0),tt1,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,nday]
      NCDF_VARGET,id,tata(0),tt2,offset=[kk(0),ii(0),hh1(0)],count=[ck,ci,nday]
      prec=dblarr(cj+ck,ci,nday)
      for h=0l,nday-1 do begin
         for i=0,ci-1 do begin
            prec(0:ck-1,i,h)=tt2(*,i,h)
            prec(ck:ck+cj-1,i,h)=tt1(*,i,h)
         endfor
      endfor
   endelse
   NCDF_CLOSE,id
; calculate 
   prec=prec*3600.*24.*30       ; mm/mon
   
; only write latitude/longitude files and resample array in first SSP
   if nrc eq 0 then begin
      all_lats=all_lats(ii)
      if kk(0) eq -1 then all_lons=all_lons(jj) else begin
         tt=dblarr(ck+cj) & tt(0:ck-1)=all_lons(kk) & tt(ck:ck+cj-1)=all_lons(jj) & all_lons=tt
      endelse
; write out a simple GCM coordinate grid for each region
      openw,4,path+region_now+'/'+gcm+'/longitudes.dat'
      printf,4,'All GCM grid longitudes contained in region'
      for i=0,n_elements(all_lons)-1 do printf,4,all_lons(i),fo='(f12.3)'  & close,4
      openw,4,path+region_now+'/'+gcm+'/latitudes.dat'
      printf,4,'All GCM grid latitudes contained in region'
      for i=0,n_elements(all_lats)-1 do printf,4,all_lats(i),fo='(f12.3)'  & close,4
   endif

   ; generate time variables
   ff=n_elements(time)/251.  ; factor detecting GCMs with leap years
   
;   if ff lt 365.1 and ff gt 364.5 then ff=365

; Define the range of years
start_year = 1850
end_year = 2100
num_years = end_year - start_year + 1

; Create the array of months (1 to 12 repeated for each year)
month = REPLICATE(INDGEN(12) + 1, num_years)
; Create the array of years (each year repeated 12 times for each month)
years = REFORM(REPLICATE(INDGEN(num_years) + start_year, 12), num_years * 12)

; ************** Loop over glaciers *************
; -----------------------------------------------

; loop over ALL glaciers
for g=0l,ng-1 do begin

   if g mod 1000 eq 0 then print, region_now+'; '+gcm+'/'+ssp+': done '+string(g*100./ng,fo='(f6.2)')+'%'
   
   ; locate closest grid cell
   a=min(abs(xy(0,g)-all_lons),indx) & a=min(abs(xy(1,g)-all_lats),indy)
   gx=strcompress(string(all_lons(indx),fo='(f7.2)'),/remove_all)
   gy=strcompress(string(all_lats(indy),fo='(f7.2)'),/remove_all)
   a=findfile(path+region_now+'/'+gcm+'/'+ssp+'/clim_'+gx+'_'+gy+'.dat')

   ; start extraction when no file for the respective glacier is available
   if a(0) eq '' or overwrite_all eq 'y' then begin

      hh=indgen(ndays)

      openw,4,path+region_now+'/'+gcms+'/'+ssp+'/clim_'+gx+'_'+gy+'.dat'
      printf,4,'Meteorological forcing for grid cell '+gx+'(lon)_'+gy+'(lat)'
      printf,4,gcms+'/'+ssp
      printf,4,'Year  Month  temp(deg)  prec(mm)'

; write file
      ; past climate (up to 2015)
      for h=0l,nday-1 do printf,4,yp(h),mop(h),temp(indx,indy,h),prec(indx,indy,h),fo='(i4,2i6,f13.4,2f11.3)'
      close,4
      if g eq 0 then print,y(h-1),mo(h-1)

   endif                        ; climate file does yet not exist
   
endfor                          ; loop over all glaciers

nrc=nrc+1

endif                           ; SSP available


endfor                          ; loop over regions


print, 'end'

end
