; filepath: /home/jabeer/projects/GloGEM/flow/load_smb.pro
; Load the SMB from Matthias and transform to elevation-dependent
; relationship (for the 1961-1990 period, needed for steady state
; simulations), or for individual years (needed for transient runs).
; Biases can be applied on top of this if needed (see end of this script)

; ; Load SMB data
compile_opt idl2
if chain le 100 then begin ; chain from EURO-CORDEX ensemble
  mb_obsrcm = import_glacier_smb('../input/' + region + '/smb_rcm/chain' + string(chain, format = '(I02)') + '/belev_' + string(glacier_id, format = '(I05)') + '.dat') ; SMB as calculated based on OBS/RCM output (data from Matthias)
endif else begin ; For committed loss experiments: load data from chain01 (because are based on pre-2017 climate, and this is the same in every chain)
  mb_obsrcm = import_glacier_smb('../input/' + region + '/smb_rcm/chain01/belev_' + string(glacier_id, format = '(I05)') + '.dat') ; SMB as calculated based on OBS/RCM output (data from Matthias)
endelse

; ; Remove NaN's (-99 in data Matthias) and transform to m i.e. a^-1
i = where(mb_obsrcm[*, 1] eq -99, count)
if count gt 0 then begin
  mb_obsrcm = mb_obsrcm[where(mb_obsrcm[*, 1] ne -99), *]
endif
mb_obsrcm[*, 1 : *] = mb_obsrcm[*, 1 : *] / (rho / 1000.0) ; column 2 = 1950-1951; column 142 = 2099-2100 !!!!! From m w.e. to m i.e. !!!! (all calculations in our model are in m i.e.)

; ; Determine the mean SMB over the period 1960-1990 or over a specific period for the committed loss simulations
dims = size(mb_obsrcm, /dimensions)
rows = dims[0]
columns = dims[1]
mean_mb = fltarr(rows)

for i = 0, rows - 1 do begin
  mean_mb[i] = mean(mb_obsrcm[i, 11 : 40]) ; 1960-1990 average: classic (note: 0-based indexing)
  if chain gt 100 then begin ; Committed loss experiments
    start_year_com = floor(chain / 100)
    end_year_com = chain - 100 * start_year_com
    if start_year_com lt 20 then start_year_com = start_year_com + 100
    if end_year_com lt 20 then end_year_com = end_year_com + 100
    mean_mb[i] = mean(mb_obsrcm[i, start_year_com - 50 : end_year_com - 50]) ; Adjusted for 0-based indexing
    print, 'start_year_com = ', start_year_com
    print, 'end_year_com = ', end_year_com
  endif
endfor

; ; Generate a second-order elevation-dependent fit through these points:
; Best SMB mean fit (2nd order, i.e. parabola) over the 1960-1990 period:
fit_order2_smb_mean = poly_fit(mb_obsrcm[*, 0], mean_mb, 2)
; Best SMB fit (2nd order, i.e. parabola) for every individual year
fit_order2_smb = fltarr(columns - 1, 3)
for i = 0, columns - 2 do begin
  fit_order2_smb[i, *] = poly_fit(mb_obsrcm[*, 0], mb_obsrcm[*, i + 1], 2)
endfor

; ; Observed ELA
; ; From data:
; unique_vals = mean_mb[UNIQ(mean_mb, SORT(mean_mb))]
; ela_observed = INTERPOL(glacier_geom_lookup_sur[SORT(mean_mb)], mean_mb[SORT(mean_mb)], 0)
; From best fit (best option, because then obtain the same ELA at end of run, if SMB bias = 0)
ela_observed1 = (-fit_order2_smb_mean[1] + sqrt(fit_order2_smb_mean[1] ^ 2 - 4 * fit_order2_smb_mean[0] * fit_order2_smb_mean[2])) / (2 * fit_order2_smb_mean[0]) ; Observed ELA based on 1960-1990 mean (first possible value)
ela_observed2 = (-fit_order2_smb_mean[1] - sqrt(fit_order2_smb_mean[1] ^ 2 - 4 * fit_order2_smb_mean[0] * fit_order2_smb_mean[2])) / (2 * fit_order2_smb_mean[0]) ; Observed ELA based on 1960-1990 mean (second possible value)
ela_observed = ela_observed1
print, 'ela_observed = ', ela_observed

