; -----------------------------------------------------------------------
; ---- Flowline mass balance: compute MB directly on horizontal grid
; -----------------------------------------------------------------------
; This replaces the grid-conversion approach (massbal_coupled + writeback).
; Mass balance is computed at each flowline cell using sur_dx[i] for
; elevation, applying the same temperature-index model as GloGEM.
;
; Uses the same climate data, DDF parameters, and lapse rates as GloGEM.
; The flow model then uses bal_dx directly — no interpolation needed.
;
; Called from glogemflow_coupled.pro AFTER GloGEM's monthly loop has
; determined the climate for this year.
;
; Inputs (from GloGEM scope):
; sur_dx, thick_dx, xnum — flowline geometry
; temp, prec, cyear, cmon — climate time series
; dtdz, dpdz, hclim — lapse rates and reference elevation
; t_offset, c_prec — calibration parameters
; DDFsnow, DDFice, T_thres, t_melt — melt model parameters
; mon_len — days per month
; tran, ye — time info
; bal_month, dd_thresholds — hydrological year definition
;
; Outputs:
; bal_dx — annual mass balance on flowline grid (m ice / yr)
; -----------------------------------------------------------------------
compile_opt idl2

; ---- Initialise flowline arrays on first call ----
if n_elements(sno_dx) eq 0 then begin
  sno_dx = dblarr(xnum) ; snow reservoir (m w.e.)
  snostor_dx = dblarr(xnum) ; snow storage from previous year
  sur_type_dx = intarr(xnum) ; surface type: 0=ice, 1=snow, 2=firn
  firn_dx = intarr(xnum) ; firn flag
  bal_yr_dx = dblarr(xnum, 5) ; store last 5 years for firn detection
  ; Set initial surface type: snow where there's ice
  ii = where(thick_dx gt 0, c)
  if c gt 0 then sur_type_dx[ii] = 1 ; start with snow cover
endif

; ---- Annual mass balance computation ----
; Replicate GloGEM's monthly loop but on the flowline grid
bal_dx = dblarr(xnum) ; annual balance (m ice / yr)
bal_dx_we = dblarr(xnum) ; annual balance (m w.e. / yr)
melt_dx = dblarr(xnum)
acc_dx = dblarr(xnum)

; Glacier mask on flowline
gl_dx = intarr(xnum)
ii_ice = where(thick_dx gt 0, c_ice)
if c_ice gt 0 then gl_dx[ii_ice] = 1

; Monthly climate counter — use the same ccmon counter as GloGEM
; GloGEM has already run its monthly loop, so we know the climate year.
; We need to re-loop over the months for the flowline grid.
ccmon_flow = 0l

