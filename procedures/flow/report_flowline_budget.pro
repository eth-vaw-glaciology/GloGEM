; -----------------------------------------------------------------------
; report_flowline_budget
;
; After a flow-model year, report what the flowline actually did, so that
;   volume change = accumulation + refreezing - melt - frontal ablation.
; Called from glogemflow_coupled.pro after STEP 3 (not after a blow-up).
;
;   mb[ye]         balance the flowline received in ice_thickness.pro:
;                  melt only where there was ice, including ice that
;                  flowed onto an ice-free cell during the year
;   flux_calv[ye]  + ice that left the flowline at its downstream end
;   accum, refre   band profiles mapped onto the flowline cells that held
;                  ice at the start of the year, like the balance (STEP 2)
;   smelt, imelt   scaled together so the components add up to mb[ye]
;   monthly acc/melt/refreeze/balance and runoff: scaled to the annual values
;
; All values are specific to areas[ye], the flowline area the output
; multiplies them with, and use GloGEM's ice density 0.9 (m ice <-> m w.e.).
; -----------------------------------------------------------------------
compile_opt idl2

rb_a = areas[ye] * 1d6   ; m2
if rb_a gt 0d0 then begin
  rb_mb = flow_mb_vol * 0.9d0 / rb_a
  rb_fa = flow_fa_vol * 0.9d0 / rb_a
  rb_acc = 0d0 & rb_refr = 0d0
  if c_boy gt 0 then begin
    rb_acc = total(acc_we_interp[ii_boy] * w_boy_dx[ii_boy]) * dx / rb_a
    rb_refr = total(refr_we_interp[ii_boy] * w_boy_dx[ii_boy]) * dx / rb_a
  endif
  rb_melt = rb_acc + rb_refr - rb_mb

  mb[ye] = rb_mb
  flux_calv[ye] = flux_calv[ye] + rb_fa

  ; annual components (snow and ice melt keep their ratio)
  rb_m0 = smelt[ye] + imelt[ye]
  if rb_m0 ne 0 and finite(rb_m0) then begin
    smelt[ye] = smelt[ye] * rb_melt / rb_m0
    imelt[ye] = imelt[ye] * rb_melt / rb_m0
  endif else begin
    smelt[ye] = 0d0
    imelt[ye] = rb_melt
  endelse
  accum[ye] = rb_acc
  refre[ye] = rb_refr

  ; monthly components of this mass-balance year keep their seasonal shape
  if time_resolution eq 'monthly' and outf_names[14] ne '' then begin
    rb_k = ye * 12L + lindgen(12)
    rb_mel0 = melmo[rb_k] & rb_ref0 = refrmo[rb_k]
    rb_s = total(accmo[rb_k])
    if rb_s ne 0 and finite(rb_s) then accmo[rb_k] = accmo[rb_k] * rb_acc / rb_s $
    else accmo[rb_k] = rb_acc / 12d0
    rb_s = total(refrmo[rb_k])
    if rb_s ne 0 and finite(rb_s) then refrmo[rb_k] = refrmo[rb_k] * rb_refr / rb_s $
    else refrmo[rb_k] = rb_refr / 12d0
    rb_s = total(melmo[rb_k])
    if rb_s ne 0 and finite(rb_s) then melmo[rb_k] = melmo[rb_k] * rb_melt / rb_s $
    else melmo[rb_k] = rb_melt / 12d0
    balmo[rb_k] = accmo[rb_k] - melmo[rb_k] + refrmo[rb_k]
    ; runoff follows the change in melt and refreezing
    discharge_gl[rb_k] = discharge_gl[rb_k] + (melmo[rb_k] - rb_mel0) - (refrmo[rb_k] - rb_ref0)
  endif
endif