; ; Potentially adapt the fit to a linear fit if a problem occurred:
if imaginary(ela_observed) ne 0 then begin ; Problem occurred with 2-D fit, because max is lower than 0 (i.e. can't find ELA) --> redo with linear fit
  fit_order1_smb_mean = poly_fit(mb_obsrcm[*, 0], mean_mb, 1)
  fit_order1_smb = fltarr(columns - 1, 2)
  for i = 0, columns - 2 do begin
    fit_order1_smb[i, *] = poly_fit(mb_obsrcm[*, 0], mb_obsrcm[*, i + 1], 1)
  endfor
  ; Fill in the 'fit_order2_smb' structure:
  fit_order2_smb_mean[0] = 0
  fit_order2_smb_mean[1 : 2] = fit_order1_smb_mean[0 : 1]
  fit_order2_smb[*, 0] = 0
  fit_order2_smb[*, 1 : 2] = fit_order1_smb[*, 0 : 1]
  ;
  ela_observed = -fit_order1_smb_mean[1] / fit_order1_smb_mean[0]
  print, 'ela_observed (after linear fit) = ', ela_observed
endif

; ; Calculate the average SMB (1960-1990)
sum_smb = 0.0
counter = 0.0
for i = 1, xnum - 2 do begin ; Adjusted for 0-based indexing
  if obs_th[i] gt 0 then begin ; Only for elevations that are ice covered
    counter = counter + width_surface[i]
    bal_this_elevation = fit_order2_smb_mean[0] * obs_sur[i] ^ 2 + fit_order2_smb_mean[1] * obs_sur[i] + fit_order2_smb_mean[2]
    sum_smb = sum_smb + bal_this_elevation * width_surface[i]
  endif
endfor
bal_mean_observed = sum_smb / counter ; 1960-1990 mean SMB (based on geometry at inventory date)
print, 'bal_mean_observed = ', bal_mean_observed

; ; Potentially display the fit
if display_during_flag eq 1 then begin
  window, 4
  plot, mb_obsrcm[*, 0], mean_mb, thick = 3, title = 'Best fit SMB (before applying eventual SMB bias)', $
    xtitle = 'Elevation (m)', ytitle = 'Average SMB (over selected time period)', /xstyle, /ystyle

  x_range = findgen(100) * (max(mb_obsrcm[*, 0]) - min(mb_obsrcm[*, 0])) / 99 + min(mb_obsrcm[*, 0])
  y_fit = fit_order2_smb_mean[0] * x_range ^ 2 + fit_order2_smb_mean[1] * x_range + fit_order2_smb_mean[2]

  oplot, x_range, y_fit, thick = 2, linestyle = 2
endif

; ; Apply potential biases
if mb_bias_flag eq 0 then begin
  bias_to_be_applied = 0
endif else if string(mb_bias_flag) eq 'on' then begin ; have an integrated SMB of 0 over the glacier (typically not used anymore; was used for initial tests)
  bias_to_be_applied = -1 * bal_mean_observed
  print, 'bias_to_be_applied = ', bias_to_be_applied
endif else if mb_bias_flag ne 0 then begin
  bias_to_be_applied = -1 * (fit_order2_smb_mean[0] * (ela_observed + mb_bias_flag) ^ 2 + $
    fit_order2_smb_mean[1] * (ela_observed + mb_bias_flag) + $
    fit_order2_smb_mean[2]) ; SMB at elevation where want ELA to be (multiplied by -1)
  print, 'bias_to_be_applied = ', bias_to_be_applied
endif

fit_order2_smb_mean[2] = fit_order2_smb_mean[2] + bias_to_be_applied
fit_order2_smb[*, 2] = fit_order2_smb[*, 2] + bias_to_be_applied

; ; For some RCM chains --> no 2099-2100 SMB --> take the one from the previous year (2098-2099) in this case and impose this as the 2099-2100 SMB
if ~finite(fit_order2_smb[columns - 2, 0]) then begin ; Using columns-2 due to 0-based indexing
  fit_order2_smb[columns - 2, *] = fit_order2_smb[columns - 3, *]
endif