; Loop over the two parts of the hydrological year (same structure as GloGEM)
for d_flow = 0, 1 do begin
  if d_flow eq 0 then st_flow = bal_month else st_flow = 1
  if d_flow eq 0 then en_flow = dd_thresholds[3] else en_flow = bal_month - 1

  for m_flow = st_flow, en_flow do begin
    psg_dx = dblarr(xnum)
    mel_dx = dblarr(xnum)

    ; Correct snow storage at start of year
    if bal_month eq dd_thresholds[2] then if m_flow eq 1 then sno_dx = sno_dx - snostor_dx
    if bal_month eq dd_thresholds[0] then if m_flow eq dd_thresholds[1] then sno_dx = sno_dx - snostor_dx
    jj = where(sno_dx lt 0, cj)
    if cj gt 0 then sno_dx[jj] = 0

    ; ---- Climate extrapolation to flowline elevations ----
    if time_resolution eq 'monthly' then cdm_flow = cmon else cdm_flow = cday
    if ccmon_flow eq 0 then jjclim_flow = where(cyear eq ye - 1 + tran[0] and cdm_flow eq m_flow)

    ; Temperature at each flowline cell
    tg_dx = temp[jjclim_flow[0] + ccmon_flow] + (sur_dx - hclim) * dtdz[m_flow - 1] + t_offset

    ; ---- Accumulation ----
    pc_dx = prec[jjclim_flow[0] + ccmon_flow] * c_prec / 1000.0d0
    pg_dx = pc_dx + pc_dx * ((sur_dx - hclim) / 10000.0d0) * dpdz

    ; Snow/rain partitioning
    for i = 0, xnum - 1 do begin
      if tg_dx[i] lt T_thres - 1 then psg_dx[i] = pg_dx[i] $
      else if tg_dx[i] lt T_thres + 1 then psg_dx[i] = pg_dx[i] * (-(tg_dx[i] - T_thres - 1.0) / 2.0) $
      else psg_dx[i] = 0d0
    endfor
    psg_dx = psg_dx * snow_multiplier

    ccmon_flow = ccmon_flow + 1

    ; ---- Melt (temperature-index model) ----
    ; Only meltmodel '1' (degree-day) is implemented here
    ; This covers the vast majority of GloGEM applications
    for i = 0, xnum - 1 do begin
      if gl_dx[i] eq 0 then continue ; skip ice-free cells
      if tg_dx[i] le t_melt then continue ; no melt below threshold

      if sur_type_dx[i] eq 1 then begin ; snow
        mel_dx[i] = DDFsnow * tg_dx[i] * mon_len[m_flow - 1] / 1000.0d0
      endif else if sur_type_dx[i] eq 2 then begin ; firn
        mel_dx[i] = (0.5 * DDFice + 0.5 * DDFsnow) * tg_dx[i] * mon_len[m_flow - 1] / 1000.0d0
      endif else begin ; ice (sur_type = 0)
        mel_dx[i] = DDFice * tg_dx[i] * mon_len[m_flow - 1] / 1000.0d0
      endelse
    endfor

    ; ---- Update snow reservoir ----
    sno_dx = sno_dx + psg_dx - mel_dx
    jj = where(sno_dx gt 0, cj)
    if cj gt 0 then sur_type_dx[jj] = 1 ; snow surface
    jj = where(sno_dx lt 0, cj)
    if cj gt 0 then begin
      ; Correct for over-melt of snow
      hh = where(gl_dx[jj] eq 0, ch)
      if ch gt 0 then mel_dx[jj[hh]] = mel_dx[jj[hh]] + sno_dx[jj[hh]]
      sno_dx[jj] = 0
    endif

    ; Update surface type
    jj = where(sno_dx eq 0 and gl_dx eq 1, cj)
    if cj gt 0 then sur_type_dx[jj] = 0 ; bare ice
    jj = where(sno_dx eq 0 and firn_dx eq 1, cj)
    if cj gt 0 then sur_type_dx[jj] = 2 ; firn

    ; Accumulate annual balance (m w.e.)
    bal_dx_we = bal_dx_we + psg_dx - mel_dx
  endfor ; months
endfor ; parts of hydrological year

; ---- Store snow reservoir for next year ----
if n_elements(snostor_dx) eq 0 then snostor_dx = dblarr(xnum)
snostor_dx = sno_dx

; ---- Update firn coverage (5-year average) ----
; Shift balance history and store current year
if n_elements(bal_yr_dx) gt 0 then begin
  for k = 3, 0, -1 do bal_yr_dx[*, k + 1] = bal_yr_dx[*, k]
  bal_yr_dx[*, 0] = bal_dx_we
  ; Firn where 5-year average balance > 0
  balm_dx = dblarr(xnum)
  for i = 0, xnum - 1 do balm_dx[i] = mean(bal_yr_dx[i, *])
  firn_dx = intarr(xnum)
  ii = where(balm_dx gt 0 and gl_dx eq 1, ci)
  if ci gt 0 then firn_dx[ii] = 1
endif

; ---- Convert to m ice / yr for the flow model ----
; The SIA continuity equation uses ice-equivalent thickness change
bal_dx = bal_dx_we / 0.917d0

; ---- Zero balance where no ice and balance is positive ----
; (prevent spontaneous ice growth in ice-free cells)
ii_noice = where(thick_dx le 0d0, c_noice)
if c_noice gt 0 then begin
  for i = 0, c_noice - 1 do begin
    if bal_dx[ii_noice[i]] gt 0d0 then bal_dx[ii_noice[i]] = 0d0
  endfor
endif

; ---- Safety checks ----
for i = 0, xnum - 1 do begin
  if ~finite(bal_dx[i]) then bal_dx[i] = 0d0
  bal_dx[i] = (bal_dx[i] > (-50d0)) < 50d0
endfor
