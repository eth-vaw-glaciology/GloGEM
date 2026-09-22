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
; *************************************************************

compile_opt idl2

lg_ii = where(thick gt 0, lg_ci)
if lg_ci gt 0 then begin

  lg_area = total(area[lg_ii])                  ; km2
  lg_vol = total(area[lg_ii] * thick[lg_ii]) / 1000.d0   ; km3
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

    print, 'WARNING: growth limit hit, glacier ' + strtrim(id[gg[g]], 2) + $
      ' year ' + strtrim(ye + tran[0], 2) + ': ' + $
      strtrim(string(lg_vol, fo='(f10.3)'), 2) + ' km3, mean thickness ' + $
      strtrim(string(lg_hmean, fo='(f9.1)'), 2) + ' m (inventory ' + $
      strtrim(string(volume0, fo='(f10.4)'), 2) + ' km3) -- clamped by factor ' + $
      strtrim(string(lg_scale, fo='(f6.3)'), 2)

    thick[lg_ii] = thick[lg_ii] * lg_scale
    lg_jj = where(thick_ini[lg_ii] gt 0, lg_cj)
    if lg_cj gt 0 then area[lg_ii[lg_jj]] = area_ini[lg_ii[lg_jj]] * $
      (thick[lg_ii[lg_jj]] / thick_ini[lg_ii[lg_jj]]) ^ (1.d0 / expon)
    elev[lg_ii] = bed_elev[lg_ii] + thick[lg_ii]
    volumes[ye] = total(area * thick) / 1000.d0
    areas[ye] = total(area)
    n_growth_clamped = n_growth_clamped + 1
  endif
endif
