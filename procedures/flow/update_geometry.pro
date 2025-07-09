; ------ Update glacier geometry ------
; Script to update & store the glacier geometry at the current time step.
; It is called from the main script 'glogemflow.pro'.
; -----------------------------------------------------
;
; @authors: Janosch Beer (2025)

; update thickness array
compile_opt idl2
for i = 0, xnum - 1 do begin
  thick[i] = th_x[i]
end

; update surface elevation array
for i = 0, xnum - 1 do begin
  elev[i] = bed_elev[i] + thick[i]
end

; update the length of the glacier
if xnum gt 0 then begin
  glacier_length = xnum * dx ; length of the glacier in m
  for i = xnum - 3, 0, -1 do begin ; Glacier length: start from top --> go down
    if thick[i] eq 0 then begin
      glacier_length = ((xnum - 2 - i) + 1) * dx
      break
    endif
  endfor
endif

; update the area of the glacier
if xnum gt 0 then begin
  glacier_area = 0.0
  for i = 0, xnum - 1 do begin
    if thick[i] gt 0 then begin
      glacier_area = glacier_area + dx * width_surface[i]
    endif
  endfor
endif

; update the volume of the glacier
if xnum gt 0 then begin
  vol = 0.0
  for i = 0, xnum - 1 do begin
    if width_flag eq 0 then begin ; Same width over entire glacier
      vol = vol + dx * thick[i] * 700 ; in m^3 (need to assume the width)
    endif else if (width_flag eq 1) or (width_flag eq 2) or (width_flag eq 3) then begin
      vol = vol + dx * thick[i] * width_mid[i] ; in m^3
    endif
  endfor
endif

; Velocity (average: vertically integrated)
for i = 1, xnum - 2 do begin
  if th_x[i] gt 0 then begin
    velocity[i] = -df_x[i] * grad_x[i] / th_x[i]
  endif
endfor
