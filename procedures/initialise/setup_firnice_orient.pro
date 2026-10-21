; *************************************************************
; setup_firnice_orient
;
; Orientation factor of the thermal model's melt (firnice_orient = 'table').
; Reads firnice_orient_dir/orient_<glacier id>.dat; every glacier of the run needs one:
;   lines starting with '#' are comments; one line 'dT' with the air temperature anomalies of the
;   table [K, increasing]; then data lines: band elevation [m a.s.l.] and F at each anomaly.
; Each data line goes to the glacierised band whose inventory elevation elev0 lies within 5 m;
; bands without a line keep F = 1 (a file with no data line: F = 1 everywhere).
; Sets: forient_dt[nd], forient[nb, nd] (F at forient_dt), and forient_tref[nb, 12], the band's mean
; air temperature of each calendar month 1981-2020 as the thermal melt sees it (no t_offset;
; the station lapse rate if firnice_thermal_lapse = 'stations'). firnice_thermal_forcing.pro
; reads F at this month's anomaly from forient_tref.
; *************************************************************

compile_opt idl2

; reference climate 1981-2020 at the climate cell, as firnice_reference_forcing.pro
if new eq 'y' then ts_or = double(tempre) else ts_or = reform(rtemp[*, clim_ilon, clim_ilat])
forient_tref = dblarr(nb, 12)
for ms_or = 1, 12 do begin
    jm_or = where(long(ryear) ge 1981 and long(ryear) le 2020 and long(rmon) eq ms_or, cm_or)
    if cm_or lt 30 then message, 'firnice_orient: only ' + strtrim(cm_or, 2) + ' years of month ' + strtrim(ms_or, 2) + $
        ' in 1981-2020 (need >= 30)'
    forient_tref[*, ms_or - 1] = mean(ts_or[jm_or]) + (elev - hclim) * dtdz[ms_or - 1]
    if firnice_thermal_lapse eq 'stations' then forient_tref[*, ms_or - 1] = forient_tref[*, ms_or - 1] + $
        (((elev - hclim) > 0d) < zth_cap) * (dtdz_icetemp[ms_or - 1] - dtdz[ms_or - 1])
endfor

fn_or = firnice_orient_dir + path_sep() + 'orient_' + id[gg[g]] + '.dat'
if not file_test(fn_or) then message, 'firnice_orient: no table ' + fn_or
openr, lun_or, fn_or, /get_lun
line_or = '' & n_or = 0l & elev_or = '' & have_dt_or = 0b
while not eof(lun_or) do begin
    readf, lun_or, line_or
    line_or = strtrim(line_or, 2)
    if strlen(line_or) eq 0 then continue
    if strmid(line_or, 0, 1) eq '#' then continue
    parts_or = strsplit(line_or, /extract)
    if parts_or[0] eq 'dT' then begin
        if have_dt_or then message, 'firnice_orient: ' + fn_or + ': two dT lines'
        forient_dt = double(parts_or[1 : *])
        if n_elements(forient_dt) lt 2 then message, 'firnice_orient: ' + fn_or + ': the dT line needs 2 values or more'
        if min(forient_dt[1 : *] - forient_dt[0 : -2]) le 0d then $
            message, 'firnice_orient: ' + fn_or + ': the dT values must increase'
        forient = dblarr(nb, n_elements(forient_dt)) + 1d & set_or = bytarr(nb)
        have_dt_or = 1b
        continue
    endif
    if not have_dt_or then message, 'firnice_orient: ' + fn_or + ': data before the dT line'
    parts_or = double(parts_or)
    if n_elements(parts_or) ne n_elements(forient_dt) + 1 then $
        message, 'firnice_orient: ' + fn_or + ': expected ' + strtrim(n_elements(forient_dt) + 1, 2) + $
        ' numbers, got: ' + line_or
    dz_or = min(abs(elev0 - parts_or[0]), jb_or)
    if dz_or gt 5d then message, 'firnice_orient: ' + fn_or + ': no band within 5 m of ' + strtrim(parts_or[0], 2)
    if gl[jb_or] eq noval then message, 'firnice_orient: ' + fn_or + ': band ' + strtrim(round(elev0[jb_or]), 2) + $
        ' is not glacierised'
    if set_or[jb_or] then message, 'firnice_orient: ' + fn_or + ': band ' + $
        strtrim(round(elev0[jb_or]), 2) + ' given twice'
    if min(parts_or[1 : *]) le 0d then message, 'firnice_orient: ' + fn_or + ': F must be positive: ' + line_or
    forient[jb_or, *] = parts_or[1 : *] & set_or[jb_or] = 1b
    elev_or = elev_or + ' ' + strtrim(round(elev0[jb_or]), 2)
    n_or++
endwhile
free_lun, lun_or
if not have_dt_or then message, 'firnice_orient: ' + fn_or + ': no dT line'
print, '  [orientation] ' + id[gg[g]] + ': ' + strtrim(n_or, 2) + ' bands with a factor' + $
    (n_or gt 0 ? ' at' + elev_or + ' m' : '') + ', dT ' + strtrim(string(forient_dt[0], fo='(f5.1)'), 2) + $
    ' to ' + strtrim(string(forient_dt[-1], fo='(f5.1)'), 2) + ' K'
