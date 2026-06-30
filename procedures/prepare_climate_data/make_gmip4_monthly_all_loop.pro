
; Compilation of GCM temperature, precipitation

allregions='y'
region=['CentralEurope']
tran=[1850,2100]
overwrite_all='y'

path='/scratch_net/vierzack04_third/lvantrich/gmip4/'
path_in='/scratch_net/vierzack04_third/lvantrich/gmip4/files/'
batch_gl='/scratch_net/iceberg_second/mhuss/global_thickness/rgi60/'
batch_data='/home/mhuss/projects/global_retreat/data/'

; ----------------------
; GCMs and SSPs
; ----------------------

gcms=['BCC-CSM2-MR','ACCESS-ESM1-5','NorESM2-MM','MPI-ESM1-2-HR','IPSL-CM6A-LR','MIROC6']
ssps=['ssp126','ssp370','ssp585']

; ---------------------
; Read region batch file
; ---------------------

fn='/itet-stor/lvantrich/glogem/data/region_batch.dat'
anz=file_lines(fn)-1

tt=strarr(anz) & region_loop_data=strarr(5,anz) & s=strarr(1)
openr,1,fn
readf,1,s
readf,1,tt
close,1

for i=0,anz-1 do begin
   a=strsplit(tt(i),' ',/extract)
   for j=0,4 do region_loop_data(j,i)=a(j)
endfor

; ---------------------
; Read regions.dat
; ---------------------

fn='/itet-stor/lvantrich/glogem/data/regions.dat'
anz=file_lines(fn)-1

s=strarr(1)
tt=strarr(anz)

openr,1,fn
readf,1,s
readf,1,tt
close,1

reg=strarr(anz)
subreg=strarr(anz)
rlons=dblarr(2,anz)
rlats=dblarr(2,anz)

for i=0,anz-1 do begin
   a=strsplit(tt(i),' ',/extract)
   reg(i)=a(1)
   subreg(i)=a(2)
   rlons(0,i)=double(a(3))
   rlons(1,i)=double(a(4))
   rlats(0,i)=double(a(5))
   rlats(1,i)=double(a(6))
endfor

; *******************************************
; Loop over regions
; *******************************************

; for all regions:
; for rg=0,n_elements(reg)-1 do begin

