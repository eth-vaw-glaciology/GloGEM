; *************************************************************
; write_netcdf_glacier
;
; Write one glacier's output to the open GlacierMIP4-compliant
; NetCDF files and accumulate its contribution into the regional
; sum arrays. Called once per glacier, after the glacier's year
; loop has completed. Works for both hindcast and projection
; contexts (same variable names set by the init procedures).
;
; Unit conversions applied here:
;   areas[ye]     [km2]         x 1e6         -> m2
;   volumes[ye]   [km3]         x 917e9       -> kg  (rho_ice=917)
;   vol_bz[ye]    [km3]         x 917e9       -> kg
;   flux_calv[ye] [m w.e.]      x areas[ye]   x 1e9 -> kg
;   Monthly acc/melt/refr/run   x areas[ye]   x 1e9 -> kg
;     (variables divided by evolving ar_gl; areas[ye] used as proxy)
;   Daily acc/melt/refr         x area_ini    x 1e9 -> kg
;     (variables divided by total(area_ini))
;   Daily discharge_gl          x areas[ye]   x 1e9 -> kg
;     (variable divided by evolving ar_gl)
;   precmo_ini / precday_ini  [m w.e. x km2]  x 1e9 -> kg
;   tempmo_ini / tempday_ini  already in K
;
; Expected variables in scope:
;   From the glacier loop: areas, volumes, vol_bz, flux_calv,
;     accmo/accday, melmo/snowmeltday/icemeltday,
;     refrmo/refrday, discharge_gl,
;     tempmo_ini/tempday_ini, precmo_ini/precday_ini,
;     area_ini, id, gg, g, snoval, time_resolution
;   From init procedure: nc_*, nc_vid_*, nc_reg_*, nc_has_split,
;     nc_years, nc_n_sub, nc_fv, nc_g,
;     nc_split_idx, nc_split_idx_sub (if nc_has_split)
; *************************************************************

compile_opt idl2

; ================================================================
; UNIT CONVERSIONS
; ================================================================

; Expand annual areas to sub-annual for variables using evolving area
nc_area_sub = dblarr(nc_n_sub)
if time_resolution eq 'monthly' then begin
    for ye = 0, nc_years-1 do $
        nc_area_sub[ye*12:ye*12+11] = areas[ye]
endif else begin
    for ye = 0, nc_years-1 do $
        nc_area_sub[ye*365:ye*365+364] = areas[ye]
endelse

nc_ini_area = total(area_ini)   ; total initial area for this glacier [km2]

; Annual [m2] and [kg]
gl_area = float(areas   * 1e6)
gl_mass = float(volumes * 917d9)
gl_mbsl = float(vol_bz  * 917d9)
gl_fabl = float(flux_calv * areas * 1e9)   ; m w.e. x area -> kg (verify flux_calv units)

; Sub-annual [kg]
if time_resolution eq 'monthly' then begin
    gl_acc  = float(accmo        * nc_area_sub * 1e9)
    gl_melt = float(melmo        * nc_area_sub * 1e9)
    gl_refr = float(refrmo       * nc_area_sub * 1e9)
    gl_run  = float(discharge_gl * nc_area_sub * 1e9)
    gl_prec = float(precmo_ini   * 1e9)              ; [m w.e. x km2] -> kg
    gl_temp = tempmo_ini                             ; already in K
endif else begin
    ; acc/melt/refr: divided by total(area_ini) in store step
    gl_acc  = float(accday                        * nc_ini_area * 1e9)
    gl_melt = float((snowmeltday + icemeltday)     * nc_ini_area * 1e9)
    gl_refr = float(refrday                       * nc_ini_area * 1e9)
    gl_run  = float(discharge_gl                  * nc_area_sub * 1e9)
    gl_prec = float(precday_ini  * 1e9)
    gl_temp = tempday_ini
endelse

