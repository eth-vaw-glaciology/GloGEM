; *************************************************************
; init_netcdf_projections
;
; Initialise GlacierMIP4-compliant NetCDF output files for a
; projection run before the glacier loop begins. Creates files
; for the full period and, if netcdf_split eq 'y', also for the
; split past and future portions. See init_netcdf_hindcast.pro
; for the hindcast equivalent.
;
; Called once per region/GCM/SSP combination when
; write_netcdf eq 'y' and reanalysis_direct ne 'y'.
; Complementary procedures:
;   @write_netcdf_glacier.pro    - called after each glacier
;   @write_netcdf_projections.pro - called after the glacier loop
;
; Files created in files/files_netcdf/full/:
;   GloGEM_rgi[XX]_[GCM]_[SSP]_annual.nc
;   GloGEM_rgi[XX]_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;   GloGEM_rgi[XX]indiv_[GCM]_[SSP]_annual.nc
;   GloGEM_rgi[XX]indiv_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;
; If netcdf_split eq 'y', also creates in PAST/PAST_netcdf/:
;   GloGEM_rgi[XX]_[reanalysis]_annual.nc        (past portion)
;   GloGEM_rgi[XX]_[reanalysis]_monthly.nc
;   GloGEM_rgi[XX]indiv_[reanalysis]_annual.nc
;   GloGEM_rgi[XX]indiv_[reanalysis]_monthly.nc
;
; And in files/files_netcdf/split/:
;   GloGEM_rgi[XX]_[GCM]_[SSP]_annual.nc        (future portion)
;   GloGEM_rgi[XX]_[GCM]_[SSP]_monthly.nc
;   GloGEM_rgi[XX]indiv_[GCM]_[SSP]_annual.nc
;   GloGEM_rgi[XX]indiv_[GCM]_[SSP]_monthly.nc
;
; Variables set in scope after this procedure:
;   nc_ann, nc_sub, nc_ann_i, nc_sub_i  - full period file IDs
;   nc_sp_ann .. nc_sp_sub_i            - split past file IDs
;   nc_sf_ann .. nc_sf_sub_i            - split future file IDs
;   nc_vid_*, nc_vid_sp_*, nc_vid_sf_*  - variable IDs
;   nc_reg_*, nc_reg_sp_*, nc_reg_sf_*  - regional accumulators
;   nc_years, nc_n_sub, nc_tran         - full period dimensions
;   nc_years_past, nc_n_sub_past        - split past dimensions
;   nc_years_fut,  nc_n_sub_fut         - split future dimensions
;   nc_split_idx, nc_split_idx_sub      - split index in arrays
;   nc_has_split                        - 1 if split requested
;   nc_g                                - glacier counter
;
; Expected variables in scope (from glogem.pro):
;   dirres, dir_region, time_resolution
;   tran[2], years, cg
;   gmip4_region, catchment_selection, reanalysis
;   GCM_model[gcms], GCM_rcp[rcps], GCM_data
;   netcdf_split, netcdf_split_year
; *************************************************************

compile_opt idl2

; --- output paths ---
nc_base      = dirres + time_resolution + path_sep() + dir_region + path_sep()
nc_outdir    = nc_base + 'files' + path_sep() + 'files_netcdf' + path_sep() + 'full' + path_sep()
if ~file_test(nc_outdir, /directory) then file_mkdir, nc_outdir

; --- file name tags ---
nc_rgi_str = string(gmip4_region, format='(i02)')
if catchment_selection eq '' then begin
    nc_base_tag  = 'rgi' + nc_rgi_str
    nc_indiv_tag = 'rgi' + nc_rgi_str + 'indiv'
endif else begin
    nc_catch     = strtrim(catchment_selection, 2)
    nc_base_tag  = 'rgi' + nc_rgi_str + '_' + nc_catch
    nc_indiv_tag = 'rgi' + nc_rgi_str + '_' + nc_catch + 'indiv'
endelse
nc_rea     = strtrim(reanalysis, 2)
nc_gcm_tag = strtrim(GCM_model[gcms], 2) + '_' + strtrim(GCM_rcp[rcps], 2)

; --- full-period time setup ---
nc_years  = years
nc_tran   = tran
nc_fv     = !VALUES.F_NAN
nc_ref_jd = julday(1, 1, 1850)

if time_resolution eq 'monthly' then begin
    nc_n_sub   = nc_years * 12
    nc_sub_lbl = 'monthly'
    nc_time_sub = lonarr(nc_n_sub)
    idx = 0L
    for yr = 0L, nc_years-1L do $
        for mo = 1, 12 do begin
            nc_time_sub[idx] = long(julday(mo, 1, nc_tran[0]+yr) - nc_ref_jd)
            idx++
        endfor
endif else begin
    nc_n_sub   = nc_years * 365
    nc_sub_lbl = 'daily'
    nc_time_sub = lonarr(nc_n_sub)
    for yr = 0L, nc_years-1L do $
        for doy = 0, 364 do $
            nc_time_sub[yr*365+doy] = long(julday(1,1,nc_tran[0]+yr) - nc_ref_jd + doy)
endelse

nc_time_ann = lonarr(nc_years)
for yr = 0L, nc_years-1L do $
    nc_time_ann[yr] = long(julday(1, 1, nc_tran[0]+yr) - nc_ref_jd)

nc_period = strtrim(string(nc_tran[0]),2) + '-' + strtrim(string(nc_tran[1]),2)

; --- full period file names ---
nc_fn_ann   = nc_outdir + 'GloGEM_' + nc_base_tag  + '_' + nc_gcm_tag + '_annual.nc'
nc_fn_sub   = nc_outdir + 'GloGEM_' + nc_base_tag  + '_' + nc_gcm_tag + '_' + nc_sub_lbl + '.nc'
nc_fn_ann_i = nc_outdir + 'GloGEM_' + nc_indiv_tag + '_' + nc_gcm_tag + '_annual.nc'
nc_fn_sub_i = nc_outdir + 'GloGEM_' + nc_indiv_tag + '_' + nc_gcm_tag + '_' + nc_sub_lbl + '.nc'

; --- global attributes helper values ---
nc_institution = 'ETH, VAW'
nc_gcm_str = strtrim(GCM_model[gcms], 2)
nc_ssp_str = strtrim(GCM_rcp[rcps],   2)
nc_dat_str = strtrim(GCM_data,         2)

