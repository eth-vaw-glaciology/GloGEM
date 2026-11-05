; *************************************************************
; book_ice_melt
;
; Books bim_we (m w.e., specific to areas[ye] like every flux of the year) as ice melt
; of this year: annual balance and ice melt; monthly melt, balance and glacier runoff,
; spread like this year's melt, evenly if there was none.
; Used by limit_glacier_growth.pro and glacier_retreat.pro (dh_regrowth outflow).
; *************************************************************

compile_opt idl2

mb[ye] = mb[ye] - bim_we
imelt[ye] = imelt[ye] + bim_we
if time_resolution eq 'monthly' and outf_names[14] ne '' then begin
  bim_k = ye * 12L + lindgen(12)
  bim_ok = where(finite(melmo[bim_k]) and melmo[bim_k] ne snoval and $
                 finite(balmo[bim_k]) and finite(discharge_gl[bim_k]), bim_cok)
  if bim_cok gt 0 then begin
    bim_k = bim_k[bim_ok]
    bim_s = total(melmo[bim_k] > 0d0)
    if bim_s gt 0 then bim_add = (melmo[bim_k] > 0d0) * (bim_we / bim_s) $
    else bim_add = dblarr(bim_cok) + bim_we / bim_cok
    melmo[bim_k] = melmo[bim_k] + bim_add
    balmo[bim_k] = balmo[bim_k] - bim_add
    discharge_gl[bim_k] = discharge_gl[bim_k] + bim_add
  endif
endif