; Replace snoval with NaN
nc_sv = snoval + 1.
ii = where(gl_area lt nc_sv, ci) & if ci gt 0 then gl_area[ii] = nc_fv
ii = where(gl_mass lt nc_sv, ci) & if ci gt 0 then gl_mass[ii] = nc_fv
ii = where(gl_mbsl lt nc_sv, ci) & if ci gt 0 then gl_mbsl[ii] = nc_fv
ii = where(gl_fabl lt nc_sv, ci) & if ci gt 0 then gl_fabl[ii] = nc_fv
ii = where(gl_acc  lt nc_sv, ci) & if ci gt 0 then gl_acc[ii]  = nc_fv
ii = where(gl_melt lt nc_sv, ci) & if ci gt 0 then gl_melt[ii] = nc_fv
ii = where(gl_refr lt nc_sv, ci) & if ci gt 0 then gl_refr[ii] = nc_fv
ii = where(gl_run  lt nc_sv, ci) & if ci gt 0 then gl_run[ii]  = nc_fv
ii = where(gl_prec lt nc_sv, ci) & if ci gt 0 then gl_prec[ii] = nc_fv
ii = where(gl_temp lt nc_sv, ci) & if ci gt 0 then gl_temp[ii] = nc_fv

; ================================================================
; WRITE INDIVIDUAL FILES (full period)
; ================================================================
ncdf_varput, nc_ann_i, nc_vid_i_rgid,  id[gg[g]],  offset=[nc_g]
ncdf_varput, nc_ann_i, nc_vid_i_area,  gl_area,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_mass,  gl_mass,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_mbsl,  gl_mbsl,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_fabl,  gl_fabl,    offset=[nc_g, 0], count=[1, nc_years]

ncdf_varput, nc_sub_i, nc_vid_i_rgid_s, id[gg[g]], offset=[nc_g]
ncdf_varput, nc_sub_i, nc_vid_i_run,    gl_run,    offset=[nc_g, 0], count=[1, nc_n_sub]

; ================================================================
; ACCUMULATE INTO REGIONAL SUMS (NaN-safe: only add valid values)
; ================================================================
; Annual
for ye = 0, nc_years-1 do begin
    if gl_area[ye] gt 0 then nc_reg_area[ye] += gl_area[ye]
    if gl_mass[ye] gt 0 then nc_reg_mass[ye] += gl_mass[ye]
    if gl_mbsl[ye] gt 0 then nc_reg_mbsl[ye] += gl_mbsl[ye]
    if gl_fabl[ye] gt 0 then nc_reg_fabl[ye] += gl_fabl[ye]
endfor

; Sub-annual
for ts = 0L, nc_n_sub-1L do begin
    if gl_acc[ts]  gt 0 then nc_reg_acc[ts]  += gl_acc[ts]
    if gl_melt[ts] gt 0 then nc_reg_melt[ts] += gl_melt[ts]
    if gl_refr[ts] gt 0 then nc_reg_refr[ts] += gl_refr[ts]
    if gl_run[ts]  gt 0 then nc_reg_run[ts]  += gl_run[ts]
    if gl_prec[ts] gt 0 then nc_reg_prec[ts] += gl_prec[ts]
endfor
; Temperature: area-weighted accumulation (skip snoval entries)
if nc_ini_area gt 0 then begin
    ii = where(gl_temp gt nc_sv, ci)
    if ci gt 0 then begin
        nc_reg_temp_w[ii] += gl_temp[ii] * nc_ini_area
        nc_reg_temp_a[ii] += nc_ini_area
    endif
endif

if ~nc_has_split then goto, write_glacier_done

; ================================================================
; SPLIT FILES — past and future portions
; ================================================================

; --- past portion (index 0 to nc_split_idx-1) ---
gl_area_p = gl_area[0:nc_split_idx-1]
gl_mass_p = gl_mass[0:nc_split_idx-1]
gl_mbsl_p = gl_mbsl[0:nc_split_idx-1]
gl_fabl_p = gl_fabl[0:nc_split_idx-1]
gl_acc_p  = gl_acc[0:nc_split_idx_sub-1]
gl_melt_p = gl_melt[0:nc_split_idx_sub-1]
gl_refr_p = gl_refr[0:nc_split_idx_sub-1]
gl_run_p  = gl_run[0:nc_split_idx_sub-1]
gl_prec_p = gl_prec[0:nc_split_idx_sub-1]
gl_temp_p = gl_temp[0:nc_split_idx_sub-1]

ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_rgid,  id[gg[g]], offset=[nc_g]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_area,  gl_area_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_mass,  gl_mass_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_mbsl,  gl_mbsl_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_fabl,  gl_fabl_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_rgid_s, id[gg[g]], offset=[nc_g]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_run,    gl_run_p,  offset=[nc_g, 0], count=[1, nc_n_sub_past]

