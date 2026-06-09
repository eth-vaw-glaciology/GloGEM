; *************************************************************
; read_climatepast_daily
;
; Read the daily reanalysis climate time series for the grid point
; nearest to the current glacier cluster.
;
; Constructs the file path from the reanalysis product name and
; regional identifiers, then performs a spiral nearest-neighbour
; search if the exact file is absent, expanding the search radius in
; 0.01-degree steps up to 1 degree. Reads temperature, precipitation,
; day-of-year, and lapse-rate columns from the data file and
; initialises the working climate arrays (temp, prec, cyear, cday)
; while removing sub-threshold daily precipitation amounts.
; *************************************************************

compile_opt idl2


fn = dir_clim + 'reanalysis/daily/' + reanalysis + '/' + dir_region + '/clim_' + gxs + '_' + gys + '.dat'
if FILE_TEST(fn) eq 1 then begin ;and check_reanalysis(fn) eq 1 then begin
    ; All good and we continue
endif else begin
    found = 0
    radius = 0
    while found eq 0 do begin
       for q = -radius, radius do begin
        for r = -radius, radius do begin
            ; Only coordinates on this radius
            if abs(q) eq radius or abs(r) eq radius then begin
               ; Bereken nieuwe coördinaten
               rmid = [mean(lon) + STRING(double(q) / 100, FORMAT='(F5.2)'), mean(lat) + STRING(double(r) / 100, FORMAT='(F5.2)')]
               gxg = STRTRIM(STRING(rmid[0], FORMAT='(F0.2)'), 2)
               gyg = STRTRIM(STRING(rmid[1], FORMAT='(F0.2)'), 2)
               fn = dir_clim + 'reanalysis/' + time_resolution + '/' + reanalysis + '/' + dir_region + '/clim_' + gxg + '_' + gyg + '.dat'
               if FILE_TEST(fn) eq 1 then begin ;and check_reanalysis(fn) eq 1 then begin
                  found = 1
                  break
               endif
            endif
         endfor
         if found eq 1 then break
      endfor
      if found eq 1 then break
      ; Increase search window
      radius = radius + 1
      ; Stop if search window gets 100 ... (1°)
      if radius eq 100 then begin
            print, 'No suitable reanalysis grid point found within 1° radius. Please check your input coordinates.'
            STOP
      endif
   endwhile
endelse

anz=file_lines(fn)-3 & da=dblarr(7,anz) & tt=strarr(3)
openr,1,fn & readf,1,tt & readf,1,da & close,1
tempre=da[4,*] & precre=da[5,*] & ryear=da[0,*] & rday=da[2,*] & rmon=da[1,*] & dtdz=da[6,*]/100.
a=strsplit(tt[1],':',/extract) & hclim=double(a[1])
prec_orig=precre  ; storing full precipitation array (with many wet days) for bias correction
cyear=ryear & cday=rday & temp=tempre & prec=precre

; removing low daily precipitation amounts
ii=where(prec lt p_thres,ci) & if ci gt 0 then prec[ii]=0
