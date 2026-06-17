; *************************************************************
; init_netcdf_hindcast
;
; Initialise GlacierMIP4-compliant NetCDF output files for a
; hindcast run before the glacier loop begins. Creates the file
; structure, defines all dimensions and variables, writes the
; time axes, and initialises regional accumulator arrays.
;
; Called once per region run when write_netcdf eq 'y' and
; reanalysis_direct eq 'y'. The complementary procedures are:
;   @write_netcdf_glacier.pro  - called after each glacier
;   @write_netcdf_hindcast.pro - called after the glacier loop
;
; Four NetCDF4 files are created in PAST/PAST_netcdf/:
;   GloGEM_rgi[XX]_[reanalysis]_annual.nc
;   GloGEM_rgi[XX]_[reanalysis]_monthly.nc  (or _daily.nc)
;   GloGEM_rgi[XX]indiv_[reanalysis]_annual.nc
;   GloGEM_rgi[XX]indiv_[reanalysis]_monthly.nc  (or _daily.nc)
; (catchment runs insert the catchment name after rgi[XX])
;
; Variables set in scope after this procedure (used by
; write_netcdf_glacier and write_netcdf_hindcast):
;   nc_ann, nc_sub, nc_ann_i, nc_sub_i  - NetCDF file IDs
;   nc_vid_*                             - variable IDs
;   nc_reg_*                             - regional accumulators
;   nc_years, nc_n_sub, nc_tran          - time dimensions
;   nc_sub_lbl                           - 'monthly' or 'daily'
;   nc_fv                                - fill value (NaN)
;   nc_has_split                         - 0 (no split for hindcast)
;   nc_g                                 - glacier counter (starts at 0)
;
; Expected variables in scope (from glogem.pro):
;   dirres, dir_region, time_resolution
;   tran[2], years, cg
;   gmip4_region, catchment_selection, reanalysis
; *************************************************************

compile_opt idl2

; --- melt model suffix (mirrors setup_output_folders logic) ---
nc_mtt = ''
if meltmodel ne '1' then nc_mtt = '_m3'
if meltmodel eq '1' and calperiod_ID eq 8 then nc_mtt = '_debris'

; --- output path ---
nc_base   = dirres + time_resolution + path_sep() + dir_region + path_sep()
nc_outdir = nc_base + 'PAST' + version_past + nc_mtt + path_sep() + 'PAST_netcdf' + path_sep()
if ~file_test(nc_outdir, /directory) then file_mkdir, nc_outdir

; --- file name tags ---
; region_id_loop[0] + re gives the current RGI region integer (e.g. 1 for RGI01)
nc_rgi_str = string(region_id_loop[0] + re, format='(i02)')
if catchment_selection eq '' then begin
    nc_base_tag  = 'rgi' + nc_rgi_str
    nc_indiv_tag = 'rgi' + nc_rgi_str + 'indiv'
endif else begin
    nc_catch     = strtrim(catchment_selection, 2)
    nc_base_tag  = 'rgi' + nc_rgi_str + '_' + nc_catch
    nc_indiv_tag = 'rgi' + nc_rgi_str + '_' + nc_catch + 'indiv'
endelse
nc_rea = strupcase(strtrim(reanalysis, 2))   ; uppercase for GlacierMIP4 naming (e.g. ERA5)

; --- time setup ---
nc_years  = years
nc_tran   = tran
nc_fv     = !VALUES.F_NAN
nc_ref_jd = julday(1, 1, 1850)

if time_resolution eq 'monthly' then begin
    nc_n_sub  = nc_years * 12
    nc_sub_lbl = 'monthly'
    nc_time_sub = lonarr(nc_n_sub)
    idx = 0L
    for yr = 0L, nc_years-1L do $
        for mo = 1, 12 do begin
            nc_time_sub[idx] = long(julday(mo, 1, nc_tran[0]+yr) - nc_ref_jd)
            idx++
        endfor
endif else begin
    nc_n_sub  = nc_years * 365
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

; --- file names ---
nc_fn_ann   = nc_outdir + 'GloGEM_' + nc_base_tag  + '_' + nc_rea + '_annual.nc'
nc_fn_sub   = nc_outdir + 'GloGEM_' + nc_base_tag  + '_' + nc_rea + '_' + nc_sub_lbl + '.nc'
nc_fn_ann_i = nc_outdir + 'GloGEM_' + nc_indiv_tag + '_' + nc_rea + '_annual.nc'
nc_fn_sub_i = nc_outdir + 'GloGEM_' + nc_indiv_tag + '_' + nc_rea + '_' + nc_sub_lbl + '.nc'

