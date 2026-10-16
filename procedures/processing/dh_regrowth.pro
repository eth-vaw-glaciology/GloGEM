; *************************************************************
; dh_regrowth
;
; A growth year (dvol > 0) of the Δh parameterisation with dh_regrowth='y', called from
; glacier_retreat.pro in place of its distribution, advance scheme and mass corrections.
;   1. The gain thickens the ice bands with the Δh shape dh.
;   2. A band thickens by at most adv_fcrit in a year and up to its limit dhr_hmax
;      (initialise_dh_regrowth.pro), the front band only up to its target thickness. The ice
;      above these goes to the front.
;   3. That ice first brings the front band to its target thickness, then fills the empty
;      bands below the front one by one, top down. Targets: a former band's inventory
;      thickness; beyond the inventory front the inventory terminus thickness dhr_inithi, at
;      most the target of the band above and the band's limit (area dhr_iniar, no
;      amplification). A band's area follows the area-thickness relation of the Δh
;      parameterisation, so the last band takes exactly what is left. Bands without
;      inventory ice inside the glacier are passed over.
;   4. Ice left at the lowest band leaves the glacier: gr_qout, booked in glacier_retreat.pro.
; The volume changes by exactly the balance less gr_qout.
;
; Inputs: ii, dh (ice bands, Δh shape), dvol, dhr_hmax, dhr_iniar, dhr_inithi; modifies
; thick, area, elev, gl, and area_ini, thick_ini of bands beyond the inventory front.
; *************************************************************

compile_opt idl2

dhr_v0 = total(area * thick)          ; mio m3
dhr_dv = dvol / 1000000.d0            ; mio m3

; target thickness of each band
dhr_inv0 = (where(area_iniconst gt 0))[0]   ; inventory front band
dhr_tgt = dblarr(nb)
dhr_tgt[*] = thick_ini < dhr_hmax
for i = dhr_inv0 - 1, 0, -1 do dhr_tgt[i] = dhr_inithi < dhr_tgt[i + 1] < dhr_hmax[i]

; 1. thickening with the Δh shape
dhr_dz = dh[ii] * dhr_dv / total(dh[ii] * area[ii])

; 2. at most adv_fcrit and up to the limit; the front band up to its target
dhr_room = (dhr_hmax[ii] - thick[ii]) > 0d0
dhr_room[0] = dhr_room[0] < ((dhr_tgt[ii[0]] - thick[ii[0]]) > 0d0)
dhr_up = dhr_dz < (adv_fcrit < dhr_room)
dhr_adv = total((dhr_dz - dhr_up) * area[ii])   ; mio m3 to the front

; thicken, then the band area of the Δh parameterisation, keeping each band's volume
thick[ii] = thick[ii] + dhr_up
dhr_bv = thick[ii] * area[ii]
area[ii] = area_ini[ii] * (thick[ii] / thick_ini[ii]) ^ (1d0 / expon)
thick[ii] = dhr_bv / area[ii]

; 3. the ice for the front: the front band to its target, then the empty bands below, top down
i = ii[0]
while dhr_adv gt 0d0 and i ge 0 do begin
  dhr_gap = i lt ii[0] and i ge dhr_inv0 and area_iniconst[i] le 0
  if ~dhr_gap then begin
    if area_ini[i] le 0 or thick_ini[i] le 0 then begin
      area_ini[i] = dhr_iniar & thick_ini[i] = dhr_inithi
    endif
    dhr_vn = thick[i] * area[i]
    dhr_vf = dhr_tgt[i] * area_ini[i] * (dhr_tgt[i] / thick_ini[i]) ^ (1d0 / expon)
    if dhr_vf gt dhr_vn then begin
      if dhr_adv lt dhr_vf - dhr_vn then begin
        ; the band takes all that is left
        dhr_h = ((dhr_vn + dhr_adv) * thick_ini[i] ^ (1d0 / expon) / area_ini[i]) ^ (expon / (expon + 1d0))
        dhr_adv = 0d0
      endif else begin
        dhr_h = dhr_tgt[i]
        dhr_adv = dhr_adv - (dhr_vf - dhr_vn)
        if dhr_adv lt 1d-9 * dhr_v0 then dhr_adv = 0d0   ; a rounding residue, not ice
      endelse
      thick[i] = dhr_h
      area[i] = area_ini[i] * (dhr_h / thick_ini[i]) ^ (1d0 / expon)
    endif
  endif
  i = i - 1
endwhile

; 4. what is left leaves the glacier at its lowest band
gr_qout = dhr_adv

dhr_jj = where(thick gt 0, dhr_cj)
elev[dhr_jj] = bed_elev[dhr_jj] + thick[dhr_jj]
gl[dhr_jj] = elev[dhr_jj]

; the volume change must be the balance less the outflow; a rounding residue is spread evenly
dhr_res = total(area * thick) - (dhr_v0 + dhr_dv - gr_qout)
if abs(dhr_res) gt 1d-6 * dhr_v0 then begin
  thick[dhr_jj] = thick[dhr_jj] - dhr_res / total(area[dhr_jj])
  elev[dhr_jj] = bed_elev[dhr_jj] + thick[dhr_jj]
  gl[dhr_jj] = elev[dhr_jj]
endif
