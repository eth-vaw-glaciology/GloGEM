; -----------------------------------------------------
; Diagnostic printout for GloGEMflow to check stability and NaN generation
;
; @authors: Janosch Beer (2025)
; -----------------------------------------------------

compile_opt idl2

print, '--- DIAGNOSTIC PRINTOUT ---'

; Print ranges of initial arrays using original variables, with _init in print statements
print, 'dist_dx_init: min=', min(horizontal_grid_inputs.dist_dx), ' max=', max(horizontal_grid_inputs.dist_dx), ' mean=', mean(horizontal_grid_inputs.dist_dx)
print, 'sur_dx_init: min=', min(horizontal_grid_inputs.sur_dx), ' max=', max(horizontal_grid_inputs.sur_dx), ' mean=', mean(horizontal_grid_inputs.sur_dx)
print, 'width_dx_init: min=', min(horizontal_grid_inputs.width_dx), ' max=', max(horizontal_grid_inputs.width_dx), ' mean=', mean(horizontal_grid_inputs.width_dx)
print, 'thick_dx_init: min=', min(horizontal_grid_inputs.thick_dx), ' max=', max(horizontal_grid_inputs.thick_dx), ' mean=', mean(horizontal_grid_inputs.thick_dx)
print, 'bed_dx_init: min=', min(horizontal_grid_inputs.bed_dx), ' max=', max(horizontal_grid_inputs.bed_dx), ' mean=', mean(horizontal_grid_inputs.bed_dx)
print, 'width_surface_dx_init: min=', min(width_surface_dx_init), ' max=', max(width_surface_dx_init), ' mean=', mean(width_surface_dx_init)
print, 'width_mid_dx_init: min=', min(width_mid_dx_init), ' max=', max(width_mid_dx_init), ' mean=', mean(width_mid_dx_init)
print, 'width_base_dx_init: min=', min(width_base_dx_init), ' max=', max(width_base_dx_init), ' mean=', mean(width_base_dx_init)
print, 'lambda_dx_init: min=', min(lambda_dx_init), ' max=', max(lambda_dx_init), ' mean=', mean(lambda_dx_init)

print, 'xnum: ', xnum
print, 'dx: ', dx
print, 'dt: ', dt

; Diffusivity diagnostics
print, 'df_dx: min=', min(df_dx), ' max=', max(df_dx), ' mean=', mean(df_dx)
print, 'df_dx: NaNs=', total(~finite(df_dx)), ' zeros=', total(df_dx eq 0)

; Thickness diagnostics
print, 'thick_dx: min=', min(thick_dx), ' max=', max(thick_dx), ' mean=', mean(thick_dx)
print, 'thick_dx: NaNs=', total(~finite(thick_dx)), ' zeros=', total(thick_dx eq 0)

; Surface elevation diagnostics
print, 'sur_dx: min=', min(sur_dx), ' max=', max(sur_dx), ' mean=', mean(sur_dx)
print, 'sur_dx: NaNs=', total(~finite(sur_dx)), ' zeros=', total(sur_dx eq 0)

; Flux divergence diagnostics
print, 'fluxdiv_dx: min=', min(fluxdiv_dx), ' max=', max(fluxdiv_dx), ' mean=', mean(fluxdiv_dx)
print, 'fluxdiv_dx: NaNs=', total(~finite(fluxdiv_dx)), ' zeros=', total(fluxdiv_dx eq 0)

; Gradient diagnostics
print, 'grad_dx: min=', min(grad_dx), ' max=', max(grad_dx), ' mean=', mean(grad_dx)
print, 'grad_dx: NaNs=', total(~finite(grad_dx)), ' zeros=', total(grad_dx eq 0)

; Mass balance diagnostics
bal_dz_valid = bal_dz[where(bal_dz ne -99.0)]
print, 'bal_dz: min=', min(bal_dz_valid), ' max=', max(bal_dz_valid), ' mean=', mean(bal_dz_valid)
print, 'bal_dz: NaNs=', total(~finite(bal_dz_valid)), ' zeros=', total(bal_dz_valid eq 0)
print, 'bal_dx: min=', min(bal_dx), ' max=', max(bal_dx), ' mean=', mean(bal_dx)
print, 'bal_dx: NaNs=', total(~finite(bal_dx)), ' zeros=', total(bal_dx eq 0)
print, 'bal_dz: ', bal_dz
print, 'bal_dx: ', bal_dx

; Area diagnostics (if available)
if n_elements(width_mid_dx) gt 0 then $
  print, 'width_mid_dx: min=', min(width_mid_dx), ' max=', max(width_mid_dx), ' mean=', mean(width_mid_dx)

if n_elements(width_surface_dx) gt 0 then $
  print, 'width_surface_dx: min=', min(width_surface_dx), ' max=', max(width_surface_dx), ' mean=', mean(width_surface_dx)

; Sanity check for unphysical values
if max(thick_dx) gt 10000 then print, 'WARNING: Unphysical ice thickness detected!'
if max(sur_dx) gt 10000 then print, 'WARNING: Unphysical surface elevation detected!'

print, '--------------------------'
