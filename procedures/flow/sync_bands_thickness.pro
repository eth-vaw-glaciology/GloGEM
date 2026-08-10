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
; Bands with thick_ini[j]=0 (never part of the original inventory-date
; elevation-band footprint) are deliberately skipped: glacier_retreat.pro's
; area-thickness scaling is area_ini*(thick/thick_ini)^(1/expon), which
; divides by thick_ini and is undefined for a zero reference. Confirmed via
; live debugging that the flow model's 1D flowline geometry does reach a
; handful of such bands for large ice caps (Iceland glacier 00375: 10 of
; ~250 bands) -- the flowline is a coarser, 1D simplification of the
; elevation-band footprint and doesn't respect its exact boundary. Writing
; thick[j] there produced X/0 in glacier_retreat.pro, which silently
; propagated to Infinity/NaN in area[]/thick[]/volumes[ye] for the rest of
; the run once Δh parameterisation took over. Excluding these few bands from
; the sync discards a small, bounded amount of ice (bounded by how much the
; flowline extended past the original footprint) in exchange for a
; numerically safe handoff.
;
; Inputs  (GloGEM scope) : elev[nb], gl[nb], thick_ini[nb], noval, nb
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

  n_skipped_noref = 0l
  for j = 0l, nb - 1l do begin
    if gl[j] ne noval and elev[j] ge elev_min_sync and elev[j] le elev_max_sync then begin
      if thick_ini[j] gt 0d0 then begin
        thick[j] = interpol(thick_sorted_sync, sur_sorted_sync, elev[j]) > 0d0
      endif else begin
        n_skipped_noref = n_skipped_noref + 1l
      endelse
    endif
  endfor
  if n_skipped_noref gt 0 then $
    print, '  sync_bands_thickness: skipped ' + strtrim(n_skipped_noref, 2) + $
      ' band(s) outside the original inventory footprint (thick_ini=0) -- ' + $
      'left ice-free rather than dividing by zero in glacier_retreat.pro.'
endif