; ================================================================
; FULL PERIOD FILES (1–4)
; ================================================================

; 1. Regional annual
nc_ann = ncdf_create(nc_fn_ann, /clobber, /netcdf4)
ncdf_attput, nc_ann, /global, 'Conventions',   'CF-1.8'
ncdf_attput, nc_ann, /global, 'model',         'GloGEM'
ncdf_attput, nc_ann, /global, 'institution',   nc_institution
ncdf_attput, nc_ann, /global, 'rgi_region',    nc_rgi_str
ncdf_attput, nc_ann, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, nc_ann, /global, 'forcing',       nc_gcm_tag
ncdf_attput, nc_ann, /global, 'gcm',           nc_gcm_str
ncdf_attput, nc_ann, /global, 'scenario',      nc_ssp_str
ncdf_attput, nc_ann, /global, 'gcm_data',      nc_dat_str
ncdf_attput, nc_ann, /global, 'period',        nc_period
ncdf_attput, nc_ann, /global, 'creation_date', systime()
nc_dim_t  = ncdf_dimdef(nc_ann, 'time', nc_years)
nc_vid_t_ann  = ncdf_vardef(nc_ann, 'time', [nc_dim_t], /long)
ncdf_attput, nc_ann, nc_vid_t_ann, 'long_name', 'time'
ncdf_attput, nc_ann, nc_vid_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_ann, nc_vid_t_ann, 'calendar', 'standard'
ncdf_attput, nc_ann, nc_vid_t_ann, 'cell_methods', 'time: point'
nc_vid_area = ncdf_vardef(nc_ann, 'area',        [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_area, 'long_name', 'Glacier area'   & ncdf_attput, nc_ann, nc_vid_area, 'units', 'm2'
ncdf_attput, nc_ann, nc_vid_area, 'cell_methods', 'time: point' & ncdf_attput, nc_ann, nc_vid_area, '_FillValue', nc_fv
nc_vid_mass = ncdf_vardef(nc_ann, 'mass',        [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_mass, 'long_name', 'Glacier mass'   & ncdf_attput, nc_ann, nc_vid_mass, 'units', 'kg'
ncdf_attput, nc_ann, nc_vid_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_ann, nc_vid_mass, '_FillValue', nc_fv
nc_vid_mbsl = ncdf_vardef(nc_ann, 'mass_bsl',    [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_mbsl, 'long_name', 'Glacier mass below sea level'
ncdf_attput, nc_ann, nc_vid_mbsl, 'units', 'kg' & ncdf_attput, nc_ann, nc_vid_mbsl, 'cell_methods', 'time: point'
ncdf_attput, nc_ann, nc_vid_mbsl, '_FillValue', nc_fv
nc_vid_fabl = ncdf_vardef(nc_ann, 'frontal_abl', [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_fabl, 'long_name', 'Total annual frontal ablation'
ncdf_attput, nc_ann, nc_vid_fabl, 'units', 'kg' & ncdf_attput, nc_ann, nc_vid_fabl, 'cell_methods', 'time: sum'
ncdf_attput, nc_ann, nc_vid_fabl, '_FillValue', nc_fv
ncdf_control, nc_ann, /endef
ncdf_varput, nc_ann, nc_vid_t_ann, nc_time_ann

; 2. Regional sub-annual
nc_sub = ncdf_create(nc_fn_sub, /clobber, /netcdf4)
ncdf_attput, nc_sub, /global, 'Conventions',    'CF-1.8'
ncdf_attput, nc_sub, /global, 'model',          'GloGEM'
ncdf_attput, nc_sub, /global, 'institution',    nc_institution
ncdf_attput, nc_sub, /global, 'rgi_region',     nc_rgi_str
ncdf_attput, nc_sub, /global, 'catchment',      strtrim(catchment_selection, 2)
ncdf_attput, nc_sub, /global, 'forcing',        nc_gcm_tag
ncdf_attput, nc_sub, /global, 'gcm',            nc_gcm_str
ncdf_attput, nc_sub, /global, 'scenario',       nc_ssp_str
ncdf_attput, nc_sub, /global, 'gcm_data',       nc_dat_str
ncdf_attput, nc_sub, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sub, /global, 'period',         nc_period
ncdf_attput, nc_sub, /global, 'creation_date',  systime()
nc_dim_s  = ncdf_dimdef(nc_sub, 'time', nc_n_sub)
nc_vid_t_sub  = ncdf_vardef(nc_sub, 'time', [nc_dim_s], /long)
ncdf_attput, nc_sub, nc_vid_t_sub, 'long_name', 'time' & ncdf_attput, nc_sub, nc_vid_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sub, nc_vid_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sub, nc_vid_t_sub, 'cell_methods', 'time: point'
nc_vid_acc  = ncdf_vardef(nc_sub, 'acc',         [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_acc,  'long_name', 'Total accumulation'
ncdf_attput, nc_sub, nc_vid_acc,  'units', 'kg' & ncdf_attput, nc_sub, nc_vid_acc,  'cell_methods', 'time: sum' & ncdf_attput, nc_sub, nc_vid_acc,  '_FillValue', nc_fv
nc_vid_melt = ncdf_vardef(nc_sub, 'melt',        [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_melt, 'long_name', 'Total glacier melt (snow, ice, firn)'
ncdf_attput, nc_sub, nc_vid_melt, 'units', 'kg' & ncdf_attput, nc_sub, nc_vid_melt, 'cell_methods', 'time: sum' & ncdf_attput, nc_sub, nc_vid_melt, '_FillValue', nc_fv
nc_vid_refr = ncdf_vardef(nc_sub, 'refreeze',    [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_refr, 'long_name', 'Total refreezing'
ncdf_attput, nc_sub, nc_vid_refr, 'units', 'kg' & ncdf_attput, nc_sub, nc_vid_refr, 'cell_methods', 'time: sum' & ncdf_attput, nc_sub, nc_vid_refr, '_FillValue', nc_fv
nc_vid_run  = ncdf_vardef(nc_sub, 'runoff_glac', [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_run,  'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sub, nc_vid_run,  'units', 'kg' & ncdf_attput, nc_sub, nc_vid_run,  'cell_methods', 'time: sum' & ncdf_attput, nc_sub, nc_vid_run,  '_FillValue', nc_fv
nc_vid_prec = ncdf_vardef(nc_sub, 'precip',      [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_prec, 'long_name', 'Total precipitation over initial glacierized area'
ncdf_attput, nc_sub, nc_vid_prec, 'units', 'kg' & ncdf_attput, nc_sub, nc_vid_prec, 'cell_methods', 'time: sum' & ncdf_attput, nc_sub, nc_vid_prec, '_FillValue', nc_fv
nc_vid_temp = ncdf_vardef(nc_sub, 'temp',        [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_temp, 'long_name', 'Near-surface air temperature over initial glacierized area'
ncdf_attput, nc_sub, nc_vid_temp, 'units', 'K' & ncdf_attput, nc_sub, nc_vid_temp, 'cell_methods', 'time: mean' & ncdf_attput, nc_sub, nc_vid_temp, '_FillValue', nc_fv
ncdf_control, nc_sub, /endef
ncdf_varput, nc_sub, nc_vid_t_sub, nc_time_sub

; 3. Individual annual
nc_ann_i = ncdf_create(nc_fn_ann_i, /clobber, /netcdf4)
ncdf_attput, nc_ann_i, /global, 'Conventions',   'CF-1.8'  & ncdf_attput, nc_ann_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_ann_i, /global, 'institution',   nc_institution
ncdf_attput, nc_ann_i, /global, 'rgi_region',    nc_rgi_str & ncdf_attput, nc_ann_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_ann_i, /global, 'forcing',       nc_gcm_tag & ncdf_attput, nc_ann_i, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_ann_i, /global, 'scenario',      nc_ssp_str & ncdf_attput, nc_ann_i, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_ann_i, /global, 'period',        nc_period  & ncdf_attput, nc_ann_i, /global, 'creation_date', systime()
nc_dim_g   = ncdf_dimdef(nc_ann_i, 'glacier', cg)
nc_dim_t_i = ncdf_dimdef(nc_ann_i, 'time',    nc_years)
nc_vid_i_rgid  = ncdf_vardef(nc_ann_i, 'RGIId', [nc_dim_g], /string)
ncdf_attput, nc_ann_i, nc_vid_i_rgid, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_i_t_ann = ncdf_vardef(nc_ann_i, 'time', [nc_dim_t_i], /long)
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'long_name', 'time' & ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'calendar', 'standard' & ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'cell_methods', 'time: point'
nc_vid_i_area = ncdf_vardef(nc_ann_i, 'area',        [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_area, 'long_name', 'Glacier area' & ncdf_attput, nc_ann_i, nc_vid_i_area, 'units', 'm2'
ncdf_attput, nc_ann_i, nc_vid_i_area, 'cell_methods', 'time: point' & ncdf_attput, nc_ann_i, nc_vid_i_area, '_FillValue', nc_fv
nc_vid_i_mass = ncdf_vardef(nc_ann_i, 'mass',        [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_mass, 'long_name', 'Glacier mass' & ncdf_attput, nc_ann_i, nc_vid_i_mass, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_ann_i, nc_vid_i_mass, '_FillValue', nc_fv
nc_vid_i_mbsl = ncdf_vardef(nc_ann_i, 'mass_bsl',    [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'long_name', 'Glacier mass below sea level' & ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'cell_methods', 'time: point' & ncdf_attput, nc_ann_i, nc_vid_i_mbsl, '_FillValue', nc_fv
nc_vid_i_fabl = ncdf_vardef(nc_ann_i, 'frontal_abl', [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'long_name', 'Total annual frontal ablation' & ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'cell_methods', 'time: sum' & ncdf_attput, nc_ann_i, nc_vid_i_fabl, '_FillValue', nc_fv
ncdf_control, nc_ann_i, /endef
ncdf_varput, nc_ann_i, nc_vid_i_t_ann, nc_time_ann

; 4. Individual sub-annual
nc_sub_i = ncdf_create(nc_fn_sub_i, /clobber, /netcdf4)
ncdf_attput, nc_sub_i, /global, 'Conventions',    'CF-1.8'  & ncdf_attput, nc_sub_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_sub_i, /global, 'institution',    nc_institution
ncdf_attput, nc_sub_i, /global, 'rgi_region',     nc_rgi_str & ncdf_attput, nc_sub_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sub_i, /global, 'forcing',        nc_gcm_tag & ncdf_attput, nc_sub_i, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_sub_i, /global, 'scenario',       nc_ssp_str & ncdf_attput, nc_sub_i, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_sub_i, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sub_i, /global, 'period',         nc_period  & ncdf_attput, nc_sub_i, /global, 'creation_date', systime()
nc_dim_g_s = ncdf_dimdef(nc_sub_i, 'glacier', cg)
nc_dim_s_i = ncdf_dimdef(nc_sub_i, 'time',    nc_n_sub)
nc_vid_i_rgid_s = ncdf_vardef(nc_sub_i, 'RGIId', [nc_dim_g_s], /string)
ncdf_attput, nc_sub_i, nc_vid_i_rgid_s, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_i_t_sub = ncdf_vardef(nc_sub_i, 'time', [nc_dim_s_i], /long)
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'long_name', 'time' & ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'cell_methods', 'time: point'
nc_vid_i_run = ncdf_vardef(nc_sub_i, 'runoff_glac', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_run, 'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sub_i, nc_vid_i_run, 'units', 'kg' & ncdf_attput, nc_sub_i, nc_vid_i_run, 'cell_methods', 'time: sum' & ncdf_attput, nc_sub_i, nc_vid_i_run, '_FillValue', nc_fv
ncdf_control, nc_sub_i, /endef
ncdf_varput, nc_sub_i, nc_vid_i_t_sub, nc_time_sub

; ================================================================
; REGIONAL ACCUMULATORS — full period
; ================================================================
nc_reg_area   = fltarr(nc_years)
nc_reg_mass   = fltarr(nc_years)
nc_reg_mbsl   = fltarr(nc_years)
nc_reg_fabl   = fltarr(nc_years)
nc_reg_acc    = fltarr(nc_n_sub)
nc_reg_melt   = fltarr(nc_n_sub)
nc_reg_refr   = fltarr(nc_n_sub)
nc_reg_run    = fltarr(nc_n_sub)
nc_reg_prec   = fltarr(nc_n_sub)
nc_reg_temp_w = dblarr(nc_n_sub)
nc_reg_temp_a = dblarr(nc_n_sub)

nc_has_split = (netcdf_split eq 'y')
nc_g         = 0L

if ~nc_has_split then goto, init_proj_done

; ================================================================
; SPLIT FILES — past portion and future portion
; ================================================================
nc_split_idx     = netcdf_split_year - tran[0]
nc_years_past    = nc_split_idx
nc_years_fut     = nc_years - nc_split_idx
if time_resolution eq 'monthly' then begin
    nc_split_idx_sub = nc_split_idx * 12
    nc_n_sub_past    = nc_years_past * 12
    nc_n_sub_fut     = nc_years_fut  * 12
endif else begin
    nc_split_idx_sub = nc_split_idx * 365
    nc_n_sub_past    = nc_years_past * 365
    nc_n_sub_fut     = nc_years_fut  * 365
endelse

; --- split past time axes ---
nc_time_ann_past = lonarr(nc_years_past)
for yr = 0L, nc_years_past-1L do $
    nc_time_ann_past[yr] = long(julday(1, 1, tran[0]+yr) - nc_ref_jd)

nc_time_sub_past = lonarr(nc_n_sub_past)
if time_resolution eq 'monthly' then begin
    idx = 0L
    for yr = 0L, nc_years_past-1L do $
        for mo = 1, 12 do begin
            nc_time_sub_past[idx] = long(julday(mo, 1, tran[0]+yr) - nc_ref_jd)
            idx++
        endfor
endif else begin
    for yr = 0L, nc_years_past-1L do $
        for doy = 0, 364 do $
            nc_time_sub_past[yr*365+doy] = long(julday(1,1,tran[0]+yr) - nc_ref_jd + doy)
endelse

; --- split future time axes ---
nc_time_ann_fut = lonarr(nc_years_fut)
for yr = 0L, nc_years_fut-1L do $
    nc_time_ann_fut[yr] = long(julday(1, 1, netcdf_split_year+yr) - nc_ref_jd)

nc_time_sub_fut = lonarr(nc_n_sub_fut)
if time_resolution eq 'monthly' then begin
    idx = 0L
    for yr = 0L, nc_years_fut-1L do $
        for mo = 1, 12 do begin
            nc_time_sub_fut[idx] = long(julday(mo, 1, netcdf_split_year+yr) - nc_ref_jd)
            idx++
        endfor
endif else begin
    for yr = 0L, nc_years_fut-1L do $
        for doy = 0, 364 do $
            nc_time_sub_fut[yr*365+doy] = long(julday(1,1,netcdf_split_year+yr) - nc_ref_jd + doy)
endelse

nc_period_past = strtrim(string(tran[0]),2)             + '-' + strtrim(string(netcdf_split_year-1),2)
nc_period_fut  = strtrim(string(netcdf_split_year),2)   + '-' + strtrim(string(tran[1]),2)

; --- split output directories ---
nc_outdir_sp = nc_base + 'PAST' + path_sep() + 'PAST_netcdf' + path_sep()
nc_outdir_sf = nc_base + 'files' + path_sep() + 'files_netcdf' + path_sep() + 'split' + path_sep()
if ~file_test(nc_outdir_sp, /directory) then file_mkdir, nc_outdir_sp
if ~file_test(nc_outdir_sf, /directory) then file_mkdir, nc_outdir_sf

; --- split past file names (hindcast naming with reanalysis) ---
nc_sp_fn_ann   = nc_outdir_sp + 'GloGEM_' + nc_base_tag  + '_' + nc_rea + '_annual.nc'
nc_sp_fn_sub   = nc_outdir_sp + 'GloGEM_' + nc_base_tag  + '_' + nc_rea + '_' + nc_sub_lbl + '.nc'
nc_sp_fn_ann_i = nc_outdir_sp + 'GloGEM_' + nc_indiv_tag + '_' + nc_rea + '_annual.nc'
nc_sp_fn_sub_i = nc_outdir_sp + 'GloGEM_' + nc_indiv_tag + '_' + nc_rea + '_' + nc_sub_lbl + '.nc'

; --- split future file names (projection naming) ---
nc_sf_fn_ann   = nc_outdir_sf + 'GloGEM_' + nc_base_tag  + '_' + nc_gcm_tag + '_annual.nc'
nc_sf_fn_sub   = nc_outdir_sf + 'GloGEM_' + nc_base_tag  + '_' + nc_gcm_tag + '_' + nc_sub_lbl + '.nc'
nc_sf_fn_ann_i = nc_outdir_sf + 'GloGEM_' + nc_indiv_tag + '_' + nc_gcm_tag + '_annual.nc'
nc_sf_fn_sub_i = nc_outdir_sf + 'GloGEM_' + nc_indiv_tag + '_' + nc_gcm_tag + '_' + nc_sub_lbl + '.nc'

; --- create split past files (5–8) ---
nc_sp_ann = ncdf_create(nc_sp_fn_ann, /clobber, /netcdf4)
ncdf_attput, nc_sp_ann, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sp_ann, /global, 'model', 'GloGEM'
ncdf_attput, nc_sp_ann, /global, 'institution', nc_institution
ncdf_attput, nc_sp_ann, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sp_ann, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sp_ann, /global, 'forcing',     nc_rea     & ncdf_attput, nc_sp_ann, /global, 'period', nc_period_past
ncdf_attput, nc_sp_ann, /global, 'split',       'past_portion' & ncdf_attput, nc_sp_ann, /global, 'creation_date', systime()
nc_sp_dim_t   = ncdf_dimdef(nc_sp_ann, 'time', nc_years_past)
nc_vid_sp_t_ann = ncdf_vardef(nc_sp_ann, 'time', [nc_sp_dim_t], /long)
ncdf_attput, nc_sp_ann, nc_vid_sp_t_ann, 'long_name', 'time' & ncdf_attput, nc_sp_ann, nc_vid_sp_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sp_ann, nc_vid_sp_t_ann, 'calendar', 'standard' & ncdf_attput, nc_sp_ann, nc_vid_sp_t_ann, 'cell_methods', 'time: point'
nc_vid_sp_area = ncdf_vardef(nc_sp_ann, 'area',        [nc_sp_dim_t], /float)
ncdf_attput, nc_sp_ann, nc_vid_sp_area, 'long_name', 'Glacier area' & ncdf_attput, nc_sp_ann, nc_vid_sp_area, 'units', 'm2'
ncdf_attput, nc_sp_ann, nc_vid_sp_area, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann, nc_vid_sp_area, '_FillValue', nc_fv
nc_vid_sp_mass = ncdf_vardef(nc_sp_ann, 'mass',        [nc_sp_dim_t], /float)
ncdf_attput, nc_sp_ann, nc_vid_sp_mass, 'long_name', 'Glacier mass' & ncdf_attput, nc_sp_ann, nc_vid_sp_mass, 'units', 'kg'
ncdf_attput, nc_sp_ann, nc_vid_sp_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann, nc_vid_sp_mass, '_FillValue', nc_fv
nc_vid_sp_mbsl = ncdf_vardef(nc_sp_ann, 'mass_bsl',    [nc_sp_dim_t], /float)
ncdf_attput, nc_sp_ann, nc_vid_sp_mbsl, 'long_name', 'Glacier mass below sea level' & ncdf_attput, nc_sp_ann, nc_vid_sp_mbsl, 'units', 'kg'
ncdf_attput, nc_sp_ann, nc_vid_sp_mbsl, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann, nc_vid_sp_mbsl, '_FillValue', nc_fv
nc_vid_sp_fabl = ncdf_vardef(nc_sp_ann, 'frontal_abl', [nc_sp_dim_t], /float)
ncdf_attput, nc_sp_ann, nc_vid_sp_fabl, 'long_name', 'Total annual frontal ablation' & ncdf_attput, nc_sp_ann, nc_vid_sp_fabl, 'units', 'kg'
ncdf_attput, nc_sp_ann, nc_vid_sp_fabl, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_ann, nc_vid_sp_fabl, '_FillValue', nc_fv
ncdf_control, nc_sp_ann, /endef
ncdf_varput, nc_sp_ann, nc_vid_sp_t_ann, nc_time_ann_past

nc_sp_sub = ncdf_create(nc_sp_fn_sub, /clobber, /netcdf4)
ncdf_attput, nc_sp_sub, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sp_sub, /global, 'model', 'GloGEM'
ncdf_attput, nc_sp_sub, /global, 'institution', nc_institution
ncdf_attput, nc_sp_sub, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sp_sub, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sp_sub, /global, 'forcing',     nc_rea     & ncdf_attput, nc_sp_sub, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sp_sub, /global, 'period',      nc_period_past & ncdf_attput, nc_sp_sub, /global, 'split', 'past_portion'
ncdf_attput, nc_sp_sub, /global, 'creation_date', systime()
nc_sp_dim_s   = ncdf_dimdef(nc_sp_sub, 'time', nc_n_sub_past)
nc_vid_sp_t_sub = ncdf_vardef(nc_sp_sub, 'time', [nc_sp_dim_s], /long)
ncdf_attput, nc_sp_sub, nc_vid_sp_t_sub, 'long_name', 'time' & ncdf_attput, nc_sp_sub, nc_vid_sp_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sp_sub, nc_vid_sp_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sp_sub, nc_vid_sp_t_sub, 'cell_methods', 'time: point'
nc_vid_sp_acc  = ncdf_vardef(nc_sp_sub, 'acc',         [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_acc,  'long_name', 'Total accumulation' & ncdf_attput, nc_sp_sub, nc_vid_sp_acc,  'units', 'kg'
ncdf_attput, nc_sp_sub, nc_vid_sp_acc,  'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub, nc_vid_sp_acc,  '_FillValue', nc_fv
nc_vid_sp_melt = ncdf_vardef(nc_sp_sub, 'melt',        [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_melt, 'long_name', 'Total glacier melt (snow, ice, firn)' & ncdf_attput, nc_sp_sub, nc_vid_sp_melt, 'units', 'kg'
ncdf_attput, nc_sp_sub, nc_vid_sp_melt, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub, nc_vid_sp_melt, '_FillValue', nc_fv
nc_vid_sp_refr = ncdf_vardef(nc_sp_sub, 'refreeze',    [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_refr, 'long_name', 'Total refreezing' & ncdf_attput, nc_sp_sub, nc_vid_sp_refr, 'units', 'kg'
ncdf_attput, nc_sp_sub, nc_vid_sp_refr, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub, nc_vid_sp_refr, '_FillValue', nc_fv
nc_vid_sp_run  = ncdf_vardef(nc_sp_sub, 'runoff_glac', [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_run,  'long_name', 'Glacier runoff from glacierized area' & ncdf_attput, nc_sp_sub, nc_vid_sp_run,  'units', 'kg'
ncdf_attput, nc_sp_sub, nc_vid_sp_run,  'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub, nc_vid_sp_run,  '_FillValue', nc_fv
nc_vid_sp_prec = ncdf_vardef(nc_sp_sub, 'precip',      [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_prec, 'long_name', 'Total precipitation over initial glacierized area' & ncdf_attput, nc_sp_sub, nc_vid_sp_prec, 'units', 'kg'
ncdf_attput, nc_sp_sub, nc_vid_sp_prec, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub, nc_vid_sp_prec, '_FillValue', nc_fv
nc_vid_sp_temp = ncdf_vardef(nc_sp_sub, 'temp',        [nc_sp_dim_s], /float)
ncdf_attput, nc_sp_sub, nc_vid_sp_temp, 'long_name', 'Near-surface air temperature over initial glacierized area'
ncdf_attput, nc_sp_sub, nc_vid_sp_temp, 'units', 'K' & ncdf_attput, nc_sp_sub, nc_vid_sp_temp, 'cell_methods', 'time: mean' & ncdf_attput, nc_sp_sub, nc_vid_sp_temp, '_FillValue', nc_fv
ncdf_control, nc_sp_sub, /endef
ncdf_varput, nc_sp_sub, nc_vid_sp_t_sub, nc_time_sub_past

nc_sp_ann_i = ncdf_create(nc_sp_fn_ann_i, /clobber, /netcdf4)
ncdf_attput, nc_sp_ann_i, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sp_ann_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_sp_ann_i, /global, 'institution', nc_institution
ncdf_attput, nc_sp_ann_i, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sp_ann_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sp_ann_i, /global, 'forcing',     nc_rea & ncdf_attput, nc_sp_ann_i, /global, 'period', nc_period_past
ncdf_attput, nc_sp_ann_i, /global, 'split', 'past_portion' & ncdf_attput, nc_sp_ann_i, /global, 'creation_date', systime()
nc_sp_dim_g   = ncdf_dimdef(nc_sp_ann_i, 'glacier', cg)
nc_sp_dim_t_i = ncdf_dimdef(nc_sp_ann_i, 'time',    nc_years_past)
nc_vid_sp_i_rgid  = ncdf_vardef(nc_sp_ann_i, 'RGIId', [nc_sp_dim_g], /string)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_rgid, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_sp_i_t_ann = ncdf_vardef(nc_sp_ann_i, 'time', [nc_sp_dim_t_i], /long)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_t_ann, 'long_name', 'time' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_t_ann, 'calendar', 'standard' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_t_ann, 'cell_methods', 'time: point'
nc_vid_sp_i_area = ncdf_vardef(nc_sp_ann_i, 'area',        [nc_sp_dim_g, nc_sp_dim_t_i], /float)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_area, 'long_name', 'Glacier area' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_area, 'units', 'm2'
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_area, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_area, '_FillValue', nc_fv
nc_vid_sp_i_mass = ncdf_vardef(nc_sp_ann_i, 'mass',        [nc_sp_dim_g, nc_sp_dim_t_i], /float)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mass, 'long_name', 'Glacier mass' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mass, 'units', 'kg'
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mass, '_FillValue', nc_fv
nc_vid_sp_i_mbsl = ncdf_vardef(nc_sp_ann_i, 'mass_bsl',    [nc_sp_dim_g, nc_sp_dim_t_i], /float)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mbsl, 'long_name', 'Glacier mass below sea level' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mbsl, 'units', 'kg'
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mbsl, 'cell_methods', 'time: point' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_mbsl, '_FillValue', nc_fv
nc_vid_sp_i_fabl = ncdf_vardef(nc_sp_ann_i, 'frontal_abl', [nc_sp_dim_g, nc_sp_dim_t_i], /float)
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_fabl, 'long_name', 'Total annual frontal ablation' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_fabl, 'units', 'kg'
ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_fabl, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_ann_i, nc_vid_sp_i_fabl, '_FillValue', nc_fv
ncdf_control, nc_sp_ann_i, /endef
ncdf_varput, nc_sp_ann_i, nc_vid_sp_i_t_ann, nc_time_ann_past

nc_sp_sub_i = ncdf_create(nc_sp_fn_sub_i, /clobber, /netcdf4)
ncdf_attput, nc_sp_sub_i, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sp_sub_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_sp_sub_i, /global, 'institution', nc_institution
ncdf_attput, nc_sp_sub_i, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sp_sub_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sp_sub_i, /global, 'forcing',     nc_rea & ncdf_attput, nc_sp_sub_i, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sp_sub_i, /global, 'period',      nc_period_past & ncdf_attput, nc_sp_sub_i, /global, 'split', 'past_portion'
ncdf_attput, nc_sp_sub_i, /global, 'creation_date', systime()
nc_sp_dim_g_s = ncdf_dimdef(nc_sp_sub_i, 'glacier', cg)
nc_sp_dim_s_i = ncdf_dimdef(nc_sp_sub_i, 'time',    nc_n_sub_past)
nc_vid_sp_i_rgid_s = ncdf_vardef(nc_sp_sub_i, 'RGIId', [nc_sp_dim_g_s], /string)
ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_rgid_s, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_sp_i_t_sub = ncdf_vardef(nc_sp_sub_i, 'time', [nc_sp_dim_s_i], /long)
ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_t_sub, 'long_name', 'time' & ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_t_sub, 'cell_methods', 'time: point'
nc_vid_sp_i_run = ncdf_vardef(nc_sp_sub_i, 'runoff_glac', [nc_sp_dim_g_s, nc_sp_dim_s_i], /float)
ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_run, 'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_run, 'units', 'kg' & ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_run, 'cell_methods', 'time: sum' & ncdf_attput, nc_sp_sub_i, nc_vid_sp_i_run, '_FillValue', nc_fv
ncdf_control, nc_sp_sub_i, /endef
ncdf_varput, nc_sp_sub_i, nc_vid_sp_i_t_sub, nc_time_sub_past

; --- split future files (9–12) ---
nc_sf_ann = ncdf_create(nc_sf_fn_ann, /clobber, /netcdf4)
ncdf_attput, nc_sf_ann, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sf_ann, /global, 'model', 'GloGEM'
ncdf_attput, nc_sf_ann, /global, 'institution', nc_institution
ncdf_attput, nc_sf_ann, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sf_ann, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sf_ann, /global, 'forcing',     nc_gcm_tag & ncdf_attput, nc_sf_ann, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_sf_ann, /global, 'scenario',    nc_ssp_str & ncdf_attput, nc_sf_ann, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_sf_ann, /global, 'period',      nc_period_fut & ncdf_attput, nc_sf_ann, /global, 'split', 'future_portion'
ncdf_attput, nc_sf_ann, /global, 'creation_date', systime()
nc_sf_dim_t   = ncdf_dimdef(nc_sf_ann, 'time', nc_years_fut)
nc_vid_sf_t_ann = ncdf_vardef(nc_sf_ann, 'time', [nc_sf_dim_t], /long)
ncdf_attput, nc_sf_ann, nc_vid_sf_t_ann, 'long_name', 'time' & ncdf_attput, nc_sf_ann, nc_vid_sf_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sf_ann, nc_vid_sf_t_ann, 'calendar', 'standard' & ncdf_attput, nc_sf_ann, nc_vid_sf_t_ann, 'cell_methods', 'time: point'
nc_vid_sf_area = ncdf_vardef(nc_sf_ann, 'area',        [nc_sf_dim_t], /float)
ncdf_attput, nc_sf_ann, nc_vid_sf_area, 'long_name', 'Glacier area' & ncdf_attput, nc_sf_ann, nc_vid_sf_area, 'units', 'm2'
ncdf_attput, nc_sf_ann, nc_vid_sf_area, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann, nc_vid_sf_area, '_FillValue', nc_fv
nc_vid_sf_mass = ncdf_vardef(nc_sf_ann, 'mass',        [nc_sf_dim_t], /float)
ncdf_attput, nc_sf_ann, nc_vid_sf_mass, 'long_name', 'Glacier mass' & ncdf_attput, nc_sf_ann, nc_vid_sf_mass, 'units', 'kg'
ncdf_attput, nc_sf_ann, nc_vid_sf_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann, nc_vid_sf_mass, '_FillValue', nc_fv
nc_vid_sf_mbsl = ncdf_vardef(nc_sf_ann, 'mass_bsl',    [nc_sf_dim_t], /float)
ncdf_attput, nc_sf_ann, nc_vid_sf_mbsl, 'long_name', 'Glacier mass below sea level' & ncdf_attput, nc_sf_ann, nc_vid_sf_mbsl, 'units', 'kg'
ncdf_attput, nc_sf_ann, nc_vid_sf_mbsl, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann, nc_vid_sf_mbsl, '_FillValue', nc_fv
nc_vid_sf_fabl = ncdf_vardef(nc_sf_ann, 'frontal_abl', [nc_sf_dim_t], /float)
ncdf_attput, nc_sf_ann, nc_vid_sf_fabl, 'long_name', 'Total annual frontal ablation' & ncdf_attput, nc_sf_ann, nc_vid_sf_fabl, 'units', 'kg'
ncdf_attput, nc_sf_ann, nc_vid_sf_fabl, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_ann, nc_vid_sf_fabl, '_FillValue', nc_fv
ncdf_control, nc_sf_ann, /endef
ncdf_varput, nc_sf_ann, nc_vid_sf_t_ann, nc_time_ann_fut

nc_sf_sub = ncdf_create(nc_sf_fn_sub, /clobber, /netcdf4)
ncdf_attput, nc_sf_sub, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sf_sub, /global, 'model', 'GloGEM'
ncdf_attput, nc_sf_sub, /global, 'institution', nc_institution
ncdf_attput, nc_sf_sub, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sf_sub, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sf_sub, /global, 'forcing',     nc_gcm_tag & ncdf_attput, nc_sf_sub, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_sf_sub, /global, 'scenario',    nc_ssp_str & ncdf_attput, nc_sf_sub, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_sf_sub, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sf_sub, /global, 'period',      nc_period_fut & ncdf_attput, nc_sf_sub, /global, 'split', 'future_portion'
ncdf_attput, nc_sf_sub, /global, 'creation_date', systime()
nc_sf_dim_s   = ncdf_dimdef(nc_sf_sub, 'time', nc_n_sub_fut)
nc_vid_sf_t_sub = ncdf_vardef(nc_sf_sub, 'time', [nc_sf_dim_s], /long)
ncdf_attput, nc_sf_sub, nc_vid_sf_t_sub, 'long_name', 'time' & ncdf_attput, nc_sf_sub, nc_vid_sf_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sf_sub, nc_vid_sf_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sf_sub, nc_vid_sf_t_sub, 'cell_methods', 'time: point'
nc_vid_sf_acc  = ncdf_vardef(nc_sf_sub, 'acc',         [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_acc,  'long_name', 'Total accumulation' & ncdf_attput, nc_sf_sub, nc_vid_sf_acc,  'units', 'kg'
ncdf_attput, nc_sf_sub, nc_vid_sf_acc,  'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub, nc_vid_sf_acc,  '_FillValue', nc_fv
nc_vid_sf_melt = ncdf_vardef(nc_sf_sub, 'melt',        [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_melt, 'long_name', 'Total glacier melt (snow, ice, firn)' & ncdf_attput, nc_sf_sub, nc_vid_sf_melt, 'units', 'kg'
ncdf_attput, nc_sf_sub, nc_vid_sf_melt, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub, nc_vid_sf_melt, '_FillValue', nc_fv
nc_vid_sf_refr = ncdf_vardef(nc_sf_sub, 'refreeze',    [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_refr, 'long_name', 'Total refreezing' & ncdf_attput, nc_sf_sub, nc_vid_sf_refr, 'units', 'kg'
ncdf_attput, nc_sf_sub, nc_vid_sf_refr, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub, nc_vid_sf_refr, '_FillValue', nc_fv
nc_vid_sf_run  = ncdf_vardef(nc_sf_sub, 'runoff_glac', [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_run,  'long_name', 'Glacier runoff from glacierized area' & ncdf_attput, nc_sf_sub, nc_vid_sf_run,  'units', 'kg'
ncdf_attput, nc_sf_sub, nc_vid_sf_run,  'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub, nc_vid_sf_run,  '_FillValue', nc_fv
nc_vid_sf_prec = ncdf_vardef(nc_sf_sub, 'precip',      [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_prec, 'long_name', 'Total precipitation over initial glacierized area' & ncdf_attput, nc_sf_sub, nc_vid_sf_prec, 'units', 'kg'
ncdf_attput, nc_sf_sub, nc_vid_sf_prec, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub, nc_vid_sf_prec, '_FillValue', nc_fv
nc_vid_sf_temp = ncdf_vardef(nc_sf_sub, 'temp',        [nc_sf_dim_s], /float)
ncdf_attput, nc_sf_sub, nc_vid_sf_temp, 'long_name', 'Near-surface air temperature over initial glacierized area'
ncdf_attput, nc_sf_sub, nc_vid_sf_temp, 'units', 'K' & ncdf_attput, nc_sf_sub, nc_vid_sf_temp, 'cell_methods', 'time: mean' & ncdf_attput, nc_sf_sub, nc_vid_sf_temp, '_FillValue', nc_fv
ncdf_control, nc_sf_sub, /endef
ncdf_varput, nc_sf_sub, nc_vid_sf_t_sub, nc_time_sub_fut

nc_sf_ann_i = ncdf_create(nc_sf_fn_ann_i, /clobber, /netcdf4)
ncdf_attput, nc_sf_ann_i, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sf_ann_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_sf_ann_i, /global, 'institution', nc_institution
ncdf_attput, nc_sf_ann_i, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sf_ann_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sf_ann_i, /global, 'forcing',     nc_gcm_tag & ncdf_attput, nc_sf_ann_i, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_sf_ann_i, /global, 'scenario',    nc_ssp_str & ncdf_attput, nc_sf_ann_i, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_sf_ann_i, /global, 'period',      nc_period_fut & ncdf_attput, nc_sf_ann_i, /global, 'split', 'future_portion'
ncdf_attput, nc_sf_ann_i, /global, 'creation_date', systime()
nc_sf_dim_g   = ncdf_dimdef(nc_sf_ann_i, 'glacier', cg)
nc_sf_dim_t_i = ncdf_dimdef(nc_sf_ann_i, 'time',    nc_years_fut)
nc_vid_sf_i_rgid  = ncdf_vardef(nc_sf_ann_i, 'RGIId', [nc_sf_dim_g], /string)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_rgid, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_sf_i_t_ann = ncdf_vardef(nc_sf_ann_i, 'time', [nc_sf_dim_t_i], /long)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_t_ann, 'long_name', 'time' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_t_ann, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_t_ann, 'calendar', 'standard' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_t_ann, 'cell_methods', 'time: point'
nc_vid_sf_i_area = ncdf_vardef(nc_sf_ann_i, 'area',        [nc_sf_dim_g, nc_sf_dim_t_i], /float)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_area, 'long_name', 'Glacier area' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_area, 'units', 'm2'
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_area, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_area, '_FillValue', nc_fv
nc_vid_sf_i_mass = ncdf_vardef(nc_sf_ann_i, 'mass',        [nc_sf_dim_g, nc_sf_dim_t_i], /float)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mass, 'long_name', 'Glacier mass' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mass, 'units', 'kg'
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mass, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mass, '_FillValue', nc_fv
nc_vid_sf_i_mbsl = ncdf_vardef(nc_sf_ann_i, 'mass_bsl',    [nc_sf_dim_g, nc_sf_dim_t_i], /float)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mbsl, 'long_name', 'Glacier mass below sea level' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mbsl, 'units', 'kg'
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mbsl, 'cell_methods', 'time: point' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_mbsl, '_FillValue', nc_fv
nc_vid_sf_i_fabl = ncdf_vardef(nc_sf_ann_i, 'frontal_abl', [nc_sf_dim_g, nc_sf_dim_t_i], /float)
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_fabl, 'long_name', 'Total annual frontal ablation' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_fabl, 'units', 'kg'
ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_fabl, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_ann_i, nc_vid_sf_i_fabl, '_FillValue', nc_fv
ncdf_control, nc_sf_ann_i, /endef
ncdf_varput, nc_sf_ann_i, nc_vid_sf_i_t_ann, nc_time_ann_fut

nc_sf_sub_i = ncdf_create(nc_sf_fn_sub_i, /clobber, /netcdf4)
ncdf_attput, nc_sf_sub_i, /global, 'Conventions', 'CF-1.8' & ncdf_attput, nc_sf_sub_i, /global, 'model', 'GloGEM'
ncdf_attput, nc_sf_sub_i, /global, 'institution', nc_institution
ncdf_attput, nc_sf_sub_i, /global, 'rgi_region',  nc_rgi_str & ncdf_attput, nc_sf_sub_i, /global, 'catchment', strtrim(catchment_selection,2)
ncdf_attput, nc_sf_sub_i, /global, 'forcing',     nc_gcm_tag & ncdf_attput, nc_sf_sub_i, /global, 'gcm', nc_gcm_str
ncdf_attput, nc_sf_sub_i, /global, 'scenario',    nc_ssp_str & ncdf_attput, nc_sf_sub_i, /global, 'gcm_data', nc_dat_str
ncdf_attput, nc_sf_sub_i, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sf_sub_i, /global, 'period',      nc_period_fut & ncdf_attput, nc_sf_sub_i, /global, 'split', 'future_portion'
ncdf_attput, nc_sf_sub_i, /global, 'creation_date', systime()
nc_sf_dim_g_s = ncdf_dimdef(nc_sf_sub_i, 'glacier', cg)
nc_sf_dim_s_i = ncdf_dimdef(nc_sf_sub_i, 'time',    nc_n_sub_fut)
nc_vid_sf_i_rgid_s = ncdf_vardef(nc_sf_sub_i, 'RGIId', [nc_sf_dim_g_s], /string)
ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_rgid_s, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_sf_i_t_sub = ncdf_vardef(nc_sf_sub_i, 'time', [nc_sf_dim_s_i], /long)
ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_t_sub, 'long_name', 'time' & ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_t_sub, 'units', 'days since 1850-01-01'
ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_t_sub, 'calendar', 'standard' & ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_t_sub, 'cell_methods', 'time: point'
nc_vid_sf_i_run = ncdf_vardef(nc_sf_sub_i, 'runoff_glac', [nc_sf_dim_g_s, nc_sf_dim_s_i], /float)
ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_run, 'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_run, 'units', 'kg' & ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_run, 'cell_methods', 'time: sum' & ncdf_attput, nc_sf_sub_i, nc_vid_sf_i_run, '_FillValue', nc_fv
ncdf_control, nc_sf_sub_i, /endef
ncdf_varput, nc_sf_sub_i, nc_vid_sf_i_t_sub, nc_time_sub_fut

; --- split regional accumulators ---
nc_reg_sp_area   = fltarr(nc_years_past)
nc_reg_sp_mass   = fltarr(nc_years_past)
nc_reg_sp_mbsl   = fltarr(nc_years_past)
nc_reg_sp_fabl   = fltarr(nc_years_past)
nc_reg_sp_acc    = fltarr(nc_n_sub_past)
nc_reg_sp_melt   = fltarr(nc_n_sub_past)
nc_reg_sp_refr   = fltarr(nc_n_sub_past)
nc_reg_sp_run    = fltarr(nc_n_sub_past)
nc_reg_sp_prec   = fltarr(nc_n_sub_past)
nc_reg_sp_temp_w = dblarr(nc_n_sub_past)
nc_reg_sp_temp_a = dblarr(nc_n_sub_past)

nc_reg_sf_area   = fltarr(nc_years_fut)
nc_reg_sf_mass   = fltarr(nc_years_fut)
nc_reg_sf_mbsl   = fltarr(nc_years_fut)
nc_reg_sf_fabl   = fltarr(nc_years_fut)
nc_reg_sf_acc    = fltarr(nc_n_sub_fut)
nc_reg_sf_melt   = fltarr(nc_n_sub_fut)
nc_reg_sf_refr   = fltarr(nc_n_sub_fut)
nc_reg_sf_run    = fltarr(nc_n_sub_fut)
nc_reg_sf_prec   = fltarr(nc_n_sub_fut)
nc_reg_sf_temp_w = dblarr(nc_n_sub_fut)
nc_reg_sf_temp_a = dblarr(nc_n_sub_fut)

init_proj_done:
