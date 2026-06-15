; -----------------------------------------------------------------------
; update_elevation_bands
;
; Rebuild GloGEM's elevation-band arrays from the flowline geometry
; after each SIA time step. Called from glogem.pro immediately after
; @procedures/flow/glogemflow_coupled.
;
; For each elevation band j, sums the area and mean surface width from
; all flowline cells whose surface elevation falls within that band.
; Bands that lose all ice are marked gl[j]=noval; bands that gain ice
; (e.g. re-advance) are activated with gl[j]=elev[j].
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

area_new   = dblarr(nb)
width_sum  = dblarr(nb)   ; sum of width_surface_dx[i] per band  [m]
ncells_new = lonarr(nb)   ; number of ice cells per band

for i = 0l, xnum - 1l do begin
  if thick_dx[i] gt 0d0 then begin
    ; Assign cell to nearest elevation band (uniform band spacing assumed)
    j_band = round((sur_dx[i] - elev[0]) / step)
    j_band = (j_band > 0l) < (nb - 1l)
    area_new[j_band]   += width_surface_dx[i] * dx / 1d6   ; m2 → km2
    width_sum[j_band]  += width_surface_dx[i]               ; m
    ncells_new[j_band] += 1l
  endif
endfor

for j = 0l, nb - 1l do begin
  if area_new[j] gt 0d0 then begin
    area[j]  = area_new[j]
    width[j] = width_sum[j] / double(ncells_new[j])   ; mean surface width [m]
    if gl[j] eq noval then gl[j] = elev[j]            ; reactivate ice-free band
  endif else begin
    area[j] = 0d0
    gl[j]   = noval
  endelse
endfor
