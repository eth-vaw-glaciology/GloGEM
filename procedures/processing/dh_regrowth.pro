; *************************************************************
; dh_regrowth
;
; A growth year (dvol > 0) of the Δh parameterisation with dh_regrowth='y', called from
; glacier_retreat.pro in place of its distribution, advance scheme and mass corrections.
;   1. The gain thickens the ice bands with the Δh shape dh.
;   2. A band thickens by at most adv_fcrit in a year and up to its limit dhr_hmax
;      (initialise_dh_regrowth.pro), the front band only up to its target thickness. The ice
;      above these goes to the front.
;   3. That ice first refills empty bands inside the glacier (holes that melt years leave), then brings the front band
;      to its target thickness and fills the empty bands below it, top down. Targets: a former
;      band's inventory thickness; beyond the inventory front the inventory terminus thickness
;      dhr_inithi (area dhr_iniar), at most the band's limit. A band's area follows the
;      area-thickness relation of the Δh parameterisation, so the last band takes exactly what
;      is left. Bands without inventory ice inside the inventory are passed over.
;      The front advances by at most dh_regrowth_adv_max a year along the flow (a band's
;      horizontal length is 10 m / tan(slope), a partly filled band counts in proportion);
;      the ice this holds back thickens all ice bands by the same amount, each up to its limit,
;      and only what is left after that continues the front beyond the advance limit.
;   4. Ice left at the lowest band leaves the glacier: gr_qout, booked in glacier_retreat.pro.
; The volume changes by exactly the balance less gr_qout.
;
; Inputs: ii, dh (ice bands, Δh shape), dvol, dhr_hmax, dhr_sl, dhr_iniar, dhr_inithi; modifies
; thick, area, elev, gl, and area_ini, thick_ini of bands beyond the inventory front.
; *************************************************************

compile_opt idl2

dhr_v0 = total(area * thick)          ; mio m3
dhr_dv = dvol / 1000000.d0            ; mio m3

; target thickness of each band
dhr_inv0 = (where(area_iniconst gt 0))[0]   ; inventory front band
dhr_tgt = thick_ini < dhr_hmax
if dhr_inv0 gt 0 then dhr_tgt[0:dhr_inv0 - 1] = dhr_inithi < dhr_hmax[0:dhr_inv0 - 1]

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

