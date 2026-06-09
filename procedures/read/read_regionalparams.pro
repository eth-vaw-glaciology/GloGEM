; *************************************************************
; read_regionalparams
;
; Read region-specific model parameters from the calibrated regional
; parameter file and assign them to the active model run.
;
; Parses the regional_parameters file for the active reanalysis
; product and time resolution, extracts calving coefficient,
; precipitation correction factor and tolerance bounds, lapse rate,
; temperature offset, and precipitation threshold for the matching
; region and sub-region. Handles both single-subregion and multi-
; subregion lookups and optionally updates the glacier size range if
; size_range_overwrite is enabled.
; *************************************************************

compile_opt idl2

fn = dir + 'regional_parameters_' + reanalysis + '.dat'
if time_resolution eq 'monthly' and reanalysis ne 'era5' then begin
   b = 6
endif else begin
   b = 10
endelse
anz = file_lines(fn) - b
ss=strarr(b) & da=strarr(anz) & openr,1,fn & readf,1,ss & readf,1,da & close,1
tt=strarr(anz) & tt2=strarr(anz) & cc=dblarr(anz) & dptt=cc & tott=cc & cprtt=dblarr(3,anz) & toff_gr=tt2
p_threshold=cc & size_range_ovw=dblarr(2,anz)
for i=0l,anz-1 do begin
   a=strsplit(da[i],' ',/extract) & tt[i]=a[0]  & tt2[i]=a[1]
   cc[i]=double(a[2]) & for j=0,2 do cprtt[j,i]=double(a[3+j]) & dptt[i]=double(a[6]) & tott[i]=double(a[7]) & toff_gr[i]=a[8]
   if time_resolution eq 'daily' then begin
      p_threshold[i]=double(a[9]) & for j=0,1 do size_range_ovw[j,i]=double(a[10+j])
   endif
endfor
ii=where(dir_region eq tt,ci)
if ci eq 1 then begin
   c_calving=cc[ii[0]] &   c_prec=cprtt[0,ii[0]]
   c1_tolerance[0]=cprtt[1,ii[0]] & c1_tolerance[1]=cprtt[2,ii[0]] & dPdz=dptt[ii[0]]
   t_offset=tott[ii[0]] & toff_grid=toff_gr[ii[0]] & toff_grid0=toff_gr[ii[0]]
   if time_resolution eq 'daily' then begin
      p_thres=p_threshold[ii[0]]
      if size_range_overwrite eq 'y' then size_range=size_range_ovw[*,ii[0]]
   endif
endif else begin
   jj=where(clim_subregion eq tt2[ii])
   c_calving=cc[ii[jj[0]]] &   c_prec=cprtt[0,ii[jj[0]]]
   c1_tolerance[0]=cprtt[1,ii[jj[0]]] & c1_tolerance[1]=cprtt[2,ii[jj[0]]]
   dPdz=dptt[ii[jj[0]]]  & t_offset=tott[ii[jj[0]]] & toff_grid=toff_gr[ii[jj[0]]] & toff_grid0=toff_gr[ii[jj[0]]]
   if time_resolution eq 'daily' then begin
      p_thres=p_threshold[ii[jj[0]]]
      if size_range_overwrite eq 'y' then size_range=size_range_ovw[*,ii[jj[0]]]
   endif
endelse
