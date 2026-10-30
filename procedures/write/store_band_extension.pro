; *************************************************************
; store_band_extension
;
; Band extension (band_extension='y'): in the elevation-band output the glacier's bands without ice and
; the extension bands below the glacier get the balance an ice surface would have (virtual_ice_balance.pro).
; Below the inventory front the balance may not rise going down: a band where the blend into the regional
; parameters would make it rise takes the value of the band above.
; Called after store_elevationband_massbalance.pro, also when the glacier has no ice left.
; *************************************************************

compile_opt idl2

v_wb = (bal_month eq dd_thresholds[2] and m eq dd_thresholds[0]) or (bal_month eq dd_thresholds[0] and m eq dd_thresholds[2])
v_mb = (bal_month eq dd_thresholds[2] and m eq dd_thresholds[2] - 1) or (bal_month eq dd_thresholds[0] and m eq dd_thresholds[0] - 1)
if v_wb or v_mb then begin
  bal_vm = bal_v
  for v_k = i_front_v - 1, 0, -1 do bal_vm[v_k] = bal_vm[v_k] < bal_vm[v_k + 1]
  v_ii = where(gl eq noval, v_ci)
  if v_wb then begin
    if v_ci gt 0 then elev_bwb[ye, v_ii] = bal_vm[bx_n + v_ii]
    if bx_n gt 0 then elev_bwbx[ye, *] = bal_vm[0 : bx_n - 1]
  endif
  if v_mb then begin
    if v_ci gt 0 then elev_bmb[ye, v_ii] = bal_vm[bx_n + v_ii]
    if bx_n gt 0 then elev_bmbx[ye, *] = bal_vm[0 : bx_n - 1]
  endif
endif