for ye = 0, nc_years_past-1 do begin
    if gl_area_p[ye] gt 0 then nc_reg_sp_area[ye] += gl_area_p[ye]
    if gl_mass_p[ye] gt 0 then nc_reg_sp_mass[ye] += gl_mass_p[ye]
    if gl_mbsl_p[ye] gt 0 then nc_reg_sp_mbsl[ye] += gl_mbsl_p[ye]
    if gl_fabl_p[ye] gt 0 then nc_reg_sp_fabl[ye] += gl_fabl_p[ye]
endfor
for ts = 0L, nc_n_sub_past-1L do begin
    if gl_acc_p[ts]  gt 0 then nc_reg_sp_acc[ts]  += gl_acc_p[ts]
    if gl_melt_p[ts] gt 0 then nc_reg_sp_melt[ts] += gl_melt_p[ts]
    if gl_refr_p[ts] gt 0 then nc_reg_sp_refr[ts] += gl_refr_p[ts]
    if gl_run_p[ts]  gt 0 then nc_reg_sp_run[ts]  += gl_run_p[ts]
    if gl_prec_p[ts] gt 0 then nc_reg_sp_prec[ts] += gl_prec_p[ts]
endfor
if nc_ini_area gt 0 then begin
    ii = where(gl_temp_p gt nc_sv, ci)
    if ci gt 0 then begin
        nc_reg_sp_temp_w[ii] += gl_temp_p[ii] * nc_ini_area
        nc_reg_sp_temp_a[ii] += nc_ini_area
    endif
endif

; --- future portion (index nc_split_idx to nc_years-1) ---
gl_area_f = gl_area[nc_split_idx:*]
gl_mass_f = gl_mass[nc_split_idx:*]
gl_mbsl_f = gl_mbsl[nc_split_idx:*]
gl_fabl_f = gl_fabl[nc_split_idx:*]
gl_acc_f  = gl_acc[nc_split_idx_sub:*]
gl_melt_f = gl_melt[nc_split_idx_sub:*]
gl_refr_f = gl_refr[nc_split_idx_sub:*]
gl_run_f  = gl_run[nc_split_idx_sub:*]
gl_prec_f = gl_prec[nc_split_idx_sub:*]
gl_temp_f = gl_temp[nc_split_idx_sub:*]

ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_rgid,  id[gg[g]], offset=[nc_g]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_area,  gl_area_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_mass,  gl_mass_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_mbsl,  gl_mbsl_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_fabl,  gl_fabl_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_rgid_s, id[gg[g]], offset=[nc_g]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_run,    gl_run_f,  offset=[nc_g, 0], count=[1, nc_n_sub_fut]

for ye = 0, nc_years_fut-1 do begin
    if gl_area_f[ye] gt 0 then nc_reg_sf_area[ye] += gl_area_f[ye]
    if gl_mass_f[ye] gt 0 then nc_reg_sf_mass[ye] += gl_mass_f[ye]
    if gl_mbsl_f[ye] gt 0 then nc_reg_sf_mbsl[ye] += gl_mbsl_f[ye]
    if gl_fabl_f[ye] gt 0 then nc_reg_sf_fabl[ye] += gl_fabl_f[ye]
endfor
for ts = 0L, nc_n_sub_fut-1L do begin
    if gl_acc_f[ts]  gt 0 then nc_reg_sf_acc[ts]  += gl_acc_f[ts]
    if gl_melt_f[ts] gt 0 then nc_reg_sf_melt[ts] += gl_melt_f[ts]
    if gl_refr_f[ts] gt 0 then nc_reg_sf_refr[ts] += gl_refr_f[ts]
    if gl_run_f[ts]  gt 0 then nc_reg_sf_run[ts]  += gl_run_f[ts]
    if gl_prec_f[ts] gt 0 then nc_reg_sf_prec[ts] += gl_prec_f[ts]
endfor
if nc_ini_area gt 0 then begin
    ii = where(gl_temp_f gt nc_sv, ci)
    if ci gt 0 then begin
        nc_reg_sf_temp_w[ii] += gl_temp_f[ii] * nc_ini_area
        nc_reg_sf_temp_a[ii] += nc_ini_area
    endif
endif

write_glacier_done:
nc_g++
