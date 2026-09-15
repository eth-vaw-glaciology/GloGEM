; -----------------------------------------------------------------------
; sync_bands_thickness
;
; Rebuild GloGEM's band-level thick[] from the current flowline geometry,
; so thick[] is consistent with the area[]/gl[]/elev[] that
; update_elevation_bands.pro maintains from the same flowline state.
;
; Called (1) every flow-model year, at the end of update_elevation_bands.pro,
; and (2) when a flow-model glacier permanently falls back to the Δh
; parameterisation (blow-up or non-finite MB) in glogemflow_coupled.pro.
;
; Rule: a band carries ice only where the flowline carries ice.
;   * bands inside the surface-elevation span of the ice-covered flowline
;     cells (exactly the bands update_elevation_bands keeps active) get
;     thick[j] interpolated from the flowline -- the same sort-by-surface-
;     elevation + interpol() pattern used there for width;
;   * every other band gets thick[j] = 0 (its area[j] is already 0);
;   * with fewer than 2 ice-covered cells (flowline melted out) every band
;     gets 0.
;
; Why the zeroing matters (found 2026-09-08): before this, nothing in the
; flow path ever wrote thick[], so bands outside the flowline's span kept
; their inventory-date thickness for decades while their area[] was 0.
; Harmless while the flow model runs (volumes/areas come from the
; flowline), but glacier_retreat.pro selects bands with `thick gt 0` and
; rebuilds their area as area_ini*(thick/thick_ini)^(1/expon). So in the
; first Δh year after a fallback, a glacier that had melted to 0.005 km2
; was resurrected with its full inventory hypsometry and the advance
; scheme then ran away on that inconsistent state: SouthAsiaEast 01184 /
; IPSL-CM6A-LR / ssp585 went 0.00006 -> 434 km3 in one year (2096),
; ArcticCanadaN 02567 / MRI-ESM2-0 / ssp126 0.0009 -> 4486 km3 (2081);
; 19,396 glacier-runs in 7 regions were affected. The same glaciers in
; the pure-Δh model (main branch) melt out and stay out. Verified on
; instrumented single-glacier runs (_debug_GloGEM, 2026-09-08): with this
; sync 01184 melts out in 2099 and stays at zero to 2300, exactly like
; the pure-Δh run; every flow-model year before the handover is unchanged.
;
; Bands with thick_ini[j]=0 (never part of the inventory-date footprint)
; are never given ice: glacier_retreat.pro divides by thick_ini. The 1D
; flowline can extend past the band footprint (Iceland 00375: 10 of ~250
; bands); the small amount of ice there is dropped at the handover in
; exchange for a numerically safe state. At the handover such a band is
; also deactivated (area 0, gl noval) so Δh does not inherit a band with
; area but no ice; during flow years area/gl stay as update_elevation_bands
; set them, so the flow model's MB sampling is untouched.
;
; Inputs  (GloGEM scope) : elev[nb], gl[nb], thick_ini[nb], noval, nb,
;                          flow_blown_up (1 only at the Δh handover)
; Inputs  (flow scope)   : sur_dx[xnum], thick_dx[xnum]
; Modifies (GloGEM scope): thick[j]; at the handover also area[j], gl[j]
;                          of thick_ini=0 bands
; -----------------------------------------------------------------------
compile_opt idl2

ii_ice_sync = where(thick_dx gt 0d0, n_ice_sync)

if n_ice_sync ge 2l then begin
  srt_sync          = sort(sur_dx[ii_ice_sync])
  sur_sorted_sync   = sur_dx[ii_ice_sync[srt_sync]]
  thick_sorted_sync = thick_dx[ii_ice_sync[srt_sync]]

  elev_min_sync = sur_sorted_sync[0]
  elev_max_sync = sur_sorted_sync[n_ice_sync - 1l]

  n_skipped_noref = 0l
  for j = 0l, nb - 1l do begin
    if gl[j] ne noval and elev[j] ge elev_min_sync and elev[j] le elev_max_sync then begin
      if thick_ini[j] gt 0d0 then begin
        thick[j] = interpol(thick_sorted_sync, sur_sorted_sync, elev[j]) > 0d0
      endif else begin
        thick[j] = 0d0
        n_skipped_noref = n_skipped_noref + 1l
        if flow_blown_up then begin
          area[j] = 0d0
          gl[j]   = noval
        endif
      endelse
    endif else begin
      thick[j] = 0d0   ; no flowline ice at this elevation -- area[j] is 0 as well
    endelse
  endfor
  if flow_blown_up and n_skipped_noref gt 0 then $
    print, '  sync_bands_thickness: ' + strtrim(n_skipped_noref, 2) + $
      ' band(s) inside the flowline span but outside the inventory footprint (thick_ini=0) ' + $
      'left ice-free and deactivated for the Δh handover.'
endif else begin
  ; Flowline melted out (fewer than 2 ice cells): nothing to interpolate,
  ; and update_elevation_bands has already deactivated every band.
  thick[*] = 0d0
  if flow_blown_up then $
    print, '  sync_bands_thickness: flowline melted out (' + strtrim(n_ice_sync, 2) + $
      ' ice cell(s)) -- all band thick[] zeroed for the Δh handover.'
endelse
