; *************************************************************
; initialise_band_extension
;
; Band extension (band_extension='y'): every band without ice gets the balance an ice surface would have
; there (virtual_ice_balance.pro), written to the elevation-band files (store_band_extension.pro).
; The domain is the glacier's bands plus extension bands below its lowest band (prefix bx_), 10 m apart,
; down to band_ext_depth below the lowest band of the inventory (bands already there, e.g. advance bands,
; count), not below sea level. The extension bands are separate arrays: the glacier itself is unchanged.
; Index 0 of the domain arrays (suffix _v) is the lowest extension band; the glacier's band i is bx_n+i.
; *************************************************************

compile_opt idl2

; extension bands below the lowest band, as for the advance bands in read_hypsometryfile.pro
bx_n = round(band_ext_depth / 10.)
if adv_calving lt 0 then bx_hmin = 0. else bx_hmin = 10.
if hmin[gg[g]] - bx_n * 10. lt bx_hmin then bx_n = fix((hmin[gg[g]] - bx_hmin) / 10)
bx_n = (bx_n > 0) - (nb - nb_inv)
bx_n = bx_n < long(floor((elev0[0] - 5.) / 10.))   ; lowest band at 5 m or above, also where hmin lies above the bands
bx_n = bx_n > 0
nv = bx_n + nb
if bx_n gt 0 then begin
  bx_elev = elev0[0] - 10d * (bx_n - dindgen(bx_n))   ; lowest band first, as elev
  ; firn as on the glacier's bands: above the median elevation
  v_elev = [bx_elev, reform(elev, nb)] & firn_v = [double(bx_elev gt hmed[gg[g]]), reform(firn, nb)]
endif else begin
  v_elev = reform(elev, nb) & firn_v = reform(firn, nb)
endelse

; virtual ice surface on every band: snow, surface type, last 5 balances
sno_v = dblarr(nv) & sur_v = dblarr(nv) & snostor_v = dblarr(nv) & bal_v5 = dblarr(5, nv)

; parameters per band: the glacier's own down to its front, blending linearly into the regional medians
; below it (w_v = 0 at and above the front), over band_blend_depth or more: the offset changes by at most
; band_blend_dtdz per metre, the degree-day factors and c_prec by at most band_blend_dlnp (relative) per
; metre, so the balance still falls going down
v_ii = where(gl ne noval, v_ci) & if v_ci gt 0 then z_front_v = min(elev[v_ii]) else z_front_v = min(elev)
if v_ci gt 0 then i_front_v = bx_n + min(v_ii) else i_front_v = 0   ; lowest band with ice
blend_d_v = band_blend_depth > abs(t_offset - toff_reg) / band_blend_dtdz
blend_d_v = blend_d_v > abs(alog(DDFice / ddfi_reg)) / band_blend_dlnp > abs(alog(DDFsnow / ddfs_reg)) / band_blend_dlnp
blend_d_v = blend_d_v > abs(alog(c_prec / cprec_reg)) / band_blend_dlnp
w_v = ((z_front_v - v_elev) / blend_d_v > 0d) < 1d
toff_v = t_offset + w_v * (toff_reg - t_offset) & cprec_v = c_prec + w_v * (cprec_reg - c_prec)
ddfs_v = DDFsnow + w_v * (ddfs_reg - DDFsnow) & ddfi_v = DDFice + w_v * (ddfi_reg - DDFice)

; output rows of the extension bands (write_elevationband_file.pro)
elev_bmbx = dblarr(years, bx_n > 1) + snoval & elev_bwbx = elev_bmbx
