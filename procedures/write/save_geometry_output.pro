; save_geometry_output.pro
;
; Called once per year (inside the ye loop) when write_geometry_output is 'y' or 'flow'.
; Accumulates per-band geometry arrays and, on the final year, writes them
; to a .sav file ('y' only).  If the flow model was active it also saves the flowline
; grid history. With geometry_output_every > 1 both keep only the years divisible by it
; and the last year, in single precision, compressed.
;
; Variables read from the calling scope (glogem.pro):
;   ye, years, tran, nb, thick, elev, bed_elev, width, area, bal, length,
;   volumes, areas, mb, id, gg, g, dirres, dir_region, time_resolution,
;   geom_output_path_b (set in prepare_output_mb_in_bins.pro -- NOT b
;   itself, which is clobbered by meltmodel.pro's unrelated scratch use of
;   the same name every month), GCM_model, gcms, GCM_rcp, rcps, use_flow_model,
;   flow_thick_hist, flow_sur_hist, flow_bal_hist, flow_width_hist,
;   bed_dx, dist_dx, dx, xnum, spinup_aflow, spinup_ela_bias, thick_dx

; initialise history arrays on first year
if ye eq 0 and write_geometry_output eq 'y' then begin
  thick_hist        = dblarr(nb, years)
  elev_hist         = dblarr(nb, years)
  bed_elev_hist     = dblarr(nb, years)
  width_hist        = dblarr(nb, years)
  area_hist         = dblarr(nb, years)
  bal_hist          = dblarr(nb, years)
  length_hist_bands = dblarr(nb, years)
endif
if ye eq 0 then begin
  year_hist         = lonarr(years)
  vol_hist          = dblarr(years)
  area_total_hist   = dblarr(years)
  mb_hist           = dblarr(years)
endif

; accumulate this year's values
if write_geometry_output eq 'y' then begin
  thick_hist[*, ye]        = reform(thick)
  elev_hist[*, ye]         = reform(elev)
  bed_elev_hist[*, ye]     = reform(bed_elev)
  width_hist[*, ye]        = reform(width)
  area_hist[*, ye]         = reform(area)
  bal_hist[*, ye]          = reform(bal)
  length_hist_bands[*, ye] = reform(length)
endif
year_hist[ye]            = ye + tran[0]
vol_hist[ye]             = volumes[ye]
area_total_hist[ye]      = areas[ye]
mb_hist[ye]              = mb[ye]

