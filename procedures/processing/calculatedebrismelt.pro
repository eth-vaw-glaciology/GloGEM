pro CALCULATEDEBRISMELT, debris_supraglacial, sur, tg, t_melt, debris_thick, debris_frac, debris_type_th, debris_type_red, debris_ponddens, debris_pond_enhancementfactor, mel, imelt, ye, ar_gl, area, time_resolution, icemel, write_mb_elevationbands
compile_opt idl2

  ; Check if supraglacial debris influence should be considered
  if debris_supraglacial eq 'y' then begin

    ; Identify debris-covered ice:
    ; The 'where' function finds indices where:
    ; - 'sur' is 0 (indicating ice rather than snow or firn)
    ; - 'tg' (temperature) is greater than 't_melt' (melting threshold)
    ; - 'debris_thick' (debris thickness) is greater than 0
    ; - 'debris_frac' (fraction of surface covered by debris) is greater than 0
    ii = where(sur eq 0 and tg gt t_melt and debris_thick gt 0 and debris_frac gt 0, ci)

    ; If there are valid debris-covered ice areas (i.e., ci > 0)
    if ci gt 0 then begin

      ; Loop through each debris-covered ice pixel
      for i = 0L, ci - 1 do begin

        ; Find the closest debris thickness type:
        ; - 'debris_type_th' is an array of predefined thickness values
        ; - 'abs(debris_thick(ii(i)) - debris_type_th)' calculates the absolute difference
        ; - 'min()' finds the smallest difference and returns the index 'ind'
        a = min(abs(debris_thick[ii[i]] - debris_type_th), ind)

        ; If writing mass balance for elevation bands, store the reduction factor
        if write_mb_elevationbands eq 'y' then debris_red_factor[ii[i]] = debris_type_red[ind]

        ; Compute surface melt considering different factors:
        ; 1. Debris-covered ice melt is reduced by 'debris_type_red(ind)' (debris-specific reduction factor)
        ; 2. Bare ice (where there is no debris) melts normally
        ; 3. Ponds and cliffs have enhanced melting based on 'debris_pond_enhancementfactor'
        mel[ii[i]] = (debris_frac[0, ii[i]] - debris_ponddens[ii[i]]) * debris_type_red[ind] * mel[ii[i]] + $  ; Reduced melting due to debris
          (1. - debris_frac[0, ii[i]]) * mel[ii[i]] + $  ; Normal melt where there is no debris
          debris_ponddens[ii[i]] * debris_pond_enhancementfactor * mel[ii[i]]  ; Enhanced melt in ponds

      endfor  ; End loop through debris-covered ice pixels

      ; Update total ice melt:
      ; - 'total(mel(ii) * area(ii))' sums melt across the affected area
      ; - Normalize by glacier area 'ar_gl' to maintain consistency
      imelt[ye] = imelt[ye] + total(mel[ii] * area[ii]) / ar_gl

      ; If the model runs on a daily resolution, store daily melt values
      if time_resolution eq 'daily' then icemel[ii] = mel[ii]

    endif  ; End check for valid debris-covered ice

  endif  ; End check for supraglacial debris effect

end  
