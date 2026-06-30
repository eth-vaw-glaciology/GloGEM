
; ============================================================
; Compilation of ERA5 daily temperature, precipitation,
; surface elevation and temperature gradients
; ============================================================

allregions = 'y'
region = ['CentralEurope']

tran = [1940,2025]
overwrite_all = 'y'
eval_tgrad = 'y'

reanalysis = 'ERA5'
short_r = 'era5_d'

; ----------------------
; Updated paths
; ----------------------

path = '/itet-stor/lvantrich/glogem/climatedata/reanalysis/daily/era5/'
path_in = '/itet-stor/lvantrich/glogem/climatedata/reanalysis/daily/era5/files/daily/'

batch_data = '/itet-stor/lvantrich/glogem/data/'
batch_gl = '/itet-stor/lvantrich/glogem/geometricdata/rgiv7/thickness/'

len = tran(1) - tran(0) + 1

; ---------------------
; Read region batch file
; ---------------------

fn = batch_data + 'region_batch.dat'
anz = file_lines(fn) - 1

tt = strarr(anz)
region_loop_data = strarr(5,anz)
s = strarr(1)

openr,1,fn
readf,1,s
readf,1,tt
close,1

for i = 0,anz-1 do begin
   a = strsplit(tt(i),' ',/extract)
   for j = 0,4 do region_loop_data(j,i) = a(j)
endfor

; ---------------------
; Read regions.dat
; ---------------------

fn = batch_data + 'regions.dat'
anz = file_lines(fn) - 1

s = strarr(1)
tt = strarr(anz)

openr,1,fn
readf,1,s
readf,1,tt
close,1

reg = strarr(anz)
subreg = strarr(anz)
rlons = dblarr(2,anz)
rlats = dblarr(2,anz)

for i = 0,anz-1 do begin
   a = strsplit(tt(i),' ',/extract)
   reg(i) = a(1)
   subreg(i) = a(2)
   rlons(0,i) = double(a(3))
   rlons(1,i) = double(a(4))
   rlats(0,i) = double(a(5))
   rlats(1,i) = double(a(6))
endfor

ii = where(rlons lt 0,ci)
if ci gt 0 then rlons(ii) = rlons(ii) + 360

if allregions eq 'y' then n_reg = anz else n_reg = 1

; ---------------------
; Read lat / lon / time variables from one file
; ---------------------

id = ncdf_open(path_in + 'temperature/ERA5_Daily_t2m_2025.nc')
ncdf_varget,id,0,time
ncdf_varget,id,1,all_lons
ncdf_varget,id,2,all_lats
ncdf_close,id

tyref = double(time) + 1940
ndays = n_elements(tyref)

all_lons0 = all_lons
ii = where(all_lons gt 180,cii)
if cii gt 0 then all_lons(ii) = all_lons(ii) - 360.

all_lons_full = all_lons
all_lats_full = all_lats

; ============================================================
; Loop over regions
; ============================================================

