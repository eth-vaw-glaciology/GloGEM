; Compilation of GCM temperature, precipitation
; Daily output, combining historical 1950-2014 and SSP 2015-2100

allregions='y'
region=['CentralEurope']
tran=[1950,2100]
overwrite_all='y'

path='/scratch_net/vierzack04_third/lvantrich/gmip4/'
path_in='/scratch_net/vierzack04_third/lvantrich/gmip4/files_daily/'
batch_gl='/scratch_net/iceberg_second/mhuss/global_thickness/rgi70/'
batch_data='/home/mhuss/projects/global_retreat/data/'
path_out='/itet-stor/lvantrich/glogem/climatedata/future/daily/gmip4/'

; ----------------------
; GCMs and SSPs
; ----------------------

gcms=['BCC-CSM2-MR'];,'ACCESS-ESM1-5','NorESM2-MM','MPI-ESM1-2-HR','IPSL-CM6A-LR','MIROC6','MRI-ESM2-0','CESM2-WACCM']
; case overshoot
;gcms=['CESM2-WACCM'];'IPSL-CM6A-LR','MIROC6','MRI-ESM2-0']

ssps=['ssp126'];,'ssp370','ssp585']

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
;for rg=0,n_elements(reg)-1 do begin

; test one region:
for rg=13,13 do begin

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

         ; ----------------------
         ; Input files
         ; ----------------------
         ; Expected filenames:
         ; GCM_tas_historical_19502014.nc
         ; GCM_pr_historical_19502014.nc
         ; GCM_tas_sspXXX_20152100.nc
         ; GCM_pr_sspXXX_20152100.nc

         fnt_past=path_in+'/'+gcm+'/'+gcm+'_tas_historical_19502014.nc'
         fnp_past=path_in+'/'+gcm+'/'+gcm+'_pr_historical_19502014.nc'

         fnt=path_in+'/'+gcm+'/'+gcm+'_tas_'+ssp+'_20152100.nc'
         fnp=path_in+'/'+gcm+'/'+gcm+'_pr_'+ssp+'_20152100.nc'

         if file_test(fnt_past) eq 0 then begin
            print, 'Missing historical temperature file: ', fnt_past
            goto, next_ssp
         endif

         if file_test(fnp_past) eq 0 then begin
            print, 'Missing historical precipitation file: ', fnp_past
            goto, next_ssp
         endif

         if file_test(fnt) eq 0 then begin
            print, 'Missing future temperature file: ', fnt
            goto, next_ssp
         endif

         if file_test(fnp) eq 0 then begin
            print, 'Missing future precipitation file: ', fnp
            goto, next_ssp
         endif

         ; ----------------------
         ; Read lat / lon / time / tas variable IDs from historical tas file
         ; ----------------------

         ncid=ncdf_open(fnt_past)
         info=ncdf_inquire(ncid)
         nv=info.nvars
         vv=strarr(nv)

         for i=0,nv-1 do begin
            r=ncdf_varinq(ncid,i)
            vv(i)=r.name
         endfor

         lala=where(vv eq 'lat',nlat)
         lolo=where(vv eq 'lon',nlon)
         tata=where(vv eq 'tas',ntas)
         titi=where(vv eq 'time',ntime)

         if nlat eq 0 or nlon eq 0 or ntas eq 0 or ntime eq 0 then begin
            print, 'Missing lat/lon/tas/time variable in: ', fnt_past
            ncdf_close,ncid
            goto, next_ssp
         endif

         ncdf_varget,ncid,lolo(0),all_lons
         ncdf_varget,ncid,lala(0),all_lats
         ncdf_varget,ncid,titi(0),timep
         ncdf_close,ncid

         all_lons0=all_lons
         all_lats0=all_lats

         ii180=where(all_lons gt 180,n180)
         if n180 gt 0 then all_lons(ii180)=all_lons(ii180)-360.

         ; ----------------------
         ; Select regional crop to save memory
         ; ----------------------

         ii=where(all_lats0 ge lat(0) and all_lats0 le lat(1),ci)
         jj=where(all_lons ge lon(0) and all_lons le lon(1),cj)

         kk=-1
         ck=0

         if lon(0) gt lon(1) then begin
            jj=where(all_lons le lon(1),cj)
            kk=where(all_lons ge lon(0),ck)
         endif

         if ci eq 0 then begin
            print, 'No latitude grid cells found for region: ', region_now
            goto, next_ssp
         endif

         if cj eq 0 and ck eq 0 then begin
            print, 'No longitude grid cells found for region: ', region_now
            goto, next_ssp
         endif

         ; create cropped longitude/latitude vectors used later for nearest grid cells

         all_lats_crop=all_lats(ii)

         if kk(0) eq -1 then begin
            all_lons_crop=all_lons(jj)
         endif else begin
            all_lons_crop=dblarr(ck+cj)
            all_lons_crop(0:ck-1)=all_lons(kk)
            all_lons_crop(ck:ck+cj-1)=all_lons(jj)
         endelse

         ; ----------------------
         ; Make output folders
         ; ----------------------

         dir1=path_out+region_now
         if file_test(dir1,/directory) eq 0 then file_mkdir,dir1

         dir2=dir1+'/'+gcm
         if file_test(dir2,/directory) eq 0 then file_mkdir,dir2

         dir3=dir2+'/'+ssp
         if file_test(dir3,/directory) eq 0 then file_mkdir,dir3

         spawn,'chmod a+rx "'+dir1+'"'
         spawn,'chmod a+rx "'+dir2+'"'
         spawn,'chmod a+rx "'+dir3+'"'

         ; ----------------------
         ; Read historical temperature, cropped
         ; ----------------------

         ncid=ncdf_open(fnt_past)
         ncdf_varget,ncid,titi(0),timep
         ndaysp=n_elements(timep)
         hh1=indgen(ndaysp)

         if kk(0) eq -1 then begin
            ncdf_varget,ncid,tata(0),tempp,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,ndaysp]
         endif else begin
            ncdf_varget,ncid,tata(0),tt1,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,ndaysp]
            ncdf_varget,ncid,tata(0),tt2,offset=[kk(0),ii(0),hh1(0)],count=[ck,ci,ndaysp]

            tempp=dblarr(ck+cj,ci,ndaysp)

            for h=0l,ndaysp-1 do begin
               for i=0,ci-1 do begin
                  tempp(0:ck-1,i,h)=tt2(*,i,h)
                  tempp(ck:ck+cj-1,i,h)=tt1(*,i,h)
               endfor
            endfor
         endelse

         ncdf_close,ncid

         tempp=double(tempp)-273.15d0

         ; ----------------------
         ; Read historical precipitation, cropped
         ; ----------------------

         ncid=ncdf_open(fnp_past)
         info=ncdf_inquire(ncid)
         nv=info.nvars
         vv=strarr(nv)

         for i=0,nv-1 do begin
            r=ncdf_varinq(ncid,i)
            vv(i)=r.name
         endfor

         prvar=where(vv eq 'pr',npr)

         if npr eq 0 then begin
            print, 'No pr variable found in: ', fnp_past
            ncdf_close,ncid
            goto, next_ssp
         endif

         if kk(0) eq -1 then begin
            ncdf_varget,ncid,prvar(0),precp,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,ndaysp]
         endif else begin
            ncdf_varget,ncid,prvar(0),tt1,offset=[jj(0),ii(0),hh1(0)],count=[cj,ci,ndaysp]
            ncdf_varget,ncid,prvar(0),tt2,offset=[kk(0),ii(0),hh1(0)],count=[ck,ci,ndaysp]

            precp=dblarr(ck+cj,ci,ndaysp)

            for h=0l,ndaysp-1 do begin
               for i=0,ci-1 do begin
                  precp(0:ck-1,i,h)=tt2(*,i,h)
                  precp(ck:ck+cj-1,i,h)=tt1(*,i,h)
               endfor
            endfor
         endelse

         ncdf_close,ncid

         precp=double(precp)*3600.0d0*24.0d0     ; kg m-2 s-1 -> mm/day

         ; ----------------------
         ; Read future temperature, cropped
         ; ----------------------

         ncid=ncdf_open(fnt)
         info=ncdf_inquire(ncid)
         nv=info.nvars
         vv=strarr(nv)

         for i=0,nv-1 do begin
            r=ncdf_varinq(ncid,i)
            vv(i)=r.name
         endfor

         tata=where(vv eq 'tas',ntas)
         titi=where(vv eq 'time',ntime)

         if ntas eq 0 or ntime eq 0 then begin
            print, 'Missing tas/time variable in: ', fnt
            ncdf_close,ncid
            goto, next_ssp
         endif

         ncdf_varget,ncid,titi(0),time
         ndays=n_elements(time)
         hh2=indgen(ndays)

         if kk(0) eq -1 then begin
            ncdf_varget,ncid,tata(0),temp,offset=[jj(0),ii(0),hh2(0)],count=[cj,ci,ndays]
         endif else begin
            ncdf_varget,ncid,tata(0),tt1,offset=[jj(0),ii(0),hh2(0)],count=[cj,ci,ndays]
            ncdf_varget,ncid,tata(0),tt2,offset=[kk(0),ii(0),hh2(0)],count=[ck,ci,ndays]

            temp=dblarr(ck+cj,ci,ndays)

            for h=0l,ndays-1 do begin
               for i=0,ci-1 do begin
                  temp(0:ck-1,i,h)=tt2(*,i,h)
                  temp(ck:ck+cj-1,i,h)=tt1(*,i,h)
               endfor
            endfor
         endelse

         ncdf_close,ncid

         temp=double(temp)-273.15d0

         ; ----------------------
         ; Read future precipitation, cropped
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

         if kk(0) eq -1 then begin
            ncdf_varget,ncid,prvar(0),prec,offset=[jj(0),ii(0),hh2(0)],count=[cj,ci,ndays]
         endif else begin
            ncdf_varget,ncid,prvar(0),tt1,offset=[jj(0),ii(0),hh2(0)],count=[cj,ci,ndays]
            ncdf_varget,ncid,prvar(0),tt2,offset=[kk(0),ii(0),hh2(0)],count=[ck,ci,ndays]

            prec=dblarr(ck+cj,ci,ndays)

            for h=0l,ndays-1 do begin
               for i=0,ci-1 do begin
                  prec(0:ck-1,i,h)=tt2(*,i,h)
                  prec(ck:ck+cj-1,i,h)=tt1(*,i,h)
               endfor
            endfor
         endelse

         ncdf_close,ncid

         prec=double(prec)*3600.0d0*24.0d0       ; kg m-2 s-1 -> mm/day

         ; ----------------------
         ; Generate daily time variables
         ; Historical: 1950-2014
         ; Future:     2015-2100
         ; ----------------------

         ff_p=double(ndaysp)/(2015.0d0-1950.0d0)

         if ff_p lt 365.1d0 and ff_p gt 364.5d0 then ff_p=365.0d0

         typ=double(indgen(ndaysp))/ff_p+1950.0d0
         yp=fix(typ)
         r=typ-yp
         mop=round(r*12.0d0+0.5d0)
         dap=round(r*365.0d0+0.5d0)

         ii_bad=where(mop lt 1,n_bad)
         if n_bad gt 0 then mop(ii_bad)=1

         ii_bad=where(mop gt 12,n_bad)
         if n_bad gt 0 then mop(ii_bad)=12

         ii_bad=where(dap lt 1,n_bad)
         if n_bad gt 0 then dap(ii_bad)=1

         ff=double(ndays)/(2101.0d0-2015.0d0)

         if ff lt 365.1d0 and ff gt 364.5d0 then ff=365.0d0

         ty=double(indgen(ndays))/ff+2015.0d0
         y=fix(ty)
         r=ty-y
         mo=round(r*12.0d0+0.5d0)
         da=round(r*365.0d0+0.5d0)

         ii_bad=where(mo lt 1,n_bad)
         if n_bad gt 0 then mo(ii_bad)=1

         ii_bad=where(mo gt 12,n_bad)
         if n_bad gt 0 then mo(ii_bad)=12

         ii_bad=where(da lt 1,n_bad)
         if n_bad gt 0 then da(ii_bad)=1

         print, 'Year range:'
         print, 'Historical: ', min(typ), max(typ)
         print, 'Future:     ', min(ty), max(ty)

         ; ----------------------
         ; Loop over glaciers
         ; ----------------------

         for g=0l,ng-1 do begin

            if g mod 1000 eq 0 then print,region_now+'; '+gcm+'/'+ssp+': done '+string(g*100.0/ng,fo='(f6.2)')+'%'

            a=min(abs(xy(0,g)-all_lons_crop),indx)
            a=min(abs(xy(1,g)-all_lats_crop),indy)

            gx=strcompress(string(all_lons_crop(indx),fo='(f7.2)'),/remove_all)
            gy=strcompress(string(all_lats_crop(indy),fo='(f7.2)'),/remove_all)

            fnout=path_out+region_now+'/'+gcm+'/'+ssp+'/clim_'+gx+'_'+gy+'.dat'

            if file_test(fnout) eq 0 or overwrite_all eq 'y' then begin

               openw,4,fnout

               printf,4,'Future meteorological forcing for grid cell '+gx+'(lon)_'+gy+'(lat)'
               printf,4,gcm+'/'+ssp
               printf,4,'Year  Month  DOY  decimal.time  temp(degC)  prec(mm/day)'

               ; historical climate: 1950-2014
               for h=0l,ndaysp-1 do begin
                  printf,4,yp(h),mop(h),dap(h),typ(h),tempp(indx,indy,h),precp(indx,indy,h),fo='(i4,2i6,f13.4,2f11.3)'
               endfor

               ; future climate: 2015-2100
               for h=0l,ndays-1 do begin
                  printf,4,y(h),mo(h),da(h),ty(h),temp(indx,indy,h),prec(indx,indy,h),fo='(i4,2i6,f13.4,2f11.3)'
               endfor

               close,4
               spawn,'chmod a+rw "'+fnout+'"'

            endif

         endfor

         next_ssp:

      endfor

   endfor

   next_region:

endfor

print,'end'

end