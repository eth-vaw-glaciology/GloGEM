; *************************************************************
; glacier_retreat
;
; Glacier retreat model
; This procedure updates the glacier geometry (glacier retreat) based on the dh-parameterization (Huss et al., 2010).
; The parametrization distributes thickness changes based on a normalized elevation rang, ensuring that the largest changes occur at the terminus.
; The procedure is mass conserving, adjusting the area of elevation band using an area-thickness scaling.
;
; The glacier advance scheme is activated when the glacier volume increases and the volume change exceeds a certain threshold.
; *************************************************************

compile_opt idl2

noval = -9999

; -----------------------------
; update surface geometry

ii = where(thick gt 0, ci)

; initialize dh-param if elevation range of glacier larger than 50m, else non-dyn downwasting
if ci gt 4 then begin
  ; normalized dh-function
  dh = dblarr(nb) + noval
  hr = dh
  hr0 = elev[ii[ci - 1]] - elev[ii[0]]
  for i = 0, ci - 1 do hr[ii[i]] = (elev[ii[ci - 1]] - elev[ii[i]]) / hr0 ; elevation range
  ; dh function
  ta = total(area)
  if ta gt dh_size[1] then for i = 0, ci - 1 do dh[ii[i]] = (hr[ii[i]] - 0.02) ^ 6 + 0.12 * (hr[ii[i]] - 0.02) ; large
  if ta gt dh_size[0] and ta le dh_size[1] then for i = 0, ci - 1 do dh[ii[i]] = (hr[ii[i]] - 0.05) ^ 4 + 0.19 * (hr[ii[i]] - 0.05) + 0.01 ; medium
  if ta le dh_size[0] then for i = 0, ci - 1 do dh[ii[i]] = (hr[ii[i]] - 0.30) ^ 2 + 0.60 * (hr[ii[i]] - 0.30) + 0.09 ; small
  jj = where(dh gt 1, cj)
  if cj gt 0 then dh[jj] = 1
  jj = where(dh lt 0 and dh ne noval, cj)
  if cj gt 0 then dh[jj] = 0

  ; distribute volume change - dh-function
  f = dvol / (total(dh[ii] * area[ii] * 1000000))
  delev = dblarr(nb) + noval
  delev[ii] = dh[ii] * f

  ; make sure that this section is only activated if volume will afterwards NOT be
  ; distributed by the glacier advance scheme!
  rda = 'y'
  if advance eq 'y' and volume1 ge volume0 and f gt adv_fcrit then rda = 'n'

  if redistribute_vplus eq 'y' and rda eq 'y' then begin
    ; check for elevation changes larger than mass balance rate (only
    ; lower ablation area!)

    if dvol lt 0 then bal_crit = -1. else bal_crit = 0.
    if dvol lt 0 then a = -1. else a = 1.
    jj = where(abs(delev[ii[0 : fix(ci / 6)]]) gt abs(bal[ii[0 : fix(ci / 6)]] / 0.9), cj)
    vplus = 0
    if cj gt 0 then begin
      for i = 0, fix(ci / 6) - 1 do begin
        if abs(delev[ii[i]]) gt abs(bal[ii[i]] / 0.9) and bal[ii[i]] lt bal_crit then begin
          vplus = vplus + balv[ii[i]] * (1 - ((bal[ii[i]] / 0.9) / ((-a) * delev[ii[i]])))
          delev[ii[i]] = (-a) * bal[ii[i]] / 0.9
        endif
      endfor

      ; distribute removed volume over the remaining glacier
      jj = where(thick gt 5, cj) ; critical thickness (thicknesses below are not touched!)
      if cj gt 3 then begin ; do redistribution only if there are some elevation bands left
        at = total(area[jj]) * 1000000.
        dhp = vplus / at
        for j = 0, cj - 1 do delev[jj[j]] = delev[jj[j]] + dhp
      endif else delev = bal / 0.9 ; apply mass balance rate if glacier at minimal thickness everywhere
    endif
  endif

  ; ------------------------------
  ; glacier advance scheme
  if advance eq 'y' and volume1 ge volume0 and f gt adv_fcrit then begin
    ; run classic advance model only when current volume is bigger than
    ; the initial one, i.e. in an ''unexplored'' range of geometries
    delev[ii] = dh[ii] * f ; set back to original parameterization
    ; determine 'excess' volume
    a = delev - adv_fcrit
    jj = where(a gt 0, cj)
    if cj gt 0 then v_adv = total(a[jj] * area[jj]) ; mio m3
    delev[jj] = adv_fcrit ; set delev back to maximum thickness increase

    ; distribute excess volume
    hh = where(area ne 0, cj)
    tt = thick
    if cj gt 0 and hh[0] ne 0 then begin ; only if there is space in front of the glacier
      for i = hh[0] - 1, 0, -1 do begin
        ; set values for 'hypothetical' initial areas and volumes
        if area_ini[i] eq 0 then area_ini[i] = adv_iniar * adv_iniamplification[i]
        if thick_ini[i] eq 0 then thick_ini[i] = adv_inithi * adv_iniamplification[i]

        ; calculate and distribute the 'advance volume';
        ; target ice thickness in each band will be taken from the one above
        v_adv = v_adv - adv_iniar * (tt[i + 1] + adv_fcrit)
        delev[i] = tt[i + 1] + adv_fcrit
        tt[i] = tt[i + 1]
        if v_adv lt 0 then goto, endsearch
      endfor
    endif else begin
      ; distribute excess volume EQUALLY if there is no space left for an advance...
      if ye gt 0 then att = areas[ye - 1] else att = areas[ye]
      delev[where(delev ne noval)] = delev[where(delev ne noval)] + v_adv / att
    endelse
    endsearch:
    ii = where(delev ne noval)
  endif else begin ; if advance no second iteration of delev!!! does not seem to be working ...

    ; --------------------------------------------------
    ; !! calculate elevation band area change !!
    darea = dblarr(nb)
    vcorr = 0.
    tt = thick + delev
    for i = 0, ci - 1 do if tt[ii[i]] ge 0 then darea[ii[i]] = area_ini[ii[i]] * (tt[ii[i]] / thick_ini[ii[i]]) ^ (1. / expon) - area[ii[i]]
    for i = 0, ci - 1 do vcorr = vcorr + darea[ii[i]] / 2. * delev[ii[i]] ; [mio m3]   ; cumulate volume to be corrected
    ; redistribute additional volume using dh-parameterization
    fcorr = vcorr / (total(dh[ii] * area[ii]))
    delev[ii] = delev[ii] - dh[ii] * fcorr
  endelse

  ; apply surface elevation change
  thick[ii] = thick[ii] + delev[ii] ; thickness

  jj = where(thick le 0, cj)
  if cj gt 0 then begin
    vol_lost = total(thick[jj] * area[jj])
    if vol_lost lt 0 then begin
      fcorr = vol_lost / (total(dh[ii] * area[ii]))
      thick[ii] = thick[ii] + dh[ii] * fcorr
      jj = where(thick le 0, cj)
    endif
    thick[jj] = 0
    area[jj] = 0
    elev[jj] = bed_elev[jj] ; set to zero if no glacier left
  endif

  area0 = area
  band_volume = thick * area ; volume per elevation band before adapting band area
  for i = 0, ci - 1 do area[ii[i]] = area_ini[ii[i]] * (thick[ii[i]] / thick_ini[ii[i]]) ^ (1. / expon)

  ; update the volume-conserving mean thickness!
  ii = where(area0 gt 0, ci)
  for i = 0, ci - 1 do thick[ii[i]] = band_volume[ii[i]] / area[ii[i]]
  for i = 0, ci - 1 do elev[ii[i]] = bed_elev[ii[i]] + thick[ii[i]] ; surface elevation calculated with updated band thickness

  ; explicitely enforce mass conservation
  vtt = total(area * thick) - volumes[ye] * 1000.
  ii = where(thick gt 0, ci)
  if ci gt 0 then begin
    fcorr = (vtt - dvol / 1000000.) / (total(dh[ii] * area[ii]))
    thick[ii] = thick[ii] - dh[ii] * fcorr
    jj = where(thick le 0, cj)
    if cj gt 0 then begin
      thick[jj] = 0
      area[jj] = 0
      elev[jj] = bed_elev[jj] ; set to zero if no glacier left
    endif
    ; updating surface elevation again
    for i = 0, ci - 1 do elev[ii[i]] = bed_elev[ii[i]] + thick[ii[i]] ; surface elevation calculated with updated band thickness
    jj = where(thick gt 0, cj)
    if cj gt 0 then gl[jj] = elev[jj]
  endif

  ; ----- calving
  ; terminus break-off due to calving

  ; cut off elevation bands located below sea level and add mass loss to calving
  ii = where(elev lt 0 and area gt 0, ci)
  q_calv = 0
  if ci gt 0 then begin
    q_calv = q_calv + total(thick[ii] * area[ii]) * 1000000.
    flux_calv[ye] = flux_calv[ye] + q_calv / 1000000. * dens / ar_gl
  endif

  if q_calv ne 0 then begin
    ii = where(thick ne 0, ci)
    vcum = 0
    for i = 0, ci - 1 do begin
      vcum = vcum + thick[ii[i]] * area[ii[i]] * 1000000.
      if vcum lt q_calv then begin
        thick[ii[i]] = 0
        area[ii[i]] = 0
        elev[ii[i]] = bed_elev[ii[i]]
      endif else begin
        tt = vcum - thick[ii[i]] * area[ii[i]] * 1000000.
        thick[ii[i]] = thick[ii[i]] * (vcum - q_calv) / (vcum - tt)
        elev[ii[i]] = bed_elev[ii[i]] + thick[ii[i]]
        area[ii[i]] = area_ini[ii[i]] * (thick[ii[i]] / thick_ini[ii[i]]) ^ (1. / expon)
        goto, end_calv
      endelse
    endfor
    end_calv:
  endif

  ii = where(area eq 0, ci)
  if ci gt 0 then gl[ii] = noval
