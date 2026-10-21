; *************************************************************
; setup_firnice_orient
;
; Orientation factor of the thermal model's melt (firnice_orient = 'table').
; Reads firnice_orient_dir/orient_<glacier id>.dat:
;   lines starting with '#' are comments; data lines: band elevation [m a.s.l.] and the factor F
;   at air temperature anomalies dT = -3, -2, -1, 0, +1, +2, +3 K (8 numbers).
; Each line goes to the band whose inventory elevation elev0 lies within 5 m; bands without a line
; and glaciers without a file keep F = 1.
; Sets: forient[nb, 7] (F at forient_dt), forient_dt[7], and forient_tref[nb, 12], the band's mean
; air temperature of each calendar month 1981-2020 as the thermal melt sees it (no t_offset;
; the station lapse rate if firnice_thermal_lapse = 'stations'). firnice_thermal_forcing.pro
; reads F at this month's anomaly from forient_tref.
; *************************************************************

compile_opt idl2

forient_dt = dindgen(7) - 3d
forient = dblarr(nb, 7) + 1d

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
if file_test(fn_or) then begin
    openr, 77, fn_or
    line_or = '' & n_or = 0l
    while not eof(77) do begin
        readf, 77, line_or
        line_or = strtrim(line_or, 2)
        if strlen(line_or) eq 0 then continue
        if strmid(line_or, 0, 1) eq '#' then continue
        parts_or = double(strsplit(line_or, /extract))
        if n_elements(parts_or) ne 8 then message, 'firnice_orient: ' + fn_or + ': expected 8 numbers, got: ' + line_or
        dz_or = min(abs(elev0 - parts_or[0]), jb_or)
        if dz_or gt 5d then message, 'firnice_orient: ' + fn_or + ': no band within 5 m of ' + strtrim(parts_or[0], 2)
        if min(parts_or[1 : 7]) le 0d then message, 'firnice_orient: ' + fn_or + ': F must be positive: ' + line_or
        forient[jb_or, *] = parts_or[1 : 7]
        n_or++
    endwhile
    close, 77
    print, '  [orientation] ' + strtrim(n_or, 2) + ' bands from ' + fn_or + ', F(dT = 0) ' + $
        string(min(forient[*, 3]), fo='(f5.2)') + ' - ' + string(max(forient[*, 3]), fo='(f5.2)')
endif else print, '  [orientation] no table for ' + id[gg[g]] + ' in ' + firnice_orient_dir + ': F = 1'
