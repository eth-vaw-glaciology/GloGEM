; *************************************************************
; write_netcdf_projections
;
; Write GlacierMIP4-compliant NetCDF output files for a climate
; projection run (GCM x SSP). CF-1.8 metadata conventions are
; followed throughout. Activated when write_netcdf eq 'y' in
; config.pro.
;
; Structurally identical to write_netcdf_hindcast.pro but uses
; GCM_model and GCM_rcp to compose file names and global attributes
; in place of ERA5. Must be called once per region per GCM x SSP
; combination, after the full glacier loop has completed.
;
; Works with both monthly and daily model configurations and with
; both full-region and catchment_selection runs. Handles RGI6 and
; RGI7 glacier IDs transparently.
;
; Four NetCDF4 files are created per run:
;
;   Full region run (catchment_selection eq ''):
;     GloGEM_rgi[XX]_[GCM]_[SSP]_annual.nc
;     GloGEM_rgi[XX]_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;     GloGEM_rgi[XX]indiv_[GCM]_[SSP]_annual.nc
;     GloGEM_rgi[XX]indiv_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;
;   Catchment selection run (catchment_selection ne ''):
;     GloGEM_rgi[XX]_[catchment]_[GCM]_[SSP]_annual.nc
;     GloGEM_rgi[XX]_[catchment]_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;     GloGEM_rgi[XX]_[catchment]indiv_[GCM]_[SSP]_annual.nc
;     GloGEM_rgi[XX]_[catchment]indiv_[GCM]_[SSP]_monthly.nc  (or _daily.nc)
;
; Annual variables (state at start of year, all positive per GlacierMIP4
; sign convention):
;   area         [m2]   - glacier area
;   mass         [kg]   - total glacier mass
;   mass_bsl     [kg]   - glacier mass below sea level
;   frontal_abl  [kg]   - total frontal ablation over preceding year
;
; Sub-annual variables (sums or means per time step):
;   acc          [kg]   - total accumulation
;   melt         [kg]   - total melt (snow + ice + firn)
;   refreeze     [kg]   - total refreezing
;   runoff_glac  [kg]   - glacier runoff from glacierized area
;   precip       [kg]   - precipitation over initial area (regional only)
;   temp         [K]    - air temperature over initial area (regional only)
;
; Time axis: integer days since 1850-01-01 (start of year, month or day).
;
; Note on unit conversions applied before calling this procedure
; (to be performed in glogem.pro when building the gmip4 arrays):
;   areas[ye]    [km2]        x 1e6       -> m2
;   volumes[ye]  [km3]        x 917e9     -> kg  (rho_ice = 917 kg/m3)
;   vol_bz[ye]   [km3]        x 917e9     -> kg
;   flux_calv[ye][m w.e.]     x ar_gl x 1e9 -> kg
;   accmo/accday [m w.e.]     x ar_gl x 1e9 -> kg
;   melmo        [m w.e.]     x ar_gl x 1e9 -> kg
;   melt (daily) snowmeltday + icemeltday, each x respective area x 1e9 -> kg
;   refrmo/refrday [m w.e.]   x ar_gl x 1e9 -> kg
;   discharge_gl [m w.e.]     x ar_gl x 1e9 -> kg
;   precmo_ini/precday_ini [m w.e. x km2] x 1e9 -> kg
;   tempmo_ini/tempday_ini   already in K
;
; Expected variables in scope (set up by glogem.pro before calling):
;   gmip4_ng                   - number of glaciers [long]
;   gmip4_rgiids[ng]           - RGI IDs as string array
;   gmip4_area[ng, years]      - glacier area per glacier per year [m2]
;   gmip4_mass[ng, years]      - glacier mass per glacier per year [kg]
;   gmip4_mass_bsl[ng, years]  - mass below sea level per glacier [kg]
;   gmip4_frontal_abl[ng,years]- frontal ablation per glacier [kg]
;   gmip4_acc[ng, years*12 or years*365]   - accumulation per glacier [kg]
;   gmip4_melt[ng, years*12 or years*365]  - melt per glacier [kg]
;   gmip4_refreeze[ng, years*12 or years*365] - refreezing per glacier [kg]
;   gmip4_runoff[ng, years*12 or years*365]   - runoff per glacier [kg]
;   gmip4_precip[years*12 or years*365]    - precip over initial area [kg]
;                                            (aggregated across all glaciers)
;   gmip4_temp[years*12 or years*365]      - temp over initial area [K]
;                                            (area-weighted across all glaciers)
;   gmip4_region        - RGI region number as integer (e.g. 1 for RGI01)
;   catchment_selection - catchment name string or '' for full region
;   GCM_model           - scalar GCM name string (e.g. 'MRI-ESM2-0')
;                         pass as GCM_model[gcms] from the GCM loop
;   GCM_rcp             - scalar SSP/scenario string (e.g. 'ssp126')
;                         pass as GCM_rcp[rcps] from the RCP loop
;   GCM_data            - dataset family string ('cmip6', 'cmip5', 'gmip4')
;                         written as global attribute only, not in file name
;   tran[2]             - modeling period [start_year, end_year]
;   years               - total number of years in the run
;   time_resolution     - 'monthly' or 'daily'
;   dirres              - base output directory path
; *************************************************************