; 3. the ice for the front
dhr_len = 10d0 / tan(dhr_sl * !dpi / 180d0)   ; horizontal length of each band, m
dhr_dist = 0d0                                ; advance of the front this year, m
; bands to fill, in order: empty bands inside the glacier other than gaps of the inventory (top down), then the
; front band and below
dhr_k = lindgen(nb)
dhr_in = where(dhr_k gt ii[0] and dhr_k lt ii[-1] and thick le 0 and (dhr_k lt dhr_inv0 or area_iniconst gt 0), dhr_nin)
dhr_lo = reverse(lindgen(ii[0] + 1))
if dhr_nin gt 0 then dhr_ord = [reverse(dhr_in), dhr_lo] else dhr_ord = dhr_lo
for dhr_p = 0, 1 do begin
  dhr_lim = dhr_p eq 0 and dh_regrowth_adv_max gt 0
  foreach i, dhr_ord do begin
    if dhr_adv le 0d0 then break
    dhr_gap = i lt ii[0] and i ge dhr_inv0 and area_iniconst[i] le 0
    if dhr_gap then continue
    if area_ini[i] le 0 or thick_ini[i] le 0 then begin
      area_ini[i] = dhr_iniar & thick_ini[i] = dhr_inithi
    endif
    dhr_vn = thick[i] * area[i]
    dhr_vf = dhr_tgt[i] * area_ini[i] * (dhr_tgt[i] / thick_ini[i]) ^ (1d0 / expon)
    if dhr_vf le dhr_vn then continue
    ; the front (band ii[0] and below) advances by at most dh_regrowth_adv_max this year
    dhr_stop = 0b
    if dhr_lim and i le ii[0] then begin
      dhr_vl = dhr_vn + ((dh_regrowth_adv_max - dhr_dist) > 0d0) / dhr_len[i] * dhr_vf
      if dhr_vl lt dhr_vf then begin
        dhr_vf = dhr_vl & dhr_stop = 1b
      endif
    endif
    if dhr_vf gt dhr_vn then begin
      if dhr_adv lt dhr_vf - dhr_vn then begin
        ; the band takes all that is left
        dhr_dist = dhr_dist + dhr_adv / (dhr_tgt[i] * area_ini[i] * (dhr_tgt[i] / thick_ini[i]) ^ (1d0 / expon)) * dhr_len[i]
        dhr_h = ((dhr_vn + dhr_adv) * thick_ini[i] ^ (1d0 / expon) / area_ini[i]) ^ (expon / (expon + 1d0))
        dhr_adv = 0d0
      endif else begin
        dhr_dist = dhr_dist + (dhr_vf - dhr_vn) / (dhr_tgt[i] * area_ini[i] * (dhr_tgt[i] / thick_ini[i]) ^ (1d0 / expon)) * dhr_len[i]
        if dhr_stop then dhr_h = (dhr_vf * thick_ini[i] ^ (1d0 / expon) / area_ini[i]) ^ (expon / (expon + 1d0)) $
        else dhr_h = dhr_tgt[i]
        dhr_adv = dhr_adv - (dhr_vf - dhr_vn)
        if dhr_adv lt 1d-9 * dhr_v0 then dhr_adv = 0d0   ; a rounding residue, not ice
      endelse
      thick[i] = dhr_h
      area[i] = area_ini[i] * (dhr_h / thick_ini[i]) ^ (1d0 / expon)
    endif
    if dhr_stop then break
  endforeach
  ; what the advance limit held back thickens all ice bands by the same amount, each up to its limit
  if dhr_p eq 0 and dhr_adv gt 0d0 then begin
    dhr_jj = where(thick gt 0 and thick_ini gt 0 and area_ini gt 0, dhr_cj)
    dhr_rm = (dhr_hmax[dhr_jj] - thick[dhr_jj]) > 0d0   ; room, m (at today's area)
    if total(dhr_rm * area[dhr_jj]) gt 0d0 then begin
      ; the common thickening dz: sum of (dz < room) * area = dhr_adv, or every band at its limit
      dhr_o = sort(dhr_rm) & dhr_ca = reverse(total(reverse(area[dhr_jj[dhr_o]]), /cumulative))
      dhr_cv = [0d0, total(dhr_rm[dhr_o] * area[dhr_jj[dhr_o]], /cumulative)]
      dhr_dzc = max(dhr_rm)
      for dhr_q = 0l, dhr_cj - 1 do begin
        ; bands dhr_o[q..] still open: volume needed to raise them all to the room of band q
        if dhr_cv[dhr_q] + dhr_rm[dhr_o[dhr_q]] * dhr_ca[dhr_q] ge dhr_adv then begin
          dhr_dzc = (dhr_adv - dhr_cv[dhr_q]) / dhr_ca[dhr_q] & break
        endif
      endfor
      dhr_add = (dhr_rm < dhr_dzc) * area[dhr_jj]
      dhr_bv = thick[dhr_jj] * area[dhr_jj] + dhr_add
      thick[dhr_jj] = (dhr_bv * thick_ini[dhr_jj] ^ (1d0 / expon) / area_ini[dhr_jj]) ^ (expon / (expon + 1d0))
      area[dhr_jj] = area_ini[dhr_jj] * (thick[dhr_jj] / thick_ini[dhr_jj]) ^ (1d0 / expon)
      dhr_adv = dhr_adv - total(dhr_add)
      if dhr_adv lt 1d-9 * dhr_v0 then dhr_adv = 0d0
    endif
  endif
endfor

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