for rg = 0,n_reg-1 do begin

   all_lons = all_lons_full
   all_lats = all_lats_full

   ; ---------------------
   ; Surface elevation
   ; ---------------------

   id = ncdf_open(path_in + 'geo_era5.nc')
   ncdf_varget,id,5,elev
   ncdf_close,id

   elev = elev / 9.80665

   if allregions eq 'y' then begin
      region_now = reg(rg)
      sureg = subreg(rg)
   endif else begin
      region_now = region(0)
      hh = where(region_now eq reg,ch)
      if ch eq 0 then begin
         print,'ERROR: selected region not found: ',region_now
         stop
      endif
      sureg = subreg(hh(0))
   endelse

   print,'========================================='
   print,'REGION: ',region_now,'   SUBREGION: ',sureg
   print,'========================================='

   ; ---------------------
   ; Glacier position file
   ; ---------------------

   ii = where(region_now eq region_loop_data(2,*),ch)

   if ch eq 0 then begin
      print,'WARNING: no region batch entry for: ',region_now
      goto,next_region
   endif

   fn = batch_gl + 'files/thick_' + region_loop_data(4,ii(0)) + '.dat'

   if file_test(fn) eq 0 then begin
      print,'WARNING: thickness file missing: ',fn
      goto,next_region
   endif

   anz = file_lines(fn) - 1
   ng = anz

   s = strarr(anz)
   tt = strarr(1)

   openr,1,fn
   readf,1,tt
   readf,1,s
   close,1

   id_gl = strarr(anz)
   xy = dblarr(2,anz)

   for i = 0l,anz-1 do begin
      id_gl(i) = strmid(s(i),0,5)
      a = strsplit(s(i),' ',/extract)
      xy(0,i) = double(a(1))
      xy(1,i) = double(a(2))
   endfor

   if sureg ne 'n' then sreg = '_' + sureg else sreg = ''

   hh = where(region_now eq reg and sureg eq subreg,ch)

   if ch eq 0 then begin
      print,'WARNING: no lat/lon bounds found for: ',region_now
      goto,next_region
   endif

   lat = rlats(*,hh(0))
   lon = rlons(*,hh(0))

   print,lat,lon
   print,region_now
   print,'Read and crop all yearly .nc files...'

   ; ---------------------
   ; Crop region
   ; ---------------------

   ii = where(all_lats ge lat(0) and all_lats le lat(1),ci)
   jj = where(all_lons0 ge lon(0) and all_lons0 le lon(1),cj)

   hh_days = indgen(ndays)
   kk = -1

   if lon(0) gt lon(1) then begin
      jj = where(all_lons0 le lon(1),cj)
      kk = where(all_lons0 ge lon(0),ck)
   endif

   if kk(0) eq -1 then n = cj else n = cj + ck

   temp_all = dblarr(len,n,ci,365)
   prec_all = temp_all

   ; ---------------------
   ; Read yearly ERA5 files
   ; ---------------------

   for yr = 0,len-1 do begin

      yearnow = string(yr + tran(0),fo='(i4)')
      print,yearnow + '...'

      ; temperature
      id = ncdf_open(path_in + 'temperature/ERA5_Daily_t2m_' + yearnow + '.nc')

      if kk(0) eq -1 then begin
         ncdf_varget,id,3,temp,offset=[jj(0),ii(0),hh_days(0)],count=[cj,ci,ndays]
      endif else begin
         ncdf_varget,id,3,tt1,offset=[jj(0),ii(0),hh_days(0)],count=[cj,ci,ndays]
         ncdf_varget,id,3,tt2,offset=[kk(0),ii(0),hh_days(0)],count=[ck,ci,ndays]

         temp = dblarr(cj+ck,ci,ndays)

         for h = 0,ndays-1 do begin
            for i = 0,ci-1 do begin
               temp(0:ck-1,i,h) = tt2(*,i,h)
               temp(ck:ck+cj-1,i,h) = tt1(*,i,h)
            endfor
         endfor
      endelse

      ncdf_close,id

      temp_all(yr,*,*,*) = temp - 273.15

      ; precipitation
      id = ncdf_open(path_in + 'precipitation/ERA5_Daily_tp_' + yearnow + '.nc')

      if kk(0) eq -1 then begin
         ncdf_varget,id,3,prec,offset=[jj(0),ii(0),hh_days(0)],count=[cj,ci,ndays]
      endif else begin
         ncdf_varget,id,3,tt1,offset=[jj(0),ii(0),hh_days(0)],count=[cj,ci,ndays]
         ncdf_varget,id,3,tt2,offset=[kk(0),ii(0),hh_days(0)],count=[ck,ci,ndays]

         prec = dblarr(cj+ck,ci,ndays)

         for h = 0,ndays-1 do begin
            for i = 0,ci-1 do begin
               prec(0:ck-1,i,h) = tt2(*,i,h)
               prec(ck:ck+cj-1,i,h) = tt1(*,i,h)
            endfor
         endfor
      endelse

      ncdf_close,id

      prec_all(yr,*,*,*) = 1000. * prec

   endfor

   ; ---------------------
   ; Reduce lat/lon arrays
   ; ---------------------

   all_lats = all_lats(ii)

   if kk(0) eq -1 then begin
      all_lons = all_lons(jj)
   endif else begin
      tt = dblarr(ck+cj)
      tt(0:ck-1) = all_lons(kk)
      tt(ck:ck+cj-1) = all_lons(jj)
      all_lons = tt
   endelse

   ; ---------------------
   ; Make output folder
   ; ---------------------

   dir1 = path + region_now
   if file_test(dir1,/directory) eq 0 then file_mkdir,dir1

   spawn,'chmod a+rx "' + dir1 + '"'

   ; ---------------------
   ; Write lon/lat files
   ; ---------------------

   openw,5,path + region_now + '/longitudes.dat'
   printf,5,'All ERA5 grid longitudes contained in region'
   for i = 0,n_elements(all_lons)-1 do printf,5,all_lons(i),fo='(f12.3)'
   close,5

   openw,5,path + region_now + '/latitudes.dat'
   printf,5,'All ERA5 grid latitudes contained in region'
   for i = 0,n_elements(all_lats)-1 do printf,5,all_lats(i),fo='(f12.3)'
   close,5

   ; ============================================================
   ; Temperature gradients
   ; ============================================================

   if eval_tgrad eq 'y' then begin

      print,'Evaluate temperature gradients...'

      id = ncdf_open('/scratch_net/vierzack04_third/lvantrich/reanalysis/era5land/monthly/gradient/era5_monthly_temperature_levels_19952022.nc')

      ncdf_varget,id,0,time_grad
      ncdf_varget,id,1,lon_grad
      ncdf_varget,id,2,lat_grad
      ncdf_varget,id,3,levels

      nlev = n_elements(levels)

      ty_grad = double(time_grad)/365./24. + 1900.
      ttg = fix(ty_grad)
      r = ty_grad - ttg
      mo_grad = round(r*12 + 0.5)

      nt_grad = n_elements(ty_grad)
      ny_grad = fix(nt_grad/12.)

      hhg = indgen(nt_grad)
      ll = indgen(nlev)

      ii_grad = where(lat_grad ge lat(0) and lat_grad le lat(1),ci_grad)
      jj_grad = where(lon_grad ge lon(0) and lon_grad le lon(1),cj_grad)

      kk_grad = -1

      if lon(0) gt lon(1) then begin
         jj_grad = where(lon_grad le lon(1),cj_grad)
         kk_grad = where(lon_grad ge lon(0),ck_grad)
      endif

      if kk_grad(0) eq -1 then begin
         ncdf_varget,id,4,height,offset=[jj_grad(0),ii_grad(0),ll(0),hhg(0)],count=[cj_grad,ci_grad,nlev,nt_grad]
         ncdf_varget,id,5,tempelev,offset=[jj_grad(0),ii_grad(0),ll(0),hhg(0)],count=[cj_grad,ci_grad,nlev,nt_grad]
      endif else begin
         ncdf_varget,id,4,tt1,offset=[jj_grad(0),ii_grad(0),ll(0),hhg(0)],count=[cj_grad,ci_grad,nlev,nt_grad]
         ncdf_varget,id,4,tt2,offset=[kk_grad(0),ii_grad(0),ll(0),hhg(0)],count=[ck_grad,ci_grad,nlev,nt_grad]
         ncdf_varget,id,5,tt3,offset=[jj_grad(0),ii_grad(0),ll(0),hhg(0)],count=[cj_grad,ci_grad,nlev,nt_grad]
         ncdf_varget,id,5,tt4,offset=[kk_grad(0),ii_grad(0),ll(0),hhg(0)],count=[ck_grad,ci_grad,nlev,nt_grad]

         height = dblarr(cj_grad+ck_grad,ci_grad,nlev,nt_grad)
         tempelev = height

         for h = 0,nt_grad-1 do begin
            for j = 0,nlev-1 do begin
               for i = 0,ci_grad-1 do begin
                  height(0:ck_grad-1,i,j,h) = tt2(*,i,j,h)
                  height(ck_grad:ck_grad+cj_grad-1,i,j,h) = tt1(*,i,j,h)
                  tempelev(0:ck_grad-1,i,j,h) = tt4(*,i,j,h)
                  tempelev(ck_grad:ck_grad+cj_grad-1,i,j,h) = tt3(*,i,j,h)
               endfor
            endfor
         endfor
      endelse

      ncdf_close,id

      height = height / 9.80665
      tempelev = tempelev - 273.15

      lat_grad = lat_grad(ii_grad)

      ii_tmp = where(lon_grad gt 180,ci_tmp)
      if ci_tmp gt 0 then lon_grad(ii_tmp) = lon_grad(ii_tmp) - 360.

      if kk_grad(0) eq -1 then begin
         lon_grad = lon_grad(jj_grad)
      endif else begin
         tt = dblarr(ck_grad+cj_grad)
         tt(0:ck_grad-1) = lon_grad(kk_grad)
         tt(ck_grad:ck_grad+cj_grad-1) = lon_grad(jj_grad)
         lon_grad = tt
      endelse

      nlev = nlev - 1

      gradient = dblarr(n_elements(lon_grad),n_elements(lat_grad),ny_grad,12)

      for h = 0,n_elements(lon_grad)-1 do begin
         for k = 0,n_elements(lat_grad)-1 do begin
            c = 0l
            for i = 0,ny_grad-1 do begin
               for m = 0,11 do begin
                  x = dblarr(1,nlev)
                  y = dblarr(nlev)

                  for l = 1,nlev do x(0,l-1) = height(h,k,l,c)
                  for l = 1,nlev do y(l-1) = tempelev(h,k,l,c)

                  dtdz = regress(x,y,corr=rr)

                  if rr^2 lt 0.4 then dtdz = -0.006

                  gradient(h,k,i,m) = dtdz
                  c = c + 1
               endfor
            endfor
         endfor
      endfor

      mgradient = dblarr(n_elements(lon_grad),n_elements(lat_grad),12)

      for h = 0,n_elements(lon_grad)-1 do begin
         for k = 0,n_elements(lat_grad)-1 do begin
            for m = 0,11 do begin
               mgradient(h,k,m) = mean(gradient(h,k,*,m))
            endfor
         endfor
      endfor

   endif

   ; ============================================================
   ; Loop over glaciers
   ; ============================================================

   for g = 0l,ng-1 do begin

      if g mod 10 eq 0 then print,region_now + ': done ' + string(g*100./ng,fo='(f6.2)') + '%'

      a = min(abs(xy(0,g)-all_lons),indx)
      a = min(abs(xy(1,g)-all_lats),indy)

      a = min(abs(xy(0,g)-all_lons_full),indx_full)
      a = min(abs(xy(1,g)-all_lats_full),indy_full)

      gx = strcompress(string(all_lons(indx),fo='(f7.2)'),/remove_all)
      gy = strcompress(string(all_lats(indy),fo='(f7.2)'),/remove_all)

      fnout = path + region_now + '/clim_' + gx + '_' + gy + '.dat'

      nx = n_elements(all_lons)
      ny = n_elements(all_lats)

      if file_test(fnout) eq 0 or overwrite_all eq 'y' then begin

         cxind = 0
         cyind = 0

         if min(temp_all(0,indx,indy,*)) lt -100 then begin

            for o = 1,20 do begin
               for x = -o,o do begin
                  for y = -o,o do begin

                     if indx+x ge 0 and indx+x lt nx and indy+y ge 0 and indy+y lt ny then begin
                        a = min(temp_all(0,indx+x,indy+y,*))
                        cxind = x
                        cyind = y

                        if a gt -100 then goto,found_cell
                     endif

                  endfor
               endfor
            endfor

            found_cell:

         endif

         if indx_full+cxind lt n_elements(all_lons0) and indx_full+cxind ge 0 and $
            indy_full+cyind lt n_elements(all_lats_full) and indy_full+cyind ge 0 then begin
            elevnow = elev(indx_full+cxind,indy_full+cyind)
         endif else begin
            elevnow = -9
         endelse

         elevnow = elev(indx_full,indy_full)

         openw,4,fnout

         printf,4,'Meteorological data for ERA5 grid cell ' + gx + '(lon)_' + gy + '(lat)'
         printf,4,'Grid cell elevation (masl): ' + string(elevnow,fo='(f6.1)')
         printf,4,'Year  Month  DOY  decimal.time  temp(degC)  prec(mm)  dT/dz(deg/100m)'

         for yr = 0,len-1 do begin

            yearnow = string(yr + tran(0),fo='(i4)')

            tempnow = temp_all(yr,indx,indy,*)
            precnow = prec_all(yr,indx,indy,*)

            id = ncdf_open(path_in + 'temperature/ERA5_Daily_t2m_' + yearnow + '.nc')
            ncdf_varget,id,0,time
            ncdf_close,id

            ty = double(time)/365. + 1940.
            ty(n_elements(ty)-1) = ty(n_elements(ty)-1) - 0.05

            corr = ty(0) - (yr + tran(0))
            ty = ty - corr

            ya = fix(ty)
            r = ty - ya
            moa = round(r*12 + 0.5)
            daa = indgen(ndays) + 1

            if eval_tgrad eq 'y' then begin
               a = min(abs(xy(0,g)-lon_grad),indxgrad)
               a = min(abs(xy(1,g)-lat_grad),indygrad)

               dtdz_day = dblarr(ndays)

               for h = 0,ndays-1 do begin
                  dtdz_day(h) = mgradient(indxgrad,indygrad,moa(h)-1)
               endfor
            endif else begin
               dtdz_day = dblarr(ndays)
               dtdz_day(*) = -0.006
            endelse

            for h = 0,ndays-1 do begin
               printf,4,ya(h),moa(h),daa(h),ty(h),tempnow(h),precnow(h),dtdz_day(h)*100.,fo='(i4,2i6,f13.4,2f11.3,f11.5)'
            endfor

         endfor

         close,4

      endif

   endfor

   next_region:

endfor

print,'end'

end

