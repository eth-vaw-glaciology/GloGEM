; -----------------------------------------------------------------------
; sync_bands_thickness
;
; Synchronize GloGEM's band-level thick[] from the current flowline
; geometry. Called once, when a flow-model glacier permanently falls back
; to the Δh parameterisation (blow-up) -- update_elevation_bands.pro never
; writes thick[] (only area[j], gl[j], width[j], elev[j]), so
; glacier_retreat.pro would otherwise inherit a stale thick[] (frozen since
; before the flow model started) inconsistent with the already-current
; area[]/elev[]. Mirrors the same sort-by-surface-elevation + interpol()
; pattern already used for width in update_elevation_bands.pro.
;
; Inputs  (GloGEM scope) : elev[nb], gl[nb], noval, nb
; Inputs  (flow scope)   : sur_dx[xnum], thick_dx[xnum]
; Modifies (GloGEM scope): thick[j]
; -----------------------------------------------------------------------
compile_opt idl2

ii_ice_sync = where(thick_dx gt 0d0, n_ice_sync)

if n_ice_sync ge 2l then begin
  srt_sync          = sort(sur_dx[ii_ice_sync])
  sur_sorted_sync   = sur_dx[ii_ice_sync[srt_sync]]
  thick_sorted_sync = thick_dx[ii_ice_sync[srt_sync]]

  elev_min_sync = sur_sorted_sync[0]
  elev_max_sync = sur_sorted_sync[n_ice_sync - 1l]

  for j = 0l, nb - 1l do begin
    if gl[j] ne noval and elev[j] ge elev_min_sync and elev[j] le elev_max_sync then $
      thick[j] = interpol(thick_sorted_sync, sur_sorted_sync, elev[j]) > 0d0
  endfor
endif