; on last year: write to disk
if ye eq years-1 then begin
  scenario_tag = 'dhdt'
  if use_flow_model eq 'y' then scenario_tag = 'flow'

  ; Same path convention as prepare_output_firnicetemp.pro -- rebuilt here from the run
  ; flags rather than inherited through the scratch variable b.
  ;
  ; This previously used geom_output_path_b, captured from b in prepare_output_mb_in_bins.pro.
  ; That capture is itself too late: meltmodel.pro reuses the name b as a numeric scratch
  ; every month, so from the SECOND glacier of a run onward geom_output_path_b held a number,
  ; not a path -- "Type conversion error: Unable to convert given STRING to Double" followed by
  ; "FILE_TEST: String expression required", which halted the whole run after glacier 1.
  ; And on the first glacier b still held setup_output_folders.pro's '/'+date_str+'/' for any
  ; run ending after 2025, so the .sav landed in a timestamped directory instead of alongside
  ; the other per-scenario output. Rebuilding the path fixes both.
  if single_glacier ne '' then begin
    geom_subpath = '/files/files_original/SINGLE'
  endif else if reanalysis_direct eq 'y' then begin
    geom_subpath = '/PAST' + version_past + mtt
  endif else begin
    geom_subpath = '/files' + mtt + '/' + GCM_model[gcms] + '/' + GCM_rcp[rcps]
  endelse
  out_dir = dirres + time_resolution + '/' + dir_region + geom_subpath + '/geometry'
  if ~file_test(out_dir, /directory) then spawn, 'mkdir -p "' + out_dir + '"'

  ; years written: all, or every geometry_output_every-th year and the last (single precision)
  geo_thin = geometry_output_every gt 1
  if geo_thin then geo_k = where(year_hist mod geometry_output_every eq 0 or lindgen(years) eq years - 1) $
  else geo_k = lindgen(years)
  year_out = year_hist[geo_k] & vol_out = vol_hist[geo_k] & area_out = area_total_hist[geo_k] & mb_out = mb_hist[geo_k]
  if geo_thin then begin
    vol_out = float(vol_out) & area_out = float(area_out) & mb_out = float(mb_out)
  endif

  if write_geometry_output eq 'y' then begin
    geometry_hist = { $
      thick:      thick_hist, $
      elev:       elev_hist, $
      bed_elev:   bed_elev_hist, $
      width:      width_hist, $
      area:       area_hist, $
      bal:        bal_hist, $
      length:     length_hist_bands, $
      years:      year_hist, $
      volume:     vol_hist, $
      area_total: area_total_hist, $
      mb:         mb_hist, $
      glacier_id: id[gg[g]], $
      scenario:   scenario_tag, $
      gcm:        GCM_model[gcms], $
      rcp:        GCM_rcp[rcps], $
      nb:         nb $
    }
    save_file = out_dir + '/geometry_' + id[gg[g]] + '_' + scenario_tag + '.sav'
    if geo_thin then begin
      geometry_hist = { $
        thick: float(thick_hist[*, geo_k]), elev: float(elev_hist[*, geo_k]), $
        bed_elev: float(bed_elev_hist[*, geo_k]), width: float(width_hist[*, geo_k]), $
        area: float(area_hist[*, geo_k]), bal: float(bal_hist[*, geo_k]), $
        length: float(length_hist_bands[*, geo_k]), years: year_out, volume: vol_out, $
        area_total: area_out, mb: mb_out, glacier_id: id[gg[g]], scenario: scenario_tag, $
        gcm: GCM_model[gcms], rcp: GCM_rcp[rcps], nb: nb }
      save, geometry_hist, file=save_file, /compress
    endif else save, geometry_hist, file=save_file
  endif

  ; only glaciers that ran the flow model: thick_dx of an earlier glacier survives in the session
  if use_flow_model eq 'y' and n_elements(flow_initialised) gt 0 then begin
    flow_hist = { $
      thick:           flow_thick_hist, $
      sur:             flow_sur_hist, $
      bal:             flow_bal_hist, $
      width:           flow_width_hist, $
      bed_dx:          bed_dx, $
      dist_dx:         dist_dx, $
      dx:              dx, $
      xnum:            xnum, $
      years:           year_hist, $
      volume:          vol_hist, $
      area_total:      area_total_hist, $
      mb:              mb_hist, $
      glacier_id:      id[gg[g]], $
      scenario:        'flow', $
      gcm:             GCM_model[gcms], $
      rcp:             GCM_rcp[rcps], $
      spinup_aflow:    (n_elements(spinup_aflow) gt 0 ? spinup_aflow : !values.d_nan), $
      spinup_ela_bias: (n_elements(spinup_ela_bias) gt 0 ? spinup_ela_bias : 0d0) $
    }
    save_file_flow = out_dir + '/flowgrid_' + id[gg[g]] + '_' + scenario_tag + '.sav'
    if geo_thin then begin
      flow_hist = { $
        thick: float(flow_thick_hist[*, geo_k]), sur: float(flow_sur_hist[*, geo_k]), $
        bal: float(flow_bal_hist[*, geo_k]), width: float(flow_width_hist[*, geo_k]), $
        bed_dx: bed_dx, dist_dx: dist_dx, dx: dx, xnum: xnum, years: year_out, volume: vol_out, $
        area_total: area_out, mb: mb_out, glacier_id: id[gg[g]], scenario: 'flow', $
        gcm: GCM_model[gcms], rcp: GCM_rcp[rcps], $
        spinup_aflow: (n_elements(spinup_aflow) gt 0 ? spinup_aflow : !values.d_nan), $
        spinup_ela_bias: (n_elements(spinup_ela_bias) gt 0 ? spinup_ela_bias : 0d0) }
      save, flow_hist, file=save_file_flow, /compress
    endif else save, flow_hist, file=save_file_flow
  endif
endif
