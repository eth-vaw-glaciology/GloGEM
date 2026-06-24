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
;   volumes[ye]   [km3]         x 900e9       -> kg  (ice density 900, matches
;                                                     GloGEM's internal dens=0.9)
;   vol_bz[ye]    [km3]         x 900e9       -> kg
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
;     ela, aar, discharge, area_cat (Table 5 optional vars),
;     area_ini, id, gg, g, snoval, time_resolution
;   From init procedure: nc_*, nc_vid_*, nc_reg_*, nc_has_split,
;     nc_years, nc_n_sub, nc_fv, nc_g,
;     nc_split_idx, nc_split_idx_sub (if nc_has_split)
; *************************************************************

compile_opt idl2

; ================================================================
; RGI ID STRING  (GlacierMIP4 format, e.g. RGI70-11.02596)
; ================================================================
nc_rgiid = 'RGI' + strtrim(RGIversion, 2) + '0-' + nc_rgi_str + '.' + strtrim(id[gg[g]], 2)

; ================================================================
; UNIT CONVERSIONS
; ================================================================

; Expand annual areas to sub-annual for variables using evolving area
; (monthly layout when running monthly OR when aggregating a daily run to monthly)
nc_area_sub = dblarr(nc_n_sub)
if time_resolution eq 'monthly' or nc_aggregate then begin
    for ye = 0, nc_years-1 do $
        nc_area_sub[ye*12:ye*12+11] = areas[ye]
endif else begin
    for ye = 0, nc_years-1 do $
        nc_area_sub[ye*365:ye*365+364] = areas[ye]
endelse

nc_ini_area = total(area_ini)   ; total initial area for this glacier [km2]

; Annual [m2] and [kg]
gl_area = float(areas   * 1e6)
; ice density 900 kg/m3 for volume->mass (matches GloGEM's internal dens=0.9)
gl_mass = float(volumes * 900d9)
gl_mbsl = float(vol_bz  * 900d9)
gl_fabl = float(flux_calv * areas * 1e9)   ; m w.e. x area -> kg (verify flux_calv units)

; Sub-annual [kg]
if time_resolution eq 'monthly' then begin
    gl_acc  = float(accmo        * nc_area_sub * 1e9)
    gl_melt = float(melmo        * nc_area_sub * 1e9)
    gl_refr = float(refrmo       * nc_area_sub * 1e9)
    gl_run  = float(discharge_gl * nc_area_sub * 1e9)
    gl_prec = float(precmo_ini   * 1e9)              ; [m w.e. x km2] -> kg
    gl_temp = tempmo_ini                             ; already in K
    gl_rbas = float(discharge    * area_cat * 1e9)   ; basin runoff over initial area -> kg
endif else if nc_aggregate then begin
    ; Daily run aggregated to monthly NetCDF: sum daily values within each
    ; calendar month; mean for temperature. Fixed month lengths (sum to 365);
    ; note mon_len is all-ones in a daily run, so a local array is used here.
    nc_mlen = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    melt_day = snowmeltday + icemeltday
    acc_m  = dblarr(nc_n_sub) & melt_m = acc_m & refr_m = acc_m
    run_m  = acc_m & prec_m = acc_m & rbas_m = acc_m & temp_m = acc_m
    for ye = 0L, nc_years-1L do begin
        m0 = 0L
        for mo = 0, 11 do begin
            i0 = ye*365L + m0
            i1 = i0 + nc_mlen[mo] - 1
            k  = ye*12 + mo
            acc_m[k]  = total(accday[i0:i1])
            melt_m[k] = total(melt_day[i0:i1])
            refr_m[k] = total(refrday[i0:i1])
            run_m[k]  = total(discharge_gl[i0:i1])
            prec_m[k] = total(precday_ini[i0:i1])
            rbas_m[k] = total(discharge[i0:i1])
            temp_m[k] = mean(tempday_ini[i0:i1])
            m0 = m0 + nc_mlen[mo]
        endfor
    endfor
    gl_acc  = float(acc_m  * nc_ini_area * 1e9)
    gl_melt = float(melt_m * nc_ini_area * 1e9)
    gl_refr = float(refr_m * nc_ini_area * 1e9)
    gl_run  = float(run_m  * nc_area_sub * 1e9)
    gl_prec = float(prec_m * 1e9)
    gl_temp = temp_m
    gl_rbas = float(rbas_m * area_cat * 1e9)
endif else begin
    ; acc/melt/refr: divided by total(area_ini) in store step
    gl_acc  = float(accday                        * nc_ini_area * 1e9)
    gl_melt = float((snowmeltday + icemeltday)     * nc_ini_area * 1e9)
    gl_refr = float(refrday                       * nc_ini_area * 1e9)
    gl_run  = float(discharge_gl                  * nc_area_sub * 1e9)
    gl_prec = float(precday_ini  * 1e9)
    gl_temp = tempday_ini
    gl_rbas = float(discharge    * area_cat * 1e9)   ; basin runoff over initial area -> kg
endelse

; GlacierMIP4 Table 5 optional individual-glacier annual variables
gl_ela  = float(ela)                          ; annual ELA [m a.s.l.]
gl_aar  = float(aar) / 100.                   ; annual AAR [fraction 0-1] (aar stored as percent)

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
ii = where(gl_ela  lt nc_sv, ci) & if ci gt 0 then gl_ela[ii]  = nc_fv
ii = where(gl_aar  lt nc_sv/100., ci) & if ci gt 0 then gl_aar[ii]  = nc_fv   ; threshold scaled (AAR now fraction)

; ================================================================
; WRITE INDIVIDUAL FILES (full period)
; ================================================================
ncdf_varput, nc_ann_i, nc_vid_i_rgid,  nc_rgiid,   offset=[nc_g]
ncdf_varput, nc_ann_i, nc_vid_i_area,  gl_area,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_mass,  gl_mass,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_mbsl,  gl_mbsl,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_fabl,  gl_fabl,    offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_ela,   gl_ela,     offset=[nc_g, 0], count=[1, nc_years]
ncdf_varput, nc_ann_i, nc_vid_i_aar,   gl_aar,     offset=[nc_g, 0], count=[1, nc_years]

ncdf_varput, nc_sub_i, nc_vid_i_rgid_s, nc_rgiid,  offset=[nc_g]
ncdf_varput, nc_sub_i, nc_vid_i_run,    gl_run,    offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_rbas,   gl_rbas,   offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_acc,    gl_acc,    offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_melt,   gl_melt,   offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_refr,   gl_refr,   offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_prec,   gl_prec,   offset=[nc_g, 0], count=[1, nc_n_sub]
ncdf_varput, nc_sub_i, nc_vid_i_temp,   gl_temp,   offset=[nc_g, 0], count=[1, nc_n_sub]

; ================================================================
; ACCUMULATE INTO REGIONAL SUMS (NaN-safe: only add valid values)
; ================================================================
; Annual (vectorised: add only positive, finite values per time step)
add = gl_area & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_area += add
add = gl_mass & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_mass += add
add = gl_mbsl & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_mbsl += add
add = gl_fabl & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_fabl += add

; Sub-annual (vectorised)
add = gl_acc  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_acc  += add
add = gl_melt & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_melt += add
add = gl_refr & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_refr += add
add = gl_run  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_run  += add
add = gl_prec & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_prec += add
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
gl_ela_p  = gl_ela[0:nc_split_idx-1]
gl_aar_p  = gl_aar[0:nc_split_idx-1]
gl_rbas_p = gl_rbas[0:nc_split_idx_sub-1]

ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_rgid,  nc_rgiid,  offset=[nc_g]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_area,  gl_area_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_mass,  gl_mass_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_mbsl,  gl_mbsl_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_fabl,  gl_fabl_p, offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_ela,   gl_ela_p,  offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_aar,   gl_aar_p,  offset=[nc_g, 0], count=[1, nc_years_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_rgid_s, nc_rgiid,  offset=[nc_g]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_run,    gl_run_p,  offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_rbas,   gl_rbas_p, offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_acc,    gl_acc_p,  offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_melt,   gl_melt_p, offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_refr,   gl_refr_p, offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_prec,   gl_prec_p, offset=[nc_g, 0], count=[1, nc_n_sub_past]
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_temp,   gl_temp_p, offset=[nc_g, 0], count=[1, nc_n_sub_past]

; Annual (vectorised)
add = gl_area_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_area += add
add = gl_mass_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_mass += add
add = gl_mbsl_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_mbsl += add
add = gl_fabl_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_fabl += add
; Sub-annual (vectorised)
add = gl_acc_p  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_acc  += add
add = gl_melt_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_melt += add
add = gl_refr_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_refr += add
add = gl_run_p  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_run  += add
add = gl_prec_p & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sp_prec += add
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
gl_ela_f  = gl_ela[nc_split_idx:*]
gl_aar_f  = gl_aar[nc_split_idx:*]
gl_rbas_f = gl_rbas[nc_split_idx_sub:*]

ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_rgid,  nc_rgiid,  offset=[nc_g]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_area,  gl_area_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_mass,  gl_mass_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_mbsl,  gl_mbsl_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_fabl,  gl_fabl_f, offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_ela,   gl_ela_f,  offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_aar,   gl_aar_f,  offset=[nc_g, 0], count=[1, nc_years_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_rgid_s, nc_rgiid,  offset=[nc_g]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_run,    gl_run_f,  offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_rbas,   gl_rbas_f, offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_acc,    gl_acc_f,  offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_melt,   gl_melt_f, offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_refr,   gl_refr_f, offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_prec,   gl_prec_f, offset=[nc_g, 0], count=[1, nc_n_sub_fut]
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_temp,   gl_temp_f, offset=[nc_g, 0], count=[1, nc_n_sub_fut]

; Annual (vectorised)
add = gl_area_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_area += add
add = gl_mass_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_mass += add
add = gl_mbsl_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_mbsl += add
add = gl_fabl_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_fabl += add
; Sub-annual (vectorised)
add = gl_acc_f  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_acc  += add
add = gl_melt_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_melt += add
add = gl_refr_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_refr += add
add = gl_run_f  & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_run  += add
add = gl_prec_f & jj = where(~finite(add) or add le 0, cj) & if cj gt 0 then add[jj] = 0 & nc_reg_sf_prec += add
if nc_ini_area gt 0 then begin
    ii = where(gl_temp_f gt nc_sv, ci)
    if ci gt 0 then begin
        nc_reg_sf_temp_w[ii] += gl_temp_f[ii] * nc_ini_area
        nc_reg_sf_temp_a[ii] += nc_ini_area
    endif
endif

write_glacier_done:
nc_g++