compile_opt idl2

; --- File naming: handles full region and catchment selection ---
rgi_str = string(gmip4_region, format='(i02)')
gcm_tag = strtrim(GCM_model, 2) + '_' + strtrim(GCM_rcp, 2)

if catchment_selection eq '' then begin
    base_tag  = 'rgi' + rgi_str
    indiv_tag = 'rgi' + rgi_str + 'indiv'
endif else begin
    catch_str = strtrim(catchment_selection, 2)
    base_tag  = 'rgi' + rgi_str + '_' + catch_str
    indiv_tag = 'rgi' + rgi_str + '_' + catch_str + 'indiv'
endelse

outdir = dirres + 'GlacierMIP4' + path_sep()
if ~file_test(outdir, /directory) then file_mkdir, outdir

fn_ann   = outdir + 'GloGEM_' + base_tag  + '_' + gcm_tag + '_annual.nc'
fn_ann_i = outdir + 'GloGEM_' + indiv_tag + '_' + gcm_tag + '_annual.nc'

; --- Sub-annual time axis: monthly or daily ---
period_str = strtrim(string(tran[0]),2) + '-' + strtrim(string(tran[1]),2)
ref_jd     = julday(1, 1, 1850)
fv         = !VALUES.F_NAN

if time_resolution eq 'monthly' then begin
    n_sub     = years * 12
    sub_label = 'monthly'
    time_sub  = lonarr(n_sub)
    idx = 0L
    for yr = 0L, years-1L do $
        for mo = 1, 12 do begin
            time_sub[idx] = long(julday(mo, 1, tran[0]+yr) - ref_jd)
            idx++
        endfor
endif else begin
    n_sub     = years * 365
    sub_label = 'daily'
    time_sub  = lonarr(n_sub)
    for yr = 0L, years-1L do $
        for doy = 0, 364 do $
            time_sub[yr*365+doy] = long(julday(1, 1, tran[0]+yr) - ref_jd + doy)
endelse

fn_sub   = outdir + 'GloGEM_' + base_tag  + '_' + gcm_tag + '_' + sub_label + '.nc'
fn_sub_i = outdir + 'GloGEM_' + indiv_tag + '_' + gcm_tag + '_' + sub_label + '.nc'

; --- Annual time axis ---
time_ann = lonarr(years)
for yr = 0L, years-1L do $
    time_ann[yr] = long(julday(1, 1, tran[0]+yr) - ref_jd)

; --- Regional totals (sum over all glaciers) ---
reg_area        = float(total(gmip4_area,        1))
reg_mass        = float(total(gmip4_mass,        1))
reg_mass_bsl    = float(total(gmip4_mass_bsl,    1))
reg_frontal_abl = float(total(gmip4_frontal_abl, 1))
reg_acc         = float(total(gmip4_acc,         1))
reg_melt        = float(total(gmip4_melt,        1))
reg_refreeze    = float(total(gmip4_refreeze,    1))
reg_runoff      = float(total(gmip4_runoff,      1))
reg_precip      = float(gmip4_precip)
reg_temp        = float(gmip4_temp)

; ================================================================
; 1. REGIONAL ANNUAL FILE
; ================================================================
ncid = ncdf_create(fn_ann, /clobber, /netcdf4)

