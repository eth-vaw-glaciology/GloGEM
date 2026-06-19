; save_geometry_output.pro
;
; Called once per year (inside the ye loop) when write_geometry_output='y'.
; Accumulates per-band geometry arrays and, on the final year, writes them
; to a .sav file.  If the flow model was active it also saves the flowline
; grid history.
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
if ye eq 0 then begin
  thick_hist        = dblarr(nb, years)
  elev_hist         = dblarr(nb, years)
  bed_elev_hist     = dblarr(nb, years)
  width_hist        = dblarr(nb, years)
  area_hist         = dblarr(nb, years)
  bal_hist          = dblarr(nb, years)
  length_hist_bands = dblarr(nb, years)
  year_hist         = lonarr(years)
  vol_hist          = dblarr(years)
  area_total_hist   = dblarr(years)
  mb_hist           = dblarr(years)
endif

; accumulate this year's values
thick_hist[*, ye]        = reform(thick)
elev_hist[*, ye]         = reform(elev)
bed_elev_hist[*, ye]     = reform(bed_elev)
width_hist[*, ye]        = reform(width)
area_hist[*, ye]         = reform(area)
bal_hist[*, ye]          = reform(bal)
length_hist_bands[*, ye] = reform(length)
year_hist[ye]            = ye + tran[0]
vol_hist[ye]             = volumes[ye]
area_total_hist[ye]      = areas[ye]
mb_hist[ye]              = mb[ye]

; on last year: write to disk
if ye eq years-1 then begin
  scenario_tag = 'dhdt'
  if use_flow_model eq 'y' then scenario_tag = 'flow'

  ; Same path convention as prepare_output_firnicetemp.pro / prepare_output_mb_in_bins.pro.
  ; Uses geom_output_path_b (captured in prepare_output_mb_in_bins.pro right
  ; after it computes b) rather than b itself -- by this point in the year
  ; loop, b has been overwritten with an unrelated numeric value by
  ; meltmodel.pro (which reuses the name "b" as a scratch variable every
  ; month), so the original path string is long gone from b itself.
  out_dir = dirres + '/' + time_resolution + '/' + dir_region + geom_output_path_b + '/geometry'
  if ~file_test(out_dir, /directory) then spawn, 'mkdir -p "' + out_dir + '"'

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
  save, geometry_hist, file=save_file

  if use_flow_model eq 'y' and n_elements(thick_dx) gt 0 then begin
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
    save, flow_hist, file=save_file_flow
  endif
endif
