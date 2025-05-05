; -----------------------------------------------------------------------
; --- This script calculates the 1960-1990 SMB for the geometry at the --
; ------------- inventory date (static, i.e. no ice dynamics)------------
; -----------------------------------------------------------------------

; Close all windows and clear memory
compile_opt idl2
widget_control, /reset
heap_gc

chain_id = [1] ; Past: always taken from chain01
figure_flag = 0 ; 0 = don't display any figures; 1 = display figures

rho = 900.0

; getting the directory of the current script
routine_path = routine_filepath()
current_dir = file_dirname(routine_path)

; Load glacier stats file
restore, current_dir + '/glacier_stats.sav'
id = transpose(index_larger_than_1_km_glaciers_save) + 1 ; 1-based index
id_start = 0
id_end = 4000
idx = where(id lt id_start, count)
if count gt 0 then id = id[where(id ge id_start)]
idx = where(id gt id_end, count)
if count gt 0 then id = id[where(id le id_end)]
idx = where(id eq 3678, count)
if count gt 0 then id = id[where(id ne 3678)]

start_year_smb = 1961 ; 1961
end_year_smb = 1990 ; 1990
; need start_year_smb=1961 && end_year_smb=1990 to save files for run for chain 01 (because need SMB info for first guess ELA change)

for chain_idx = 0, n_elements(chain_id) - 1 do begin
  chain = chain_id[chain_idx]
  for g_idx = 0, n_elements(id) - 1 do begin
    glacier_id = id[g_idx]
    print, 'Glacier ID: ', glacier_id

    ; Keep only needed variables
    KEEP_VARS = ['glacier_id', 'id', 'rho', 'start_year_smb', 'end_year_smb', 'chain', 'figure_flag']

    ; Import SMB data
    chainstr = string(chain, format = '(I02)')
    idstr = string(glacier_id, format = '(I05)')
    mb_obs_eobs = import_glacier_smb(current_dir + '/smb_rcm/chain' + chainstr + '/belev_' + idstr + '.dat') ; SMB calculated from OBS/RCM (Data from Matthias from March 2018)
    glacier_geom = import_glacier_geometry_1d(current_dir + '/flowline_geom/' + idstr + '.dat')

    ; Remove invalid data points
    idx = where(mb_obs_eobs[*, 1] eq -99, count)
    if count gt 0 then begin
      mb_obs_eobs = mb_obs_eobs[where(mb_obs_eobs[*, 1] ne -99), *]
      glacier_geom = glacier_geom[where(mb_obs_eobs[*, 1] ne -99), *]
    endif

    ; Convert from m w.e. to m i.e.
    mb_obs_eobs[*, 1 : *] = mb_obs_eobs[*, 1 : *] / (rho / 1000.0) ; column 1 = 1950-1951; column 141 = 2099-2100

    rows = n_elements(mb_obs_eobs[*, 0])
    mean_mb = fltarr(rows)

    ; Calculate mean mass balance for selected period
    for i = 0, rows - 1 do begin
      mean_mb[i] = mean(mb_obs_eobs[i, (start_year_smb - 1949) : (end_year_smb - 1949)])
    endfor

    ; Best SMB mean fit (2nd order, i.e. parabola) over the [start_year_smb]-[end_year_smb] period
    fit_order2_smb_mean = poly_fit(mb_obs_eobs[*, 0], mean_mb, 2)

    ; Calculate observed ELA
    ela_observed = (-fit_order2_smb_mean[1] + sqrt(fit_order2_smb_mean[1] ^ 2 - 4 * fit_order2_smb_mean[2] * fit_order2_smb_mean[0])) / (2 * fit_order2_smb_mean[2])

    ; Calculate the average SMB ([start_year_smb]->[end_year_smb]), based on best-fit
    sum_smb = 0.0
    counter = 0.0
    for i = 0, rows - 1 do begin
      counter += glacier_geom[i, 3] ; glacier_geom[i,3] = area for this elevation band
      bal_this_elevation = fit_order2_smb_mean[2] * mb_obs_eobs[i, 0] ^ 2 + fit_order2_smb_mean[1] * mb_obs_eobs[i, 0] + fit_order2_smb_mean[0]
      sum_smb += bal_this_elevation * glacier_geom[i, 3]
    endfor
    bal_mean_observed = sum_smb / counter ; Mean SMB based on geometry at inventory date

    ; Repeat with different ELAs (to find which ELA dif is needed to have a zero MB)
    ela_change_matrix = fltarr(41, 2) ; -200 to 200 in steps of 10 = 41 elements
    ela_counter = 0

    for ela_change = -200, 200, 10 do begin
      ela_counter = (ela_change + 200) / 10
      sum_smb = 0.0
      counter = 0.0

      for i = 0, rows - 1 do begin
        counter += glacier_geom[i, 3] ; glacier_geom[i,3] = area for this elevation band
        ; Use correct coefficient ordering - [2] is quadratic, [1] is linear, [0] is constant
        bal_this_elevation = fit_order2_smb_mean[2] * (mb_obs_eobs[i, 0] - ela_change) ^ 2 + $
          fit_order2_smb_mean[1] * (mb_obs_eobs[i, 0] - ela_change) + fit_order2_smb_mean[0]
        sum_smb += bal_this_elevation * glacier_geom[i, 3]
      endfor

      bal_mean_observed_different_ela = sum_smb / counter
      ela_change_matrix[ela_counter, 0] = ela_change
      ela_change_matrix[ela_counter, 1] = bal_mean_observed_different_ela
    endfor

    ; ELA at which the SMB = 0: based on linear interpolation
    ela_dif_tohave0smb = interpol(ela_change_matrix[*, 0], ela_change_matrix[*, 1], 0)

    ; Check that SMB is really (close to) zero for this ELA
    sum_smb = 0.0
    counter = 0.0
    for i = 0, rows - 1 do begin
      counter += glacier_geom[i, 3] ; glacier_geom[i,3] = area for this elevation band
      ; Use correct coefficient ordering - [2] is quadratic, [1] is linear, [0] is constant
      bal_this_elevation = fit_order2_smb_mean[2] * (mb_obs_eobs[i, 0] - ela_dif_tohave0smb) ^ 2 + $
        fit_order2_smb_mean[1] * (mb_obs_eobs[i, 0] - ela_dif_tohave0smb) + fit_order2_smb_mean[0]
      sum_smb += bal_this_elevation * glacier_geom[i, 3]
    endfor

    bal_mean_want_to_be_zero = sum_smb / counter

    ; Save results for past evolution simulations
    if (start_year_smb eq 1961) and (end_year_smb eq 1990) and (chain eq 1) then begin
      ela_dif_tohave0smb_6190 = ela_dif_tohave0smb
      ; Instead of saving a structure
      save, bal_mean_observed, ela_observed, ela_dif_tohave0smb_6190, $
        filename = current_dir + '/smb_rcm/chain' + chainstr + '/smb6190_' + idstr + '.sav'
    endif
  endfor
endfor
