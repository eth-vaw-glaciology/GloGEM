; *************************************************************
; dh_reseed
;
; A glacier with no ice left restarts (dh_reseed='y'): every band of its inventory
; footprint on a bed above sea level whose ice-surface balance (virtual_ice_balance.pro) has
; been positive in each of the last five years gets the sum of these five balances as ice,
; with the band area of the Δh parameterisation, the firn cover of that ice surface and its
; surface type. That ice is the restarted glacier's balance of this year (booked in
; glacier_retreat.pro); from the next year on the glacier evolves as any other
; (dh_regrowth.pro).
; Called from glacier_retreat.pro when no band has ice.
; *************************************************************

compile_opt idl2

if ye ge 4 then begin
  drs_ii = where(area_iniconst gt 0 and thick_ini gt 0 and bed_elev ge 0 and min(bal_v5, dimension=1) gt 0, drs_ci)
  if drs_ci gt 0 then begin
    thick[drs_ii] = (total(bal_v5, 1))[drs_ii] / 0.9d0
    area[drs_ii] = area_ini[drs_ii] * (thick[drs_ii] / thick_ini[drs_ii]) ^ (1d0 / expon)
    elev[drs_ii] = bed_elev[drs_ii] + thick[drs_ii]
    gl[drs_ii] = elev[drs_ii]
    firn[drs_ii] = firn_v[drs_ii]
    sur[drs_ii] = 2 * firn[drs_ii]
    drs_s = where(sno[drs_ii] gt 0, drs_cs) & if drs_cs gt 0 then sur[drs_ii[drs_s]] = 1
    gr_qseed = total(thick[drs_ii] * area[drs_ii])   ; mio m3
  endif
endif
