; -----------------------------------------------------------------------
; update_elevation_bands
;
; Rebuild GloGEM's elevation-band arrays from the flowline geometry
; after each SIA time step. Called from glogem.pro immediately after
; @procedures/flow/glogemflow_coupled.
;
; Interpolates width (and local slope, to convert width into an area
; increment) as continuous functions of surface elevation from the
; flowline's ice-covered cells onto each elevation band, instead of
; binning flowline cells into their nearest band. Nearest-cell binning
; leaves many bands with zero cells whenever xnum (flowline cells) is
; much smaller than nb (elevation bands) — e.g. Aletsch has ~125
; flowline cells but ~254 10 m elevation bands — deactivating those
; bands (gl[j]=noval) even though the glacier surface genuinely passes
; through that elevation. Which bands get hit shifts every year as
; geometry evolves, producing band on/off flicker that propagates into
; the firn/ice temperature output and into the velocity mapped for
; advection (see glogemflow_coupled.pro STEP 7, same fix applied there).
;
; Bands outside the flowline's currently ice-covered elevation range
; are deactivated (gl[j]=noval) -- this is real retreat/advance, not
; a mapping artifact.
;
; elev[j] is NOT updated in this version to avoid inter-band cell
; migration. The elevation-feedback term will be added once the coupled
; run is validated as numerically stable.
;
; Inputs  (GloGEM scope) : elev[nb], step, nb, noval
; Inputs  (flow scope)   : sur_dx[xnum], thick_dx[xnum],
;                          width_surface_dx[xnum], dx, xnum
; Modifies (GloGEM scope): area[j], gl[j], width[j]
; -----------------------------------------------------------------------
compile_opt idl2

ii_ice = where(thick_dx gt 0d0, n_ice)

if n_ice ge 2l then begin
  ; Sort ice-covered cells by surface elevation (interpol requires
  ; a monotonically increasing abscissa)
  srt = sort(sur_dx[ii_ice])
  sur_sorted   = sur_dx[ii_ice[srt]]
  width_sorted = width_surface_dx[ii_ice[srt]]

  ; Local along-flow elevation gradient (= tan(slope)) at every flowline
  ; cell, from the same centred-difference used elsewhere (e.g.
  ; ice_thickness.pro); recomputed here from the just-updated sur_dx so
  ; it reflects the final post-advance geometry, not a mid-RK-step value.
  grad_elev_dx = dblarr(xnum)
  for i = 1l, xnum - 2l do $
    grad_elev_dx[i] = (sur_dx[i + 1] - sur_dx[i - 1]) / (2d0 * dx)
  grad_elev_dx[0]         = grad_elev_dx[1]
  grad_elev_dx[xnum - 1l] = grad_elev_dx[xnum - 2l]
  grad_sorted = abs(grad_elev_dx[ii_ice[srt]])
  grad_sorted = grad_sorted > 1d-3   ; avoid division by zero on near-flat cells

  elev_min = sur_sorted[0]
  elev_max = sur_sorted[n_ice - 1l]

  for j = 0l, nb - 1l do begin
    if elev[j] ge elev_min and elev[j] le elev_max then begin
      width_j = interpol(width_sorted, sur_sorted, elev[j]) > 0d0
      grad_j  = interpol(grad_sorted,  sur_sorted, elev[j])
      width[j] = width_j
      area[j]  = (width_j * step / grad_j) / 1d6   ; m2 -> km2
      if gl[j] eq noval then gl[j] = elev[j]        ; reactivate ice-free band
    endif else begin
      area[j] = 0d0
      gl[j]   = noval
    endelse
  endfor
endif else begin
  ; No ice left on the flowline grid: deactivate every band
  area[*] = 0d0
  gl[*]   = noval
endelse