ncdf_attput, ncid, /global, 'Conventions',   'CF-1.8'
ncdf_attput, ncid, /global, 'model',         'GloGEM'
ncdf_attput, ncid, /global, 'institution',   'ETH, VAW'
ncdf_attput, ncid, /global, 'rgi_region',    rgi_str
ncdf_attput, ncid, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, ncid, /global, 'forcing',       gcm_tag
ncdf_attput, ncid, /global, 'gcm',           strtrim(GCM_model, 2)
ncdf_attput, ncid, /global, 'scenario',      strtrim(GCM_rcp, 2)
ncdf_attput, ncid, /global, 'gcm_data',     strtrim(GCM_data, 2)
ncdf_attput, ncid, /global, 'period',        period_str
ncdf_attput, ncid, /global, 'creation_date', systime()

t_dimid = ncdf_dimdef(ncid, 'time', years)

t_varid = ncdf_vardef(ncid, 'time', [t_dimid], /long)
ncdf_attput, ncid, t_varid, 'long_name',    'time'
ncdf_attput, ncid, t_varid, 'units',        'days since 1850-01-01'
ncdf_attput, ncid, t_varid, 'calendar',     'standard'
ncdf_attput, ncid, t_varid, 'cell_methods', 'time: point'

v_area = ncdf_vardef(ncid, 'area', [t_dimid], /float)
ncdf_attput, ncid, v_area, 'long_name',    'Glacier area'
ncdf_attput, ncid, v_area, 'units',        'm2'
ncdf_attput, ncid, v_area, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_area, '_FillValue',   fv

v_mass = ncdf_vardef(ncid, 'mass', [t_dimid], /float)
ncdf_attput, ncid, v_mass, 'long_name',    'Glacier mass'
ncdf_attput, ncid, v_mass, 'units',        'kg'
ncdf_attput, ncid, v_mass, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_mass, '_FillValue',   fv

v_mbsl = ncdf_vardef(ncid, 'mass_bsl', [t_dimid], /float)
ncdf_attput, ncid, v_mbsl, 'long_name',    'Glacier mass below sea level'
ncdf_attput, ncid, v_mbsl, 'units',        'kg'
ncdf_attput, ncid, v_mbsl, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_mbsl, '_FillValue',   fv

v_fabl = ncdf_vardef(ncid, 'frontal_abl', [t_dimid], /float)
ncdf_attput, ncid, v_fabl, 'long_name',    'Total annual frontal ablation'
ncdf_attput, ncid, v_fabl, 'units',        'kg'
ncdf_attput, ncid, v_fabl, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_fabl, '_FillValue',   fv

ncdf_control, ncid, /endef

ncdf_varput, ncid, t_varid, time_ann
ncdf_varput, ncid, v_area,  reg_area
ncdf_varput, ncid, v_mass,  reg_mass
ncdf_varput, ncid, v_mbsl,  reg_mass_bsl
ncdf_varput, ncid, v_fabl,  reg_frontal_abl

ncdf_close, ncid

; ================================================================
; 2. REGIONAL SUB-ANNUAL FILE (monthly or daily)
; ================================================================
ncid = ncdf_create(fn_sub, /clobber, /netcdf4)

ncdf_attput, ncid, /global, 'Conventions',   'CF-1.8'
ncdf_attput, ncid, /global, 'model',         'GloGEM'
ncdf_attput, ncid, /global, 'institution',   'ETH, VAW'
ncdf_attput, ncid, /global, 'rgi_region',    rgi_str
ncdf_attput, ncid, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, ncid, /global, 'forcing',       gcm_tag
ncdf_attput, ncid, /global, 'gcm',           strtrim(GCM_model, 2)
ncdf_attput, ncid, /global, 'scenario',      strtrim(GCM_rcp, 2)
ncdf_attput, ncid, /global, 'gcm_data',     strtrim(GCM_data, 2)
ncdf_attput, ncid, /global, 'time_resolution', sub_label
ncdf_attput, ncid, /global, 'period',        period_str
ncdf_attput, ncid, /global, 'creation_date', systime()

t_dimid = ncdf_dimdef(ncid, 'time', n_sub)

t_varid = ncdf_vardef(ncid, 'time', [t_dimid], /long)
ncdf_attput, ncid, t_varid, 'long_name',    'time'
ncdf_attput, ncid, t_varid, 'units',        'days since 1850-01-01'
ncdf_attput, ncid, t_varid, 'calendar',     'standard'
ncdf_attput, ncid, t_varid, 'cell_methods', 'time: point'

