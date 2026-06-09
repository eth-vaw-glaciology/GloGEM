; *************************************************************
; setup_grid_loops
;
; Determine grid loop bounds and dimensions.
;
; Calculates the lon/lat bounding box from the glacier inventory,
; narrows it to a single glacier if requested, then computes the
; number of grid cells (ngx, ngy) for the spatial loop.
; *************************************************************

compile_opt idl2

; determine the range of glaciers that are covered in region
if clim_subregion eq '' then begin
  lon0 = [fix(min(lon_gl) / grid_step) * grid_step - grid_step / 2., fix(max(lon_gl) / grid_step) * grid_step + grid_step / 2. + 2 * grid_step]
  lat0 = [fix(min(lat_gl) / grid_step) * grid_step - grid_step / 2., fix(max(lat_gl) / grid_step) * grid_step + grid_step / 2. + 2 * grid_step]
endif

if single_glacier ne '' then begin
  gg = where(id eq single_glacier, cg)
  if cg gt 0 then begin
    lon0 = [fix(min(lon_gl[gg]) / grid_step) * grid_step - grid_step / 2., fix(max(lon_gl[gg]) / grid_step) * grid_step + grid_step / 2.]
    lat0 = [fix(min(lat_gl[gg]) / grid_step) * grid_step - grid_step / 2., fix(max(lat_gl[gg]) / grid_step) * grid_step + grid_step / 2.]
  endif
endif

if grid_run eq 'n' then begin
  ngx = 1
  ngy = 1
  lat = lat0
  lon = lon0
endif else begin
  ngx = fix((lon0[1] - lon0[0]) / grid_step)
  ngy = fix((lat0[1] - lat0[0]) / grid_step)
  if ngx lt 1 then ngx = 1
  if ngy lt 1 then ngy = 1
endelse
