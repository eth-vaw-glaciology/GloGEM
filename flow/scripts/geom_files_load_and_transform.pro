; Inventory date is loaded and the glacier geometry is loaded from files
; provided by Matthias Huss. Subsequently, the geometric info from a
; previous model run can eventually be loaded.

; ; getting the directory of the current script
compile_opt idl2
routine_path = routine_filepath()
current_dir = file_dirname(routine_path)

; ; RGI inventory date
restore, current_dir + '/../input/centraleurope/inventory_date.sav' ; Load the RGI inventory_date of all glaciers
inventory_date_id = inventory_date[glacier_id] ; RGI inventory date for specific glacier
inventory_date = 0 ; Clear the RGI inventory_date of all glaciers (not needed anymore)

; ; Load geometry from the files of Matthias with 'load_glacier' function (this needs to be done in every case, also when simulations will start from a modelled glacier geometry)
result = load_glacier(glacier_id, region, dx, frontal_length, display_during_flag)
sur_input = result.sur_input
th_input = result.th_input
width_input = result.width_input
x_input = result.x_input
dx = result.dx
volume_Huss_1d_fixeddistance = result.volume_huss_1D_fixeddistance
area_Huss_1d_fixeddistance = result.area_huss_1D_fixeddistance
length_fixeddistance = result.length_fixeddistance

; ; If needed: can load data from a modelled geometry (can be a steady state or a transient geometry --> in paper: always start simulations in 1950/1990 from a steady state)
if flag_startobs eq 2 then begin ; Start from a modelled state
  ; Keep the observed surface (sur_input), observed thickness (th_input), observed width (width_input), observed volume (volume_Huss_1d_fixeddistance), observed area (area_Huss_1d_fixeddistance) and observed length (length_fixeddistance) (observed = at RGI inventory date)

  ; Load/Overwrite: 'x_input','dx','sur','th' from calibrated geometry (is always from chain01)
  if start_year eq 1950 then begin ; Calibration method == 2
    file_path = '../output/' + region + '/data_rcm/chain01/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_1950_ss.mat'
    restore, file_path
  endif else if start_year eq 1990 then begin ; Calibration method == 1
    file_path = '../output/' + region + '/data_rcm/chain01/calibration' + string(calibration_method, format = '(I0)') + '/variables_' + string(glacier_id, format = '(I05)') + '_1990_ss.mat'
    restore, file_path
  endif
  ; Could eventually also add cases where start from other periods (e.g. at inventory date or in 2017), but this is not used so far (all transient simulations start at the steady state date)
endif