v_acc = ncdf_vardef(ncid, 'acc', [t_dimid], /float)
ncdf_attput, ncid, v_acc, 'long_name',    'Total accumulation'
ncdf_attput, ncid, v_acc, 'units',        'kg'
ncdf_attput, ncid, v_acc, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_acc, '_FillValue',   fv

v_melt = ncdf_vardef(ncid, 'melt', [t_dimid], /float)
ncdf_attput, ncid, v_melt, 'long_name',    'Total glacier melt (snow, ice, firn)'
ncdf_attput, ncid, v_melt, 'units',        'kg'
ncdf_attput, ncid, v_melt, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_melt, '_FillValue',   fv

v_refr = ncdf_vardef(ncid, 'refreeze', [t_dimid], /float)
ncdf_attput, ncid, v_refr, 'long_name',    'Total refreezing'
ncdf_attput, ncid, v_refr, 'units',        'kg'
ncdf_attput, ncid, v_refr, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_refr, '_FillValue',   fv

v_run = ncdf_vardef(ncid, 'runoff_glac', [t_dimid], /float)
ncdf_attput, ncid, v_run, 'long_name',    'Glacier runoff from glacierized area'
ncdf_attput, ncid, v_run, 'units',        'kg'
ncdf_attput, ncid, v_run, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_run, '_FillValue',   fv

v_prec = ncdf_vardef(ncid, 'precip', [t_dimid], /float)
ncdf_attput, ncid, v_prec, 'long_name',    'Total precipitation over initial glacierized area'
ncdf_attput, ncid, v_prec, 'units',        'kg'
ncdf_attput, ncid, v_prec, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_prec, '_FillValue',   fv

v_temp = ncdf_vardef(ncid, 'temp', [t_dimid], /float)
ncdf_attput, ncid, v_temp, 'long_name',    'Near-surface air temperature over initial glacierized area'
ncdf_attput, ncid, v_temp, 'units',        'K'
ncdf_attput, ncid, v_temp, 'cell_methods', 'time: mean'
ncdf_attput, ncid, v_temp, '_FillValue',   fv

ncdf_control, ncid, /endef

ncdf_varput, ncid, t_varid, time_sub
ncdf_varput, ncid, v_acc,   reg_acc
ncdf_varput, ncid, v_melt,  reg_melt
ncdf_varput, ncid, v_refr,  reg_refreeze
ncdf_varput, ncid, v_run,   reg_runoff
ncdf_varput, ncid, v_prec,  reg_precip
ncdf_varput, ncid, v_temp,  reg_temp

ncdf_close, ncid

; ================================================================
; 3. INDIVIDUAL ANNUAL FILE
; ================================================================
ncid = ncdf_create(fn_ann_i, /clobber, /netcdf4)

ncdf_attput, ncid, /global, 'Conventions',   'CF-1.8'
ncdf_attput, ncid, /global, 'model',         'GloGEM'
ncdf_attput, ncid, /global, 'institution',   'ETH, VAW'
ncdf_attput, ncid, /global, 'rgi_region',    rgi_str
ncdf_attput, ncid, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, ncid, /global, 'forcing',       gcm_tag
ncdf_attput, ncid, /global, 'gcm',           strtrim(GCM_model, 2)
ncdf_attput, ncid, /global, 'scenario',      strtrim(GCM_rcp, 2)
ncdf_attput, ncid, /global, 'gcm_data',     strtrim(GCM_data, 2)
ncdf_attput, ncid, /global, 'period',        period_str
ncdf_attput, ncid, /global, 'creation_date', systime()

t_dimid = ncdf_dimdef(ncid, 'time',    years)
g_dimid = ncdf_dimdef(ncid, 'glacier', gmip4_ng)

v_rgid = ncdf_vardef(ncid, 'RGIId', [g_dimid], /string)
ncdf_attput, ncid, v_rgid, 'long_name', 'Randolph Glacier Inventory ID'

t_varid = ncdf_vardef(ncid, 'time', [t_dimid], /long)
ncdf_attput, ncid, t_varid, 'long_name',    'time'
ncdf_attput, ncid, t_varid, 'units',        'days since 1850-01-01'
ncdf_attput, ncid, t_varid, 'calendar',     'standard'
ncdf_attput, ncid, t_varid, 'cell_methods', 'time: point'

v_area = ncdf_vardef(ncid, 'area', [g_dimid, t_dimid], /float)
ncdf_attput, ncid, v_area, 'long_name',    'Glacier area'
ncdf_attput, ncid, v_area, 'units',        'm2'
ncdf_attput, ncid, v_area, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_area, '_FillValue',   fv

