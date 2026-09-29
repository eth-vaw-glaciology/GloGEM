; *************************************************************
; limit_glacier_growth
;
; Runtime bound on glacier size, applied every year to every glacier
; on BOTH geometry paths (flow model and Δh parameterisation).
;
; Neither path limits how large a glacier may become: the Δh advance
; scheme grows area and thickness together with no upper bound, and the
; mass-conservation guard only checks that the change matches the mass
; balance, not that the result is physically possible. Until this
; procedure existed the only thing catching a blow-up was
; check_gmip4_output.py, run days after the campaign.
;
; Thresholds are those of check_gmip4_output.py, so a glacier this
; clamps is exactly one the post-hoc gate would have flagged.
;
; The limit only removes ice: it thins the glacier by one factor and
; keeps its area. In a flow-model year it measures and thins the
; flowline (called before update_elevation_bands rebuilds the bands
; from it); otherwise the elevation bands. The removed ice is booked as
; ice melt of this year (annual balance and ice melt; monthly melt,
; balance and glacier runoff), so volume change = balance - frontal
; ablation still holds.
; *************************************************************

compile_opt idl2

; the flowline is the glacier in a flow-model year, the bands otherwise
lg_flow = use_flow_model_gl eq 'y' and n_elements(flow_initialised) gt 0
if lg_flow then begin
  lg_ii = where(thick_dx gt 0, lg_ci)
  if lg_ci gt 0 then begin
    lg_vol = total(thick_dx[lg_ii] * width_mid_dx[lg_ii]) * dx / 1d9      ; km3
    lg_area = total(width_surface_dx[lg_ii]) * dx / 1d6                  ; km2
  endif
endif else begin
  lg_ii = where(thick gt 0, lg_ci)
  if lg_ci gt 0 then begin
    lg_area = total(area[lg_ii])                           ; km2
    lg_vol = total(area[lg_ii] * thick[lg_ii]) / 1000.d0   ; km3
  endif
endelse

if lg_ci gt 0 then begin

  if lg_area gt 0 then lg_hmean = lg_vol * 1000.d0 / lg_area else lg_hmean = 0.d0

  ; absurd mean thickness, or a large volume that is also a huge multiple
  ; of the inventory (the pair keeps legitimate small-remnant regrowth safe)
  lg_hit = 0
  if lg_hmean gt growth_max_thick then lg_hit = 1
  if lg_vol gt growth_max_vol and volume0 gt 0 and lg_vol gt growth_max_rel * volume0 then lg_hit = 1

  if lg_hit then begin
    lg_scale = lg_hmean gt 0 ? (growth_max_thick / lg_hmean) < 1.d0 : 1.d0
    if volume0 gt 0 and lg_vol gt growth_max_vol then $
      lg_scale = lg_scale < ((growth_max_rel * volume0) / lg_vol)

    ; thin the ice, keep the area
    if lg_flow then begin
      thick_dx = thick_dx * lg_scale
      sur_dx = bed_dx + thick_dx
      width_surface_dx = width_base_dx + lambda_dx * thick_dx
      width_mid_dx = (width_base_dx + width_surface_dx) / 2d0
      flow_thick_hist[*, ye] = thick_dx
      flow_sur_hist[*, ye] = sur_dx
      flow_width_hist[*, ye] = width_surface_dx
      lg_vol1 = total(thick_dx[lg_ii] * width_mid_dx[lg_ii]) * dx / 1d9
    endif else begin
      thick[lg_ii] = thick[lg_ii] * lg_scale
      elev[lg_ii] = bed_elev[lg_ii] + thick[lg_ii]
      lg_vol1 = total(area[lg_ii] * thick[lg_ii]) / 1000.d0
    endelse
    lg_rm = (lg_vol - lg_vol1) > 0d0   ; km3 ice removed

    ; removed ice as ice melt, specific to areas[ye] like every flux of the year
    if lg_rm gt 0 and areas[ye] gt 0 then begin
      lg_we = lg_rm * 900d0 / areas[ye]   ; m w.e.
      mb[ye] = mb[ye] - lg_we
      imelt[ye] = imelt[ye] + lg_we
      if time_resolution eq 'monthly' and outf_names[14] ne '' then begin
        lg_k = ye * 12L + lindgen(12)
        lg_ok = where(finite(melmo[lg_k]) and melmo[lg_k] ne snoval and $
                      finite(balmo[lg_k]) and finite(discharge_gl[lg_k]), lg_cok)
        if lg_cok gt 0 then begin
          lg_k = lg_k[lg_ok]
          ; spread like this year's melt, evenly if there was none
          lg_s = total(melmo[lg_k] > 0d0)
          if lg_s gt 0 then lg_add = (melmo[lg_k] > 0d0) * (lg_we / lg_s) $
          else lg_add = dblarr(lg_cok) + lg_we / lg_cok
          melmo[lg_k] = melmo[lg_k] + lg_add
          balmo[lg_k] = balmo[lg_k] - lg_add
          discharge_gl[lg_k] = discharge_gl[lg_k] + lg_add
        endif
      endif
    endif

    print, 'WARNING: growth limit hit, glacier ' + strtrim(id[gg[g]], 2) + $
      ' year ' + strtrim(ye + tran[0], 2) + ': ' + $
      strtrim(string(lg_vol, fo='(f10.3)'), 2) + ' km3, mean thickness ' + $
      strtrim(string(lg_hmean, fo='(f9.1)'), 2) + ' m (inventory ' + $
      strtrim(string(volume0, fo='(f10.4)'), 2) + ' km3) -- clamped by factor ' + $
      strtrim(string(lg_scale, fo='(f6.3)'), 2) + ', ' + $
      strtrim(string(lg_rm, fo='(e10.3)'), 2) + ' km3 removed as ice melt (' + $
      (lg_flow ? 'flow model' : 'Δh parameterisation') + ')'

    n_growth_clamped = n_growth_clamped + 1
    growth_removed_gt = growth_removed_gt + lg_rm * 0.9d0
  endif
endif
