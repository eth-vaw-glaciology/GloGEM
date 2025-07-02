; -----------------------------------------------------------
; Created by:
; Lander Van Tricht
; Date of last modification:
; 24/01/2025
; Name:
; WRITE_RESULTS_FILES_DAILY
; Purpose:
; Writes model results for all desired output variables into .dat files.
; Inputs:
; outf_names      - Array of output filenames
; ANNUAL (The values below are stored with annual values)
; areas           - Array of glacier areas
; volumes         - Array of glacier volumes
; mb              - Array of mass balance values
; wb              - Array of winter balance values
; smelt           - Array of snow melt
; imelt           - Array of ice melt
; accum           - Array of accumulation data
; rain            - Array of rain data
; ela             - Array of equilibrium line altitude data
; aar             - Array of accumulation area ratio data
; refre           - Array of refreezing data
; hmin_g          - Array of glacier minimum height data
; flux_calv       - Array of calving flux data
; discharge       - Array of discharge data
; discharge_gl    - Array of glacier discharge data
; MONTHLY (The variables below are stored with daily values)
; accmo           - Array of accumulation
; precmo          - Array of precipitation
; mellmo          - Array of melt
; balmo           - Array of mass balance
; refrmo          - Array of refreezing
; id              - Identifier for each glacier to be modelled in a region
; gg, g           - Glacier group and index
; years           - Number of simulation years
; y               - Array of year values
; -----------------------------------------------------------

pro WRITE_RESULTS_FILES_MONTHLY, format_of, time_resolution, outf_names, areas, volumes, mb, wb, smelt, imelt, accum, rain, ela, aar, refre, hmin_g, flux_calv, discharge, discharge_gl, balmo, precmo, accmo, mellmo, refrmo, id, gg, g, years, y
  compile_opt idl2

  ; Validate inputs
  if n_elements(outf_names) eq 0 then begin
    print, 'Error: outf_names is required.'
    RETURN
  endif

  ; Validate time resolution (ensure it's monthly)
  if time_resolution ne 'monthly' then begin
    print, 'Error: time_resolution must be "monthly".'
    RETURN
  endif

  if time_resolution eq 'monthly' then begin
    ii = where(outf_names ne '', ci)
    for i = 0, ci - 1 do begin
      case ii[i] of
        0: var = areas
        1: var = volumes
        2: var = mb
        3: var = wb
        4: var = smelt
        5: var = imelt
        6: var = accum
        7: var = rain
        8: var = ela
        9: var = aar
        10: var = refre
        11: var = hmin_g
        12: var = flux_calv
        13: var = discharge
        14: var = discharge_gl
        15: var = balmo
        16: var = precmo
        17: var = accmo
        18: var = melmo
        19: var = refrmo
      endcase
      if ii[i] ge 13 then a = 12 else a = 1
      printf, string(i + 10, fo = '(i2)'), id[gg[g]] + ' ' + string(var, fo = '(' + strcompress(string(years) * a, /remove_all) + format_of[i] + ')')
    endfor
  endif
end
