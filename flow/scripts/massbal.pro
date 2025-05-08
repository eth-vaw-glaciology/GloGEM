; Calculate the surface mass balance for every point (based on elevation
; dependent fit that was calculated before the time loop, in 'load_smb').
; Eventually a sinusoidal signal can be applied on top of this
; (was used for first experiments/tests; now never used normally)

; ; Elevation used to calculate the SMB
compile_opt idl2
mb_sur = fltarr(xnum)
if mb_sur_flag eq 0 then begin ; Calculate mass balance based on observed geometry (i.e. not based on modelled transient geometry)
  mb_sur = obs_sur
endif else if mb_sur_flag eq 1 then begin ; Calculate mass balance based on modelled transient geometry (i.e. not based on observed geometry)
  obs_surf = transpose(obs_sur)
  mb_sur = sur
  z = where(sur gt obs_surf, count)
  if count gt 0 then mb_sur[z] = obs_surf[z] ; For points where ice thickness is larger than observation --> take observed elevation to calculate SMB (to avoid the very occasional problems where the SMB-elevation feedback would lead to an explosion..)
endif

; ; Define the SMB year
smb_year = floor(time + 1) ; e.g. if time = 1999 (1990.0 = end of summer 1990) --> smb-year = 2000 = 1999-2000.
if smb_year gt 2100 then smb_year = 2100 ; Can be the case at last time step

; ; Define the SMB for every point on the grid:
if mb_type_flag eq 1 then begin ; Impose SMB profile (normally never used anymore)
  ela = mb_bias
  for i = 0, xnum - 1 do begin
    if sur[i] lt ela then begin
      bal[i] = (mb_sur[i] - ela) * 0.008
    endif else begin
      bal[i] = (mb_sur[i] - ela) * 0.003
    endelse
  endfor
  bal[0] = 0
  bal[1] = 0
endif else if mb_type_flag eq 5 then begin ; 5 = '1960-1990 mean' + bias eventually (this bias was already applied in 'load_smb.pro')
  for i = 0, xnum - 1 do begin
    bal[i] = fit_order2_smb_mean[2] * mb_sur[i] ^ 2 + fit_order2_smb_mean[1] * mb_sur[i] + fit_order2_smb_mean[0]
  endfor
endif else if mb_type_flag eq 6 then begin ; Every year separately: 1950/1990-->2100
  for i = 0, xnum - 1 do begin
    bal[i] = fit_order2_smb[smb_year - 1950, 2] * mb_sur[i] ^ 2 + fit_order2_smb[smb_year - 1950, 1] * mb_sur[i] + fit_order2_smb[smb_year - 1950, 0]
    if (th[i] eq 0) and (bal[i] gt 0) then bal[i] = 0 ; To avoid that area increases rapidly if year with positive SMB (if positive SMB under glaciated area)
  endfor
endif

; ; if a committed loss experiments is considered: only apply the forcing after 2017
if (chain gt 100) and (smb_year gt 2017) then begin
  for i = 0, xnum - 1 do begin
    bal[i] = fit_order2_smb_mean[2] * mb_sur[i] ^ 2 + fit_order2_smb_mean[1] * mb_sur[i] + fit_order2_smb_mean[0]
  endfor
endif

; ; Determine the ELA
ela = (-fit_order2_smb_mean[1] + sqrt(fit_order2_smb_mean[1] ^ 2 - 4 * fit_order2_smb_mean[2] * fit_order2_smb_mean[0])) / (2 * fit_order2_smb_mean[2])
if (imaginary(ela) ne 0) or (finite(ela, /nan)) then begin
  ela = -fit_order1_smb_mean[1] / fit_order1_smb_mean[2] ; Rely on first order solution
endif

; ; Impose a sinusoidal signal on top (normally never used; just for tests)
if smb_sinus_flag gt 0 then begin
  freq = smb_sinus_flag ; a
  amplitude = 0.75 ; m i.e. a^{-1}
  ;
  a = time mod freq
  b = sin((a / freq) * !pi * 2) ; Note: IDL uses radians, not degrees like MATLAB's sind()
  bal = bal + b * amplitude
endif