; ================================================================
; 1. REGIONAL ANNUAL FILE
; ================================================================
nc_ann = ncdf_create(nc_fn_ann, /clobber, /netcdf4)
ncdf_attput, nc_ann, /global, 'Conventions',    'CF-1.8'
ncdf_attput, nc_ann, /global, 'model',          'GloGEM'
ncdf_attput, nc_ann, /global, 'institution',    'ETH, VAW'
ncdf_attput, nc_ann, /global, 'rgi_region',     nc_rgi_str
ncdf_attput, nc_ann, /global, 'catchment',      strtrim(catchment_selection, 2)
ncdf_attput, nc_ann, /global, 'forcing',        nc_rea
ncdf_attput, nc_ann, /global, 'period',         nc_period
ncdf_attput, nc_ann, /global, 'creation_date',  systime()

nc_dim_t = ncdf_dimdef(nc_ann, 'time', nc_years)
nc_vid_t_ann  = ncdf_vardef(nc_ann, 'time', [nc_dim_t], /long)
ncdf_attput, nc_ann, nc_vid_t_ann, 'long_name', 'time'
ncdf_attput, nc_ann, nc_vid_t_ann, 'units',     'days since 1850-01-01'
ncdf_attput, nc_ann, nc_vid_t_ann, 'calendar',  'standard'
ncdf_attput, nc_ann, nc_vid_t_ann, 'cell_methods', 'time: point'
nc_vid_area = ncdf_vardef(nc_ann, 'area',        [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_area, 'long_name', 'Glacier area'
ncdf_attput, nc_ann, nc_vid_area, 'units', 'm2'
ncdf_attput, nc_ann, nc_vid_area, 'cell_methods', 'time: point'
ncdf_attput, nc_ann, nc_vid_area, '_FillValue', nc_fv
nc_vid_mass = ncdf_vardef(nc_ann, 'mass',        [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_mass, 'long_name', 'Glacier mass'
ncdf_attput, nc_ann, nc_vid_mass, 'units', 'kg'
ncdf_attput, nc_ann, nc_vid_mass, 'cell_methods', 'time: point'
ncdf_attput, nc_ann, nc_vid_mass, '_FillValue', nc_fv
nc_vid_mbsl = ncdf_vardef(nc_ann, 'mass_bsl',    [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_mbsl, 'long_name', 'Glacier mass below sea level'
ncdf_attput, nc_ann, nc_vid_mbsl, 'units', 'kg'
ncdf_attput, nc_ann, nc_vid_mbsl, 'cell_methods', 'time: point'
ncdf_attput, nc_ann, nc_vid_mbsl, '_FillValue', nc_fv
nc_vid_fabl = ncdf_vardef(nc_ann, 'frontal_abl', [nc_dim_t], /float)
ncdf_attput, nc_ann, nc_vid_fabl, 'long_name', 'Total annual frontal ablation'
ncdf_attput, nc_ann, nc_vid_fabl, 'units', 'kg'
ncdf_attput, nc_ann, nc_vid_fabl, 'cell_methods', 'time: sum'
ncdf_attput, nc_ann, nc_vid_fabl, '_FillValue', nc_fv
ncdf_control, nc_ann, /endef
ncdf_varput, nc_ann, nc_vid_t_ann, nc_time_ann

; ================================================================
; 2. REGIONAL SUB-ANNUAL FILE
; ================================================================
nc_sub = ncdf_create(nc_fn_sub, /clobber, /netcdf4)
ncdf_attput, nc_sub, /global, 'Conventions',    'CF-1.8'
ncdf_attput, nc_sub, /global, 'model',          'GloGEM'
ncdf_attput, nc_sub, /global, 'institution',    'ETH, VAW'
ncdf_attput, nc_sub, /global, 'rgi_region',     nc_rgi_str
ncdf_attput, nc_sub, /global, 'catchment',      strtrim(catchment_selection, 2)
ncdf_attput, nc_sub, /global, 'forcing',        nc_rea
ncdf_attput, nc_sub, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sub, /global, 'period',         nc_period
ncdf_attput, nc_sub, /global, 'creation_date',  systime()

nc_dim_s = ncdf_dimdef(nc_sub, 'time', nc_n_sub)
nc_vid_t_sub  = ncdf_vardef(nc_sub, 'time',        [nc_dim_s], /long)
ncdf_attput, nc_sub, nc_vid_t_sub, 'long_name', 'time'
ncdf_attput, nc_sub, nc_vid_t_sub, 'units',     'days since 1850-01-01'
ncdf_attput, nc_sub, nc_vid_t_sub, 'calendar',  'standard'
ncdf_attput, nc_sub, nc_vid_t_sub, 'cell_methods', 'time: point'
nc_vid_acc  = ncdf_vardef(nc_sub, 'acc',        [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_acc,  'long_name', 'Total accumulation'
ncdf_attput, nc_sub, nc_vid_acc,  'units', 'kg'
ncdf_attput, nc_sub, nc_vid_acc,  'cell_methods', 'time: sum'
ncdf_attput, nc_sub, nc_vid_acc,  '_FillValue', nc_fv
nc_vid_melt = ncdf_vardef(nc_sub, 'melt',       [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_melt, 'long_name', 'Total glacier melt (snow, ice, firn)'
ncdf_attput, nc_sub, nc_vid_melt, 'units', 'kg'
ncdf_attput, nc_sub, nc_vid_melt, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub, nc_vid_melt, '_FillValue', nc_fv
nc_vid_refr = ncdf_vardef(nc_sub, 'refreeze',   [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_refr, 'long_name', 'Total refreezing'
ncdf_attput, nc_sub, nc_vid_refr, 'units', 'kg'
ncdf_attput, nc_sub, nc_vid_refr, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub, nc_vid_refr, '_FillValue', nc_fv
nc_vid_run  = ncdf_vardef(nc_sub, 'runoff_glac', [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_run,  'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sub, nc_vid_run,  'units', 'kg'
ncdf_attput, nc_sub, nc_vid_run,  'cell_methods', 'time: sum'
ncdf_attput, nc_sub, nc_vid_run,  '_FillValue', nc_fv
nc_vid_prec = ncdf_vardef(nc_sub, 'precip',     [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_prec, 'long_name', 'Total precipitation over initial glacierized area'
ncdf_attput, nc_sub, nc_vid_prec, 'units', 'kg'
ncdf_attput, nc_sub, nc_vid_prec, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub, nc_vid_prec, '_FillValue', nc_fv
nc_vid_temp = ncdf_vardef(nc_sub, 'temp',       [nc_dim_s], /float)
ncdf_attput, nc_sub, nc_vid_temp, 'long_name', 'Near-surface air temperature over initial glacierized area'
ncdf_attput, nc_sub, nc_vid_temp, 'units', 'K'
ncdf_attput, nc_sub, nc_vid_temp, 'cell_methods', 'time: mean'
ncdf_attput, nc_sub, nc_vid_temp, '_FillValue', nc_fv
ncdf_control, nc_sub, /endef
ncdf_varput, nc_sub, nc_vid_t_sub, nc_time_sub

; ================================================================
; 3. INDIVIDUAL ANNUAL FILE
; ================================================================
nc_ann_i = ncdf_create(nc_fn_ann_i, /clobber, /netcdf4)
ncdf_attput, nc_ann_i, /global, 'Conventions',   'CF-1.8'
ncdf_attput, nc_ann_i, /global, 'model',         'GloGEM'
ncdf_attput, nc_ann_i, /global, 'institution',   'ETH, VAW'
ncdf_attput, nc_ann_i, /global, 'rgi_region',    nc_rgi_str
ncdf_attput, nc_ann_i, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, nc_ann_i, /global, 'forcing',       nc_rea
ncdf_attput, nc_ann_i, /global, 'period',        nc_period
ncdf_attput, nc_ann_i, /global, 'creation_date', systime()

nc_dim_g   = ncdf_dimdef(nc_ann_i, 'glacier', nc_total_g)
nc_dim_t_i = ncdf_dimdef(nc_ann_i, 'time',    nc_years)
nc_vid_i_rgid = ncdf_vardef(nc_ann_i, 'RGIId', [nc_dim_g], /string)
ncdf_attput, nc_ann_i, nc_vid_i_rgid, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_i_t_ann = ncdf_vardef(nc_ann_i, 'time', [nc_dim_t_i], /long)
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'long_name', 'time'
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'units',     'days since 1850-01-01'
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'calendar',  'standard'
ncdf_attput, nc_ann_i, nc_vid_i_t_ann, 'cell_methods', 'time: point'
nc_vid_i_area = ncdf_vardef(nc_ann_i, 'area',        [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_area, 'long_name', 'Glacier area'
ncdf_attput, nc_ann_i, nc_vid_i_area, 'units', 'm2'
ncdf_attput, nc_ann_i, nc_vid_i_area, 'cell_methods', 'time: point'
ncdf_attput, nc_ann_i, nc_vid_i_area, '_FillValue', nc_fv
nc_vid_i_mass = ncdf_vardef(nc_ann_i, 'mass',        [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_mass, 'long_name', 'Glacier mass'
ncdf_attput, nc_ann_i, nc_vid_i_mass, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_mass, 'cell_methods', 'time: point'
ncdf_attput, nc_ann_i, nc_vid_i_mass, '_FillValue', nc_fv
nc_vid_i_mbsl = ncdf_vardef(nc_ann_i, 'mass_bsl',    [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'long_name', 'Glacier mass below sea level'
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, 'cell_methods', 'time: point'
ncdf_attput, nc_ann_i, nc_vid_i_mbsl, '_FillValue', nc_fv
nc_vid_i_fabl = ncdf_vardef(nc_ann_i, 'frontal_abl', [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'long_name', 'Total annual frontal ablation'
ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'units', 'kg'
ncdf_attput, nc_ann_i, nc_vid_i_fabl, 'cell_methods', 'time: sum'
ncdf_attput, nc_ann_i, nc_vid_i_fabl, '_FillValue', nc_fv
; --- GlacierMIP4 Table 5 optional individual-glacier variables ---
nc_vid_i_ela = ncdf_vardef(nc_ann_i, 'ELA', [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_ela, 'long_name', 'Altitude of the annual equilibrium line'
ncdf_attput, nc_ann_i, nc_vid_i_ela, 'units', 'm'
ncdf_attput, nc_ann_i, nc_vid_i_ela, 'cell_methods', 'time: maximum'
ncdf_attput, nc_ann_i, nc_vid_i_ela, '_FillValue', nc_fv
nc_vid_i_aar = ncdf_vardef(nc_ann_i, 'AAR', [nc_dim_g, nc_dim_t_i], /float)
ncdf_attput, nc_ann_i, nc_vid_i_aar, 'long_name', 'Annual Accumulation Area Ratio'
ncdf_attput, nc_ann_i, nc_vid_i_aar, 'units', '1'
ncdf_attput, nc_ann_i, nc_vid_i_aar, 'cell_methods', 'time: maximum'
ncdf_attput, nc_ann_i, nc_vid_i_aar, '_FillValue', nc_fv
ncdf_control, nc_ann_i, /endef
ncdf_varput, nc_ann_i, nc_vid_i_t_ann, nc_time_ann

; ================================================================
; 4. INDIVIDUAL SUB-ANNUAL FILE (runoff_glac only)
; ================================================================
nc_sub_i = ncdf_create(nc_fn_sub_i, /clobber, /netcdf4)
ncdf_attput, nc_sub_i, /global, 'Conventions',    'CF-1.8'
ncdf_attput, nc_sub_i, /global, 'model',          'GloGEM'
ncdf_attput, nc_sub_i, /global, 'institution',    'ETH, VAW'
ncdf_attput, nc_sub_i, /global, 'rgi_region',     nc_rgi_str
ncdf_attput, nc_sub_i, /global, 'catchment',      strtrim(catchment_selection, 2)
ncdf_attput, nc_sub_i, /global, 'forcing',        nc_rea
ncdf_attput, nc_sub_i, /global, 'time_resolution', nc_sub_lbl
ncdf_attput, nc_sub_i, /global, 'period',         nc_period
ncdf_attput, nc_sub_i, /global, 'creation_date',  systime()

nc_dim_g_s   = ncdf_dimdef(nc_sub_i, 'glacier', nc_total_g)
nc_dim_s_i   = ncdf_dimdef(nc_sub_i, 'time',    nc_n_sub)
nc_vid_i_rgid_s = ncdf_vardef(nc_sub_i, 'RGIId', [nc_dim_g_s], /string)
ncdf_attput, nc_sub_i, nc_vid_i_rgid_s, 'long_name', 'Randolph Glacier Inventory ID'
nc_vid_i_t_sub = ncdf_vardef(nc_sub_i, 'time', [nc_dim_s_i], /long)
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'long_name', 'time'
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'units',     'days since 1850-01-01'
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'calendar',  'standard'
ncdf_attput, nc_sub_i, nc_vid_i_t_sub, 'cell_methods', 'time: point'
nc_vid_i_run = ncdf_vardef(nc_sub_i, 'runoff_glac', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_run, 'long_name', 'Glacier runoff from glacierized area'
ncdf_attput, nc_sub_i, nc_vid_i_run, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_run, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_run, '_FillValue', nc_fv
; --- GlacierMIP4 Table 5 optional individual-glacier variable ---
nc_vid_i_rbas = ncdf_vardef(nc_sub_i, 'runoff_basin', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_rbas, 'long_name', 'Runoff from the initial glacierized area'
ncdf_attput, nc_sub_i, nc_vid_i_rbas, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_rbas, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_rbas, '_FillValue', nc_fv
; --- GlacierMIP4 Table 4 mandatory variables (per glacier) ---
nc_vid_i_acc = ncdf_vardef(nc_sub_i, 'acc', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_acc, 'long_name', 'Total accumulation'
ncdf_attput, nc_sub_i, nc_vid_i_acc, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_acc, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_acc, '_FillValue', nc_fv
nc_vid_i_melt = ncdf_vardef(nc_sub_i, 'melt', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_melt, 'long_name', 'Total glacier melt (snow, ice, firn)'
ncdf_attput, nc_sub_i, nc_vid_i_melt, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_melt, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_melt, '_FillValue', nc_fv
nc_vid_i_refr = ncdf_vardef(nc_sub_i, 'refreeze', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_refr, 'long_name', 'Total refreezing'
ncdf_attput, nc_sub_i, nc_vid_i_refr, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_refr, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_refr, '_FillValue', nc_fv
nc_vid_i_prec = ncdf_vardef(nc_sub_i, 'precip', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_prec, 'long_name', 'Total precipitation over initial glacierized area'
ncdf_attput, nc_sub_i, nc_vid_i_prec, 'units', 'kg'
ncdf_attput, nc_sub_i, nc_vid_i_prec, 'cell_methods', 'time: sum'
ncdf_attput, nc_sub_i, nc_vid_i_prec, '_FillValue', nc_fv
nc_vid_i_temp = ncdf_vardef(nc_sub_i, 'temp', [nc_dim_g_s, nc_dim_s_i], /float)
ncdf_attput, nc_sub_i, nc_vid_i_temp, 'long_name', 'Near-surface air temperature over initial glacierized area'
ncdf_attput, nc_sub_i, nc_vid_i_temp, 'units', 'K'
ncdf_attput, nc_sub_i, nc_vid_i_temp, 'cell_methods', 'time: mean'
ncdf_attput, nc_sub_i, nc_vid_i_temp, '_FillValue', nc_fv
ncdf_control, nc_sub_i, /endef
ncdf_varput, nc_sub_i, nc_vid_i_t_sub, nc_time_sub

; ================================================================
; REGIONAL ACCUMULATORS  (summed across glaciers per time step)
; ================================================================
nc_reg_area = fltarr(nc_years)
nc_reg_mass = fltarr(nc_years)
nc_reg_mbsl = fltarr(nc_years)
nc_reg_fabl = fltarr(nc_years)
nc_reg_acc  = fltarr(nc_n_sub)
nc_reg_melt = fltarr(nc_n_sub)
nc_reg_refr = fltarr(nc_n_sub)
nc_reg_run  = fltarr(nc_n_sub)
nc_reg_prec = fltarr(nc_n_sub)
nc_reg_temp_w = dblarr(nc_n_sub)   ; weighted temperature sum (numerator)
nc_reg_temp_a = dblarr(nc_n_sub)   ; initial area sum (denominator)

nc_has_split = 0   ; no split for pure hindcast runs
nc_g         = 0L  ; glacier counter (incremented in write_netcdf_glacier)