endif else begin
  ; ----------------------------
  ; very small glaciers

  ; apply surface elevation change
  for i = 0, ci - 1 do thick[ii[i]] = thick[ii[i]] + bal[ii[i]] / 0.9 ; thickness
  for i = 0, ci - 1 do elev[ii[i]] = elev[ii[i]] + bal[ii[i]] / 0.9 ; surface elevation
  for i = 0, ci - 1 do area[ii[i]] = area_ini[ii[i]] * (thick[ii[i]] / thick_ini[ii[i]]) ^ (1. / expon) ; area in elevation band
  jj = where(thick lt 0, cj)
  if cj gt 0 then begin
    thick[jj] = 0
    area[jj] = 0
    elev[jj] = bed_elev[jj]
    gl[jj] = noval ; set to zero if no glacier left
  endif
endelse

; ----------------------------
; advance from look-up table

; determine geometry based on look up table of previous volumes
ii = where(thick gt 0, ci)
if adv_lookup eq 'y' and dvol gt 0 and volume1 lt volume0 and ci gt 4 then begin
  ; searching for next known target volume
  a = min(abs((volume1 + dvol / 1000000000.) - adv_lookup_data[0, 0, *]), ind)
  for i = 0, nb - 1 do area[i] = adv_lookup_data[1, i, ind]

  ; correcting for error to enforce mass conservation
  vtt = adv_lookup_data[0, 0, ind] - (volume1 + dvol / 1000000000.)
  ii = where(area gt 0, ci)
  if ci gt 0 then begin
    fcorr = (vtt * 1000.) / (total(dh[ii] * area[ii]))
    thick[ii] = adv_lookup_data[2, ii, ind] - dh[ii] * fcorr
    jj = where(thick le 0, cj)
    if cj gt 0 then begin
      thick[jj] = 0
      area[jj] = 0
      elev[jj] = bed_elev[jj] ; set to zero if no glacier left
    endif
    elev[ii] = bed_elev[ii] + thick[ii] ; surface elevation calculated with updated band thickness
    jj = where(thick gt 0, cj)
    if cj gt 0 then gl[jj] = elev[jj]
  endif
endif

; storing of results
; if ye mod 10 eq 0 then gls(cnp,*)=elev
; if ye mod 10 eq 0 then cnp=cnp+1
