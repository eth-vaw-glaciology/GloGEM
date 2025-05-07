; -----------------------------------------------------------------------
; ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)----
; ------------------ Volume calibration function   ----------------------
; ----- (called from 'main' script if opt for volume calib. only or -----
; from 'length_calibration' function if apply the 'volume+length' calib.)
; -----------------------------------------------------------------------

function volume_calibration, glacier_id, region, chain, poly_fit_flag, ela_change, frontal_length, dtfactor, $
  calibration_method, aflow_guess1, inventorydate
  compile_opt idl2

  ; ; Define a few parameters (does normally not need to be modified)
  if calibration_method eq 1 then begin ; Classic, volume+length calibration: 1990 steady state --> match inventory date length and volume
    start_year = 1990
  endif else if calibration_method eq 2 then begin ; Sensitivity experiment for paper: volume calibraion only: 1950 steady state --> match inventory date volume
    start_year = 1950
  endif
  nyears = inventorydate - start_year
  vol_precision = 0.01 ; Want the volume to be matched within 1%

  ; ; First attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias on this ('mb_bias_flag',ela_change)
  ; ; These runs start from an ice-free topography ('flag_startobs',0)
  res = glacier(glacier_id, region, chain, aflow = aflow_guess1, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
    frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method) ; 1950/1990 steady state
  vol_obs = res[0]
  vol = res[1]

  ; Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
  while (vol eq 'out') or (finite(vol) eq 0) do begin ; Need this 'WHILE loop' to avoid problems when switch from 'nan' --> 'out'
    if vol eq 'out' then begin ; Ice is leaving the domain, re-run, with bigger larger frontal area
      while vol eq 'out' do begin
        frontal_length = frontal_length + 0.25
        print, frontal_length
        res = glacier(glacier_id, region, chain, aflow = aflow_guess1, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
          frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
        vol_obs = res[0]
        vol = res[1]
        if frontal_length gt 1.5 then begin ; Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
          vol = !values.f_nan
        endif
      endwhile
    endif

    if finite(vol) eq 0 then begin ; Instability. Re-run, with smaller time-step
      while (finite(vol) eq 0) or (vol eq 'out') do begin
        dtfactor = dtfactor * 0.5
        print, dtfactor
        if dtfactor lt 5e-2 then break
        res = glacier(glacier_id, region, chain, aflow = aflow_guess1, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
          frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
        vol_obs = res[0]
        vol = res[1]
        if vol eq 'out' then vol = !values.f_nan ; to not leave loop in the case vol is 'out'
      endwhile
      if dtfactor lt 5e-2 then begin
        vol = !values.f_nan
        break
      endif
    endif
  endwhile

  ; ; First attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003)
  ; ; This run starts from the modelled state-state geometry ('flag_startobs',2)
  res = glacier(glacier_id, region, chain, aflow = aflow_guess1, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
    nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
    calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
  vol_obs = res[0]
  vol = res[1]

  if (finite(vol) eq 0) or (vol eq 'out') then begin ; in case a problem occurs in the transient run (SS --> inventory date): launch one more with a smaller time step
    dtfactor = dtfactor / 2
    res = glacier(glacier_id, region, chain, aflow = aflow_guess1, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
      nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
      calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
    vol_obs = res[0]
    vol = res[1]
  endif

  if (finite(vol) eq 0) or (vol eq 'out') or (vol eq 0) then begin ; Stop calculations
    print, 'First volume calibration effort was unsuccesful (instability/ice leaving the domain)...Stopped volume calibration procedure'
  endif else begin ; Continue!

    ; ; Write results from this first volume calibration effort down in 'rmse_vol'
    rmse_vol = dblarr(6, 3) ; Initialize array for storing results
    rmse_vol[0, 0] = aflow_guess1
    rmse_vol[0, 1] = vol
    rmse_vol[0, 2] = vol - vol_obs

    ; ; Estimate 'aflow' for second attempt (needed for following plot; may not be needed for calculations if modelled volume first test was within X% of observed)
    vol_multiplication = vol_obs / vol ; factor by which the volume of the first test needs to be multiplied to obtain the observed volume
    print, 'vol_multiplication = ', vol_multiplication
    aflow_guess2 = aflow_guess1 * (vol_multiplication) ^ (-4)
    print, 'aflow_guess2 = ', aflow_guess2

    ; ; Plot first attempt
    WINDOW, 0, xsize = 800, ysize = 600, title = 'Volume Calibration'
    !p.multi = [0, 1, 1]
    !p.charsize = 1.5
    !p.charthick = 2
    !x.thick = 2
    !y.thick = 2

    ; Area plot for volume range
    x_vals = [0, aflow_guess1 * 100]
    y_upper = [vol_obs / 1e9 * (1 + vol_precision), vol_obs / 1e9 * (1 + vol_precision)]
    y_lower = [vol_obs / 1e9 * (1 - vol_precision), vol_obs / 1e9 * (1 - vol_precision)]
    polyfill, [x_vals, reverse(x_vals)], [y_upper, reverse(y_lower)], color = 200

    PLOT, rmse_vol[0 : 0, 0], rmse_vol[0 : 0, 1] / 1e9, psym = 8, symsize = 2, xstyle = 1, ystyle = 1, thick = 3, $
      xtitle = 'Deformation-sliding factor a (Pa^(-3) a^(-1))', ytitle = 'Volume total (km^3)', /nodata
    polyfill, [x_vals, reverse(x_vals)], [y_upper, reverse(y_lower)], color = 200
    oplot, [0, max([aflow_guess1, aflow_guess2])], [vol_obs, vol_obs] / 1e9, thick = 3, linestyle = 2
    oplot, rmse_vol[0 : 0, 0], rmse_vol[0 : 0, 1] / 1e9, psym = 8, symsize = 2, thick = 3
    xyouts, 0.1 * max([aflow_guess1, aflow_guess2]), 0.9 * max([vol_obs / 1e9, rmse_vol[0, 1] / 1e9]), 'Target volume', charsize = 1.5

    ; ; If the first attempt was not within X% of the observed volume (X=vol_precision*100) --> proceed to second attempt
    if abs((vol - vol_obs) / vol_obs) gt vol_precision then begin
      ; ; Second attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias on this ('mb_bias_flag',ela_change)
      ; ; These runs start from an ice-free topography ('flag_startobs',0)
      res = glacier(glacier_id, region, chain, aflow = aflow_guess2, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
        frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method) ; 1950/1990 steady state
      vol_obs = res[0]
      vol = res[1]

      ; Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
      while (vol eq 'out') or (finite(vol) eq 0) do begin ; Need this 'WHILE loop' to avoid problems when switch from 'nan' --> 'out'
        if vol eq 'out' then begin ; Ice is leaving the domain, re-run, with bigger larger frontal area
          while vol eq 'out' do begin
            frontal_length = frontal_length + 0.25
            print, frontal_length
            res = glacier(glacier_id, region, chain, aflow = aflow_guess2, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
              frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
            vol_obs = res[0]
            vol = res[1]
            if frontal_length gt 1.5 then begin ; Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
              vol = !values.f_nan
            endif
          endwhile
        endif

        if finite(vol) eq 0 then begin ; Instability. Re-run, with smaller time-step
          while (finite(vol) eq 0) or (vol eq 'out') do begin
            dtfactor = dtfactor * 0.5
            print, dtfactor
            if dtfactor lt 5e-2 then break
            res = glacier(glacier_id, region, chain, aflow = aflow_guess2, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
              frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
            vol_obs = res[0]
            vol = res[1]
          endwhile
          if dtfactor lt 5e-2 then begin
            vol = !values.f_nan
            break
          endif
        endif
      endwhile

      ; ; Second attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003)
      ; ; This run starts from the modelled state-state geometry ('flag_startobs',2)
      res = glacier(glacier_id, region, chain, aflow = aflow_guess2, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
        nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
        calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
      vol_obs = res[0]
      vol = res[1]

      if (finite(vol) eq 0) or (vol eq 'out') then begin ; in case a problem occurs in the transient run (SS --> inventory date): launch one more with a smaller time step
        dtfactor = dtfactor / 2
        res = glacier(glacier_id, region, chain, aflow = aflow_guess2, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
          nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
          calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
        vol_obs = res[0]
        vol = res[1]
      endif

      ; ; Only continue if second test resulted in a real value:
      if (finite(vol) eq 0) or (vol eq 'out') then begin
        print, 'Second volume calibration effort was unsuccesful (instability/ice leaving the domain)...Stopped volume calibration procedure'
      endif else begin
        ; ; Write results from this second volume calibration effort down in 'rmse_vol'
        rmse_vol[1, 0] = aflow_guess2
        rmse_vol[1, 1] = vol
        rmse_vol[1, 2] = vol - vol_obs

        ; ; Plot second attempt:
        oplot, [0, aflow_guess2], [vol_obs, vol_obs] / 1e9, thick = 3, linestyle = 2
        oplot, rmse_vol[0 : 1, 0], rmse_vol[0 : 1, 1] / 1e9, psym = 8, symsize = 2, thick = 3

        ; ; Estimate new value for deformation-sliding factor (a) based on first two attempts:
        p = poly_fit(rmse_vol[0 : 1, 0], rmse_vol[0 : 1, 1], 1)
        p_volobs = p
        p_volobs[n_elements(p_volobs) - 1] = p_volobs[n_elements(p_volobs) - 1] - vol_obs
        r = fz_roots(p_volobs) ; Replace with appropriate root-finding function for IDL
        aflow = r[0]
        print, 'aflow = ', aflow

        if aflow lt 0 then aflow = 0.5 * min(rmse_vol[0 : 1, 0])

        if poly_fit_flag eq 0 then begin ; For linear fit only
          ; If needed: change order, to make sure that closest value is on second row (as this will be used for the next polyfit, at end of the 'for' loop)
          if rmse_vol[0, 2] lt rmse_vol[1, 2] then begin
            a = rmse_vol[0, *]
            rmse_vol[0, *] = rmse_vol[1, *]
            rmse_vol[1, *] = a
          endif
        endif

        ; ; If the second guess was not within X% of the observed volume (X=vol_precision*100) --> proceed to additional attempts (#3 to #6)
        if abs((vol - vol_obs) / vol_obs) gt vol_precision then begin
          for i = 3, 6 do begin
            print, 'aflow = ', aflow

            ; ; Next attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias
            res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
              frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method) ; 1950/1990 steady state
            vol_obs = res[0]
            vol = res[1]

            ; Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
            while (vol eq 'out') or (finite(vol) eq 0) do begin ; Need this 'WHILE loop' to avoid problems when switch from 'nan' --> 'out'
              if vol eq 'out' then begin ; Ice is leaving the domain, re-run, with bigger larger frontal area
                while vol eq 'out' do begin
                  frontal_length = frontal_length + 0.25
                  print, frontal_length
                  res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
                    frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
                  vol_obs = res[0]
                  vol = res[1]
                  if frontal_length gt 1.5 then begin ; Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
                    vol = !values.f_nan
                  endif
                endwhile
              endif

              if finite(vol) eq 0 then begin ; Instability. Re-run, with smaller time-step
                while (finite(vol) eq 0) or (vol eq 'out') do begin
                  dtfactor = dtfactor * 0.5
                  print, dtfactor
                  if dtfactor lt 5e-2 then break
                  res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
                    frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method)
                  vol_obs = res[0]
                  vol = res[1]
                endwhile
                if dtfactor lt 5e-2 then begin
                  vol = !values.f_nan
                  break
                endif
              endif
            endwhile

            ; ; Next attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003)
            res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
              nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
              calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
            vol_obs = res[0]
            vol = res[1]

            if (finite(vol) eq 0) or (vol eq 'out') then begin ; in case a problem occurs in the transient run
              dtfactor = dtfactor / 2
              res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
                nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
                calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
              vol_obs = res[0]
              vol = res[1]
            endif

            if (finite(vol) ne 0) and (vol ne 'out') then begin ; ; If a 'real' volume is obtained for 'vol' (i.e. not 'out' or 'NaN') --> continue
              ; ; Write results from this volume calibration effort down in 'rmse_vol'
              rmse_vol[i - 1, 0] = aflow
              rmse_vol[i - 1, 1] = vol
              rmse_vol[i - 1, 2] = vol - vol_obs

              ; ; Plot this new attempt:
              oplot, [0, max(rmse_vol[0 : i - 1, 0])], [vol_obs, vol_obs] / 1e9, thick = 3, linestyle = 2
              oplot, rmse_vol[i - 1 : i - 1, 0], rmse_vol[i - 1 : i - 1, 1] / 1e9, psym = 8, symsize = 2, thick = 3
              PLOT, rmse_vol[0 : i - 1, 0], rmse_vol[0 : i - 1, 1] / 1e9, psym = 8, symsize = 2, xstyle = 1, ystyle = 1, thick = 3, $
                xrange = [0, max(rmse_vol[0 : i - 1, 0])], /nodata, /noerase

              ; ; Check whether it was a succesful attempt:
              if abs((vol - vol_obs) / vol_obs) lt vol_precision then begin ; If the guess is within X% of the observed volume (X=vol_precision*100)
                message = 'Within less than ' + string(vol_precision, format = '(F5.3)') + '% of observed volume. Number of iterations: ' + string(i, format = '(I1)') + ', aflow = ' + string(aflow, format = '(E10.3)')
                print, message
                break
              endif

              ; ; Estimate new value for deformation-sliding factor (a) based on previous attempts:
              if poly_fit_flag eq 0 then begin ; Linear fit (polyfit of order n=1)
                a = where(rmse_vol[0 : i - 1, 1] lt vol_obs, count_a)
                b = where(rmse_vol[0 : i - 1, 1] gt vol_obs, count_b)

                if (count_a gt 0) and (count_b gt 0) then begin ; if there's an underestimation for the volume and an overestimation: use the closest under/overestimations for the polyfit
                  rmse_vol_under = rmse_vol[0 : i - 1, *]
                  rmse_vol_under = rmse_vol_under[where(rmse_vol[0 : i - 1, 1] lt vol_obs), *]
                  dummy = abs(rmse_vol_under[*, 2])
                  i1 = sort(dummy)

                  rmse_vol_over = rmse_vol[0 : i - 1, *]
                  rmse_vol_over = rmse_vol_over[where(rmse_vol[0 : i - 1, 1] gt vol_obs), *]
                  dummy = abs(rmse_vol_over[*, 2])
                  i2 = sort(dummy)

                  p = poly_fit([rmse_vol_under[i1[0], 0], rmse_vol_over[i2[0], 0]], [rmse_vol_under[i1[0], 1], rmse_vol_over[i2[0], 1]], 1)
                endif else begin ; Fit based on two previous guesses
                  p = poly_fit(rmse_vol[i - 3 : i - 2, 0], rmse_vol[i - 3 : i - 2, 1], 1)
                endelse

                p_volobs = p
                p_volobs[n_elements(p_volobs) - 1] = p_volobs[n_elements(p_volobs) - 1] - vol_obs
                r = fz_roots(p_volobs) ; Replace with appropriate root-finding function for IDL
                aflow = r[0]
                print, 'aflow = ', aflow
              endif else if poly_fit_flag eq 1 then begin ; Polynomial fit
                ; Best fit based on all runs
                valid_data = where(finite(rmse_vol[0 : i - 1, 0]) and finite(rmse_vol[0 : i - 1, 1]), count_valid)
                if count_valid ge i - 1 then begin
                  p = poly_fit(rmse_vol[0 : i - 1, 0], rmse_vol[0 : i - 1, 1], i - 2) ; IDL's POLY_FIT degree is one less than MATLAB's
                  p_volobs = p
                  p_volobs[n_elements(p_volobs) - 1] = p_volobs[n_elements(p_volobs) - 1] - vol_obs
                  r = fz_roots(p_volobs) ; Replace with appropriate root-finding function for IDL

                  ; take aflow as the one closest to previous guess for aflow (as in some cases several values are possible)
                  r_minvol = r - aflow
                  dummy = min(abs(r_minvol), index)
                  aflow = r[index]
                  print, 'aflow = ', aflow

                  ; in case the polynomial fit did not work (e.g. when based on first and second guess, which were equal) --> opt for a linear fit
                  if ~finite(aflow) then begin
                    a = where(rmse_vol[0 : i - 1, 1] lt vol_obs, count_a)
                    b = where(rmse_vol[0 : i - 1, 1] gt vol_obs, count_b)

                    if (count_a gt 0) and (count_b gt 0) then begin ; if there's an underestimation for the volume and an overestimation: use the closest under/overestimations for the polyfit
                      rmse_vol_under = rmse_vol[0 : i - 1, *]
                      rmse_vol_under = rmse_vol_under[where(rmse_vol[0 : i - 1, 1] lt vol_obs), *]
                      dummy = abs(rmse_vol_under[*, 2])
                      i1 = sort(dummy)

                      rmse_vol_over = rmse_vol[0 : i - 1, *]
                      rmse_vol_over = rmse_vol_over[where(rmse_vol[0 : i - 1, 1] gt vol_obs), *]
                      dummy = abs(rmse_vol_over[*, 2])
                      i2 = sort(dummy)

                      p = poly_fit([rmse_vol_under[i1[0], 0], rmse_vol_over[i2[0], 0]], [rmse_vol_under[i1[0], 1], rmse_vol_over[i2[0], 1]], 1)
                    endif else begin ; Fit based on two previous guesses
                      p = poly_fit(rmse_vol[i - 3 : i - 2, 0], rmse_vol[i - 3 : i - 2, 1], 1)
                    endelse

                    p_volobs = p
                    p_volobs[n_elements(p_volobs) - 1] = p_volobs[n_elements(p_volobs) - 1] - vol_obs
                    r = fz_roots(p_volobs) ; Replace with appropriate root-finding function for IDL
                    aflow = r[0]
                    print, 'aflow = ', aflow
                  endif
                endif
              endif

              if aflow lt 0 then aflow = 0.5 * min(rmse_vol[0 : i - 1, 0])
            endif else begin
              break
            endelse
          endfor

          if abs((vol - vol_obs) / vol_obs) gt vol_precision then begin ; Did not succeed to get within X% of observed volume after 6 attempts --> take one that is closest
            valid_data = where(finite(rmse_vol[*, 2]), count_valid)
            if count_valid gt 0 then begin
              dummy = min(abs(rmse_vol[0 : i - 1, 2]), index)
              print, 'Minimum error value = ', dummy
              aflow = rmse_vol[index, 0]
              print, 'aflow = ', aflow

              ; re-run for the attempt that was the closest (as this may not have been the last one, and results need to be written down again)
              res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = ela_change, mb_type_flag = 5, flag_startobs = 0, $
                frontal_length = frontal_length, dtfactor = dtfactor, calibration_method = calibration_method) ; 1950/1990 steady state
              vol_obs = res[0]
              vol = res[1]

              res = glacier(glacier_id, region, chain, aflow = aflow, mb_bias_flag = 0, mb_type_flag = 6, flag_startobs = 2, $
                nyears = nyears, start_year = start_year, frontal_length = frontal_length, dtfactor = dtfactor, $
                calibration_method = calibration_method) ; Transient: 1950/1990 --> inventory date
              vol_obs = res[0]
              vol = res[1]
            endif
          endif
        endif
      endelse
    endif else begin
      print, 'Volume was within X% at first attempt! Succesful volume calibration'
    endelse
  endelse

  wdelete, 0 ; Close the 'aflow vs. volume' figure (i.e. the 'volume calibration' figure and not the 'length calibration' figure)

  RETURN, vol
end
