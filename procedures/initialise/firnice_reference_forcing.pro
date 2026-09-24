; *************************************************************
; firnice_reference_forcing
;
; Mean monthly climate of the thermal spin-up's reference period
; (firnice_spinup_ref_period, hydrological years, e.g. Oct 1960 - Sep 1990),
; from the full reanalysis series at the glacier's climate cell.
; The main run only loads tran[0]-1..tran[1] into temp/prec, so the full
; series is taken from rtemp/rprec (or tempre/precre on the 'new' path).
;
; Sets: tclim_sp[12] [°C], pclim_sp[12] [mm/month], at the climate cell.
; *************************************************************

compile_opt idl2

if time_resolution ne 'monthly' then $
    message, 'thermal spin-up: only monthly runs are supported'

if new eq 'y' then begin
    ts_sp = double(tempre) & ps_sp = double(precre)
endif else begin
    ts_sp = reform(rtemp[*, clim_ilon, clim_ilat])
    ps_sp = reform(rprec[*, clim_ilon, clim_ilat])
endelse

sp_y0 = long(firnice_spinup_ref_period[0])
sp_y1 = long(firnice_spinup_ref_period[1])
; months from bal_month on belong to the next hydrological year
hyd_sp = long(ryear) + (long(rmon) ge bal_month)

tclim_sp = dblarr(12) & pclim_sp = dblarr(12)
for ms = 1, 12 do begin
    jm = where(hyd_sp ge sp_y0 and hyd_sp le sp_y1 and rmon eq ms, cm)
    if cm lt 20 then message, 'thermal spin-up: only ' + strtrim(cm,2) + ' years of month ' + $
        strtrim(ms,2) + ' in ' + strtrim(sp_y0,2) + '-' + strtrim(sp_y1,2) + ' (need >= 20)'
    tclim_sp[ms-1] = mean(ts_sp[jm])
    pclim_sp[ms-1] = mean(ps_sp[jm])
endfor

if sp_y1 ne tran[0]-1l then $
    print, '  [thermal spinup] note: reference period ends Sep ' + strtrim(sp_y1,2) + $
           ', main run starts month ' + strtrim(bal_month,2) + ' of ' + strtrim(tran[0]-1l,2)
