; filepath: /Users/janoschbeer/Library/Mobile Documents/com~apple~CloudDocs/PhD/projects/GloGEM/flow/scripts/post_timeloop.idl
; A few operations to be performed at the end of the transient simulation
; (i.e. at the end of the run): calculate the final ELA, save the variables in the
; workspace in a file, and potentially perform some final plotting

; getting the directory of the current script
compile_opt idl2
routine_path = routine_filepath()
current_dir = file_dirname(routine_path)

; ; ELA, based on best fit (best option, because then obtain the same ELA as at begin of run, if SMB bias = 0)
ela_ss1 = (-fit_order2_smb_mean[1] + sqrt(fit_order2_smb_mean[1] ^ 2 - 4 * fit_order2_smb_mean[0] * fit_order2_smb_mean[2])) / (2 * fit_order2_smb_mean[0])
; ela_ss2=(-fit_order2_smb_mean[1]-sqrt(fit_order2_smb_mean[1]^2-4*fit_order2_smb_mean[0]*fit_order2_smb_mean[2]))/(2*fit_order2_smb_mean[0])
ela_ss = ela_ss1

print, 'display_end_flag:', display_end_flag

; ; Some final plotting
if (size(vol, /type) ne 7 && finite(vol)) || (size(vol, /type) eq 7 && vol ne 'out') then begin
  if display_end_flag gt 0 then begin
    @plot_final
  endif
endif

; ; Remove unnecessary rows in matrices and some variables that we do not want to save (to reduce the total file size!)
aflow_hist = aflow_hist[0 : counter_diag]
area_hist = area_hist[0 : counter_diag]
bal_mean_hist = bal_mean_hist[0 : counter_diag]
time_hist = time_hist[0 : counter_diag]
dt_hist = dt_hist[0 : counter_diag]
df_max_hist = df_max_hist[0 : counter_diag]
height_front_hist = height_front_hist[0 : counter_diag]
length_hist = length_hist[0 : counter_diag]
vol_hist = vol_hist[0 : counter_diag]
;
bal_hist = bal_hist[0 : counter_diag, *]
fluxdiv_plot_hist = fluxdiv_plot_hist[0 : counter_diag, *]
th_hist = th_hist[0 : counter_diag, *]

;
; Clear variables to save memory
; Note: IDL doesn't have a direct equivalent to MATLAB's "clear"
; but we can set variables to null or undefined
fluxdiv_plot_hist = !null
mb_obsrcm = !null
matrix = !null
matrix_obs = !null

; ; Saving the files
if mb_type_flag eq 5 then begin
  if calibration_method eq 1 then begin
    save, filename = current_dir + '/../output/centraleurope/data_rcm/chain' + string(chain, format = '(I02)') + '/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_1990_ss.sav'
  endif else if calibration_method eq 2 then begin
    save, filename = current_dir + '/../output/centraleurope/data_rcm/chain' + string(chain, format = '(I02)') + '/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_1950_ss.sav'
  endif
endif else if mb_type_flag eq 6 and floor(time) lt 2017 then begin
  save, filename = current_dir + '/../output/centraleurope/data_rcm/chain' + string(chain, format = '(I02)') + '/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_' + string(inventory_date_id) + '_tr.sav'
endif else if mb_type_flag eq 6 and floor(time) eq 2017 then begin
  save, filename = current_dir + '/../output/centraleurope/data_rcm/chain' + string(chain, format = '(I02)') + '/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_2017_tr.sav'
endif else if mb_type_flag eq 6 and floor(time) ge 2100 then begin
  save, filename = current_dir + '/../output/centraleurope/data_rcm/chain' + string(chain, format = '(I02)') + '/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_' + string(floor(time)) + '_tr.sav'
endif

if calibration_method eq 0 then begin ; Only for test-cases. Normally not used
  save, filename = current_dir + '/example_output.sav'
endif