v_mass = ncdf_vardef(ncid, 'mass', [g_dimid, t_dimid], /float)
ncdf_attput, ncid, v_mass, 'long_name',    'Glacier mass'
ncdf_attput, ncid, v_mass, 'units',        'kg'
ncdf_attput, ncid, v_mass, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_mass, '_FillValue',   fv

v_mbsl = ncdf_vardef(ncid, 'mass_bsl', [g_dimid, t_dimid], /float)
ncdf_attput, ncid, v_mbsl, 'long_name',    'Glacier mass below sea level'
ncdf_attput, ncid, v_mbsl, 'units',        'kg'
ncdf_attput, ncid, v_mbsl, 'cell_methods', 'time: point'
ncdf_attput, ncid, v_mbsl, '_FillValue',   fv

v_fabl = ncdf_vardef(ncid, 'frontal_abl', [g_dimid, t_dimid], /float)
ncdf_attput, ncid, v_fabl, 'long_name',    'Total annual frontal ablation'
ncdf_attput, ncid, v_fabl, 'units',        'kg'
ncdf_attput, ncid, v_fabl, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_fabl, '_FillValue',   fv

ncdf_control, ncid, /endef

ncdf_varput, ncid, v_rgid,  gmip4_rgiids
ncdf_varput, ncid, t_varid, time_ann
ncdf_varput, ncid, v_area,  float(gmip4_area)
ncdf_varput, ncid, v_mass,  float(gmip4_mass)
ncdf_varput, ncid, v_mbsl,  float(gmip4_mass_bsl)
ncdf_varput, ncid, v_fabl,  float(gmip4_frontal_abl)

ncdf_close, ncid

; ================================================================
; 4. INDIVIDUAL SUB-ANNUAL FILE (runoff_glac only, monthly or daily)
; ================================================================
ncid = ncdf_create(fn_sub_i, /clobber, /netcdf4)

ncdf_attput, ncid, /global, 'Conventions',   'CF-1.8'
ncdf_attput, ncid, /global, 'model',         'GloGEM'
ncdf_attput, ncid, /global, 'institution',   'ETH, VAW'
ncdf_attput, ncid, /global, 'rgi_region',    rgi_str
ncdf_attput, ncid, /global, 'catchment',     strtrim(catchment_selection, 2)
ncdf_attput, ncid, /global, 'forcing',       gcm_tag
ncdf_attput, ncid, /global, 'gcm',           strtrim(GCM_model, 2)
ncdf_attput, ncid, /global, 'scenario',      strtrim(GCM_rcp, 2)
ncdf_attput, ncid, /global, 'gcm_data',     strtrim(GCM_data, 2)
ncdf_attput, ncid, /global, 'time_resolution', sub_label
ncdf_attput, ncid, /global, 'period',        period_str
ncdf_attput, ncid, /global, 'creation_date', systime()

t_dimid = ncdf_dimdef(ncid, 'time',    n_sub)
g_dimid = ncdf_dimdef(ncid, 'glacier', gmip4_ng)

v_rgid = ncdf_vardef(ncid, 'RGIId', [g_dimid], /string)
ncdf_attput, ncid, v_rgid, 'long_name', 'Randolph Glacier Inventory ID'

t_varid = ncdf_vardef(ncid, 'time', [t_dimid], /long)
ncdf_attput, ncid, t_varid, 'long_name',    'time'
ncdf_attput, ncid, t_varid, 'units',        'days since 1850-01-01'
ncdf_attput, ncid, t_varid, 'calendar',     'standard'
ncdf_attput, ncid, t_varid, 'cell_methods', 'time: point'

v_run = ncdf_vardef(ncid, 'runoff_glac', [g_dimid, t_dimid], /float)
ncdf_attput, ncid, v_run, 'long_name',    'Glacier runoff from glacierized area'
ncdf_attput, ncid, v_run, 'units',        'kg'
ncdf_attput, ncid, v_run, 'cell_methods', 'time: sum'
ncdf_attput, ncid, v_run, '_FillValue',   fv

ncdf_control, ncid, /endef

ncdf_varput, ncid, v_rgid,  gmip4_rgiids
ncdf_varput, ncid, t_varid, time_sub
ncdf_varput, ncid, v_run,   float(gmip4_runoff)

ncdf_close, ncid
