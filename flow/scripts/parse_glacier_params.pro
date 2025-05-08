; ----------------------------------------------------------------------- ;
; Parse parameters for glacier model
; Returns a structure containing all parameters with default values
; overridden by any provided values
; ----------------------------------------------------------------------- ;

function parse_glacier_params, params = params, $
  aflow = aflow, calibration_method = calibration_method, dx = dx, $
  display_during_flag = display_during_flag, display_end_flag = display_end_flag, $
  dtfactor = dtfactor, dt_flag = dt_flag, flag_startobs = flag_startobs, $
  frontal_length = frontal_length, mb_bias_flag = mb_bias_flag, $
  mb_sur_flag = mb_sur_flag, mb_type_flag = mb_type_flag, nyears = nyears, $
  smb_sinus_flag = smb_sinus_flag, ss_criterion = ss_criterion, $
  start_year = start_year, width_flag = width_flag
  compile_opt idl2

  ; Define default parameters
  default_params = { $
    aflow: 1e-16, $ ; X = value of deformation-sliding factor (10^-16 Pa^-3 a^-1)
    calibration_method: 0, $ ; 0 = no calibration (for tests/examples, is not used in paper)
    dx: 0, $ ; 0 = resolution will be chosen to ensure that the observed glacier is divided into 100 grid cells
    display_during_flag: 0, $ ; 0 = do not display anything during run (geometry and smb stuff)
    display_end_flag: 0, $ ; 0 = do not display anything in the end
    dtfactor: 1, $ ; X = multiply dt by a certain factor --> can be used to avoid numerical instability
    dt_flag: 0, $ ; 0 = adaptive time step (dynamic); X = time step in years
    flag_startobs: 1, $ ; 0 = start from zero ice thickness; 1 = start from observed geometry
    frontal_length: 1.0 / 4.0, $ ; X = length of proglacial area (defined as fraction of glacier length)
    mb_bias_flag: 0, $ ; 0 = run with original climatic data (no bias)
    mb_sur_flag: 1, $ ; 0 = SMB is calculated based on observed geometry; 1 = dynamic
    mb_type_flag: 5, $ ; 5 = 1960-1990 mean from E-OBS (+ eventual perturbation)
    nyears: 5000, $ ; X = number of years for simulation
    smb_sinus_flag: 0, $ ; 0 = no perturbation on SMB signal
    ss_criterion: 0.01, $ ; X = steady state is reached when the volume change is less than X percent per dtdiag
    start_year: 0, $ ; X = year in which the simulation starts
    width_flag: 2 $ ; 2 = trapezium transect (classic)
    }

  ; Start with default parameters
  working_params = default_params

  ; Apply changes from params structure if provided
  if n_elements(params) ne 0 then begin
    ; Get tags from the provided params structure
    p_tags = tag_names(params)
    default_tags = tag_names(default_params)

    ; Loop through each tag in the provided params
    for i = 0, n_elements(p_tags) - 1 do begin
      tag = p_tags[i]
      ; Check if this tag exists in the default parameters
      idx = where(strlowcase(default_tags) eq strlowcase(tag), count)
      if count gt 0 then begin
        ; Copy the value from params to working_params
        working_params.(idx[0]) = params.(i)
      endif
    endfor
  endif

  ; Apply individual keyword parameters (these override both defaults and params structure)
  if n_elements(aflow) ne 0 then working_params.aflow = aflow
  if n_elements(calibration_method) ne 0 then working_params.calibration_method = calibration_method
  if n_elements(dx) ne 0 then working_params.dx = dx
  if n_elements(display_during_flag) ne 0 then working_params.display_during_flag = display_during_flag
  if n_elements(display_end_flag) ne 0 then working_params.display_end_flag = display_end_flag
  if n_elements(dtfactor) ne 0 then working_params.dtfactor = dtfactor
  if n_elements(dt_flag) ne 0 then working_params.dt_flag = dt_flag
  if n_elements(flag_startobs) ne 0 then working_params.flag_startobs = flag_startobs
  if n_elements(frontal_length) ne 0 then working_params.frontal_length = frontal_length
  if n_elements(mb_bias_flag) ne 0 then working_params.mb_bias_flag = mb_bias_flag
  if n_elements(mb_sur_flag) ne 0 then working_params.mb_sur_flag = mb_sur_flag
  if n_elements(mb_type_flag) ne 0 then working_params.mb_type_flag = mb_type_flag
  if n_elements(nyears) ne 0 then working_params.nyears = nyears
  if n_elements(smb_sinus_flag) ne 0 then working_params.smb_sinus_flag = smb_sinus_flag
  if n_elements(ss_criterion) ne 0 then working_params.ss_criterion = ss_criterion
  if n_elements(start_year) ne 0 then working_params.start_year = start_year
  if n_elements(width_flag) ne 0 then working_params.width_flag = width_flag

  return, working_params
end