; test one region:
for rg=22,22 do begin

   if allregions eq 'y' then region_now=reg(rg) else region_now=region(0)
   sureg=subreg(rg)

   print, 'REGION: ', region_now, '  SUBREGION: ', sureg

   ; get batch file for glacier positions
   ii=where(region_now eq region_loop_data(2,*),ch)
   if ch eq 0 then begin
      print, 'No region batch entry for: ', region_now
      goto, next_region
   endif

   fn='/itet-stor/lvantrich/glogem/geometricdata/rgiv7/thickness/files/thick_'+region_loop_data(4,ii(0))+'.dat'

   if file_test(fn) eq 0 then begin
      print, 'Thickness file missing: ', fn
      goto, next_region
   endif

   anz=file_lines(fn)-1
   ng=anz
   s=strarr(anz)
   tt=strarr(1)

   openr,1,fn
   readf,1,tt
   readf,1,s
   close,1

   id_gl=strarr(anz)
   xy=dblarr(2,anz)

   for i=0l,anz-1 do begin
      id_gl(i)=strmid(s(i),0,5)
      a=strsplit(s(i),' ',/extract)
      xy(0,i)=double(a(1))
      xy(1,i)=double(a(2))
   endfor

   if sureg ne 'n' then sreg='_'+sureg else sreg=''

   hh=where(region_now eq reg and sureg eq subreg,ch)
   if ch eq 0 then begin
      print, 'No region bounds found for: ', region_now
      goto, next_region
   endif

   lat=rlats(*,hh(0))
   lon=rlons(*,hh(0))

   ; *******************************************
   ; Loop over GCMs
   ; *******************************************

   for igcm=0,n_elements(gcms)-1 do begin

      gcm=gcms(igcm)

      ; *******************************************
      ; Loop over SSPs
      ; *******************************************

      for issp=0,n_elements(ssps)-1 do begin

         ssp=ssps(issp)

         print, 'Processing: ', region_now, '  ', gcm, '  ', ssp

         fnt=path_in+'/'+gcm+'/'+gcm+'_'+ssp+'_r1i1p1f1_tas_era5corrected.nc'
         fnp=path_in+'/'+gcm+'/'+gcm+'_'+ssp+'_r1i1p1f1_pr_era5corrected.nc'

         if file_test(fnt) eq 0 then begin
            print, 'Missing temperature file: ', fnt
            goto, next_ssp
         endif

         if file_test(fnp) eq 0 then begin
            print, 'Missing precipitation file: ', fnp
            goto, next_ssp
         endif

         ; ----------------------
         ; Read lat / lon / time / tas variables
         ; ----------------------

         ncid=ncdf_open(fnt)
         info=ncdf_inquire(ncid)
         nv=info.nvars
         vv=strarr(nv)

         for i=0,nv-1 do begin
            r=ncdf_varinq(ncid,i)
            vv(i)=r.name
         endfor

         lala=where(vv eq 'lat')
         lolo=where(vv eq 'lon')
         tata=where(vv eq 'tas')
         titi=where(vv eq 'time')

         ncdf_varget,ncid,lolo(0),all_lons
         ncdf_varget,ncid,lala(0),all_lats
         ncdf_varget,ncid,titi(0),timetest
         ncdf_close,ncid

         start_year=1850
         end_year=start_year+n_elements(timetest)/12-1

         all_lons0=all_lons
         all_lats0=all_lats

         ii180=where(all_lons gt 180,n180)
         if n180 gt 0 then all_lons(ii180)=all_lons(ii180)-360.

         ; ----------------------
         ; Make folders
         ; ----------------------

         dir1=path+region_now
         if file_test(dir1,/directory) eq 0 then file_mkdir,dir1

         dir2=dir1+'/'+gcm
         if file_test(dir2,/directory) eq 0 then file_mkdir,dir2

         dir3=dir2+'/'+ssp
         if file_test(dir3,/directory) eq 0 then file_mkdir,dir3

         spawn,'chmod a+rx "'+dir1+'"'
         spawn,'chmod a+rx "'+dir2+'"'
         spawn,'chmod a+rx "'+dir3+'"'

         ; ----------------------
         ; Read temperature
         ; ----------------------

         ncid=ncdf_open(fnt)
         ncdf_varget,ncid,titi(0),time
         nmon=n_elements(time)
         ncdf_varget,ncid,tata(0),temp
         ncdf_close,ncid

         temp=double(temp)-273.15

         ; ----------------------
         ; Read precipitation
         ; ----------------------

         ncid=ncdf_open(fnp)
         info=ncdf_inquire(ncid)
         nv=info.nvars
         vv=strarr(nv)

         for i=0,nv-1 do begin
            r=ncdf_varinq(ncid,i)
            vv(i)=r.name
         endfor

         prvar=where(vv eq 'pr',npr)

         if npr eq 0 then begin
            print, 'No pr variable found in: ', fnp
            ncdf_close,ncid
            goto, next_ssp
         endif

         ncdf_varget,ncid,prvar(0),prec
         ncdf_close,ncid

         prec=prec*3600.*24.*30.

         ; ----------------------
         ; Write lon/lat files
         ; ----------------------

         openw,4,path+region_now+'/'+gcm+'/longitudes.dat'
         printf,4,'All GCM grid longitudes contained in region'
         for i=0,n_elements(all_lons)-1 do printf,4,all_lons(i),fo='(f12.3)'
         close,4

         openw,4,path+region_now+'/'+gcm+'/latitudes.dat'
         printf,4,'All GCM grid latitudes contained in region'
         for i=0,n_elements(all_lats)-1 do printf,4,all_lats(i),fo='(f12.3)'
         close,4

         ; ----------------------
         ; Time variables
         ; ----------------------

         len=end_year-start_year+1
         month=reform(rebin(indgen(12)+1,12,len),len*12)

         years=fltarr(len*12)
         for i=0,len-1 do years(i*12:(i+1)*12-1)=start_year+i

         ; ----------------------
         ; Detect time dimension
         ; ----------------------

         dims_temp=size(temp,/dimensions)
         dims_prec=size(prec,/dimensions)

         time_dim_temp=where(dims_temp eq max(dims_temp),n_time_temp)
         time_dim_prec=where(dims_prec eq max(dims_prec),n_time_prec)

         time_dim_temp=time_dim_temp(0)
         time_dim_prec=time_dim_prec(0)

         ; ----------------------
         ; Loop over glaciers
         ; ----------------------

         for g=0l,ng-1 do begin

            if g mod 1000 eq 0 then print,region_now+'; '+gcm+'/'+ssp+': done '+string(g*100./ng,fo='(f6.2)')+'%'

            a=min(abs(xy(0,g)-all_lons),indx)
            a=min(abs(xy(1,g)-all_lats),indy)

            gx=strcompress(string(all_lons(indx),fo='(f7.2)'),/remove_all)
            gy=strcompress(string(all_lats(indy),fo='(f7.2)'),/remove_all)

            fnout=path+region_now+'/'+gcm+'/'+ssp+'/clim_'+gx+'_'+gy+'.dat'

            if file_test(fnout) eq 0 or overwrite_all eq 'y' then begin

               openw,4,fnout

               printf,4,'Meteorological forcing for grid cell '+gx+'(lon)_'+gy+'(lat)'
               printf,4,gcm+'/'+ssp
               printf,4,'Year  Month  temp(deg)  prec(mm)'

               for h=0l,nmon-1 do begin

                  if time_dim_temp eq 0 then begin
                     tval=temp(h,indx,indy)
                  endif else begin
                     tval=temp(indx,indy,h)
                  endelse

                  if time_dim_prec eq 0 then begin
                     pval=prec(h,indx,indy)
                  endif else begin
                     pval=prec(indx,indy,h)
                  endelse

                  printf,4,fix(years(h)),month(h),tval,pval,fo='(i4,i6,f13.2,f11.3)'

               endfor

               close,4

            endif

         endfor

         next_ssp:

      endfor

   endfor

   next_region:

endfor

print,'end'

end