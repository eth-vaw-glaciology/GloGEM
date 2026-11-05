; -----------------------------------------------------------------------
; handover_to_dh
;
; A flow-model glacier falls back to the Δh parameterisation during the run
; (non-finite balance or blow-up). Called in glogemflow_coupled.pro after
; sync_bands_thickness; glacier_retreat.pro then takes this same year.
;
;   * band thickness is scaled so the bands hold this year's flowline volume
;     (volumes[ye]): the switch neither creates nor removes ice
;   * mb[ye] and areas[ye] go back to the band values: this year's balance
;     is the bands' balance over their area, which glacier_retreat applies
; -----------------------------------------------------------------------
compile_opt idl2

ho_ii = where(gl ne noval and area gt 0 and thick gt 0, ho_c)
if ho_c gt 0 and volumes[ye] gt 0 then begin
  ho_f = volumes[ye] * 1000d0 / total(area[ho_ii] * thick[ho_ii])
  thick[ho_ii] = thick[ho_ii] * ho_f
  print, '  handover_to_dh: band thickness scaled by ' + strtrim(string(ho_f, fo='(f8.4)'), 2) + $
    ' to keep the flowline volume of ' + strtrim(string(volumes[ye], fo='(f10.4)'), 2) + ' km3'
endif
mb[ye] = mb_band_ye
areas[ye] = ar_gl
volume1 = volumes[ye]
