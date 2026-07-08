; *************************************************************
; read_firnicetemp_calibration_knn
;
; Reads the per-glacier k-NN residual-correction file
; (firnice_temp_calib_knn_file) into outer-scope arrays.
;
; Called once at startup (inside `if firnice_temperature eq 'y'`)
; when firnice_temp_calib_knn_file ne ''.
;
; Unlike firnice_temp_calib_file (which OVERWRITES all bands with one flat
; glacier-wide value), this file carries per-glacier ADDITIVE residuals —
; the difference between a glacier's directly calibrated (perm_frac, dT_scale,
; z0) and what the global transfer model predicts at that glacier's own mean
; climate. Ungauged glaciers are assigned the residual of their nearest
; glenglat calibration glacier (05_firnicetemp_calibration.ipynb, ce-knn cell).
; apply_firnicetemp_calibration_knn.pro ADDS these residuals to the per-band
; transfer-model baseline — regional adaptation (from the residual) composes
; with per-band variation (from the baseline), rather than replacing it.
;
; Calibration file format (space-separated, one line per glacier):
;   # glacier_id  delta_pf  delta_ds  delta_z0
;   00773  0.050  -0.30  12.0
;   00774 -0.120   0.85 -18.0
;   ...
; Lines starting with '#' are treated as comments and skipped.
;
; Sets outer-scope arrays (used by apply_firnicetemp_calibration_knn.pro):
;   firnicecaliknn_id       — string array of glacier IDs
;   firnicecaliknn_pf_delta — double array of perm_frac residuals
;   firnicecaliknn_ds_delta — double array of dT_scale residuals
;   firnicecaliknn_z0_delta — double array of z0 residuals [m]
; *************************************************************

compile_opt idl2

firnicecaliknn_id       = ['']
firnicecaliknn_pf_delta = [0.d]
firnicecaliknn_ds_delta = [0.d]
firnicecaliknn_z0_delta = [0.d]
n_caliknn = 0l

if ~file_test(firnice_temp_calib_knn_file) then begin
    print, '  [firnicetemp calib-knn] WARNING: calibration file not found: ' + firnice_temp_calib_knn_file
    goto, read_firnicecaliknn_done
endif

if firnice_temp_calib ne 'y' then begin
    print, '  [firnicetemp calib-knn] WARNING: firnice_temp_calib_knn_file is set but ' + $
        'firnice_temp_calib is not "y" — there is no per-band baseline to correct.'
endif

anz = file_lines(firnice_temp_calib_knn_file)
openr, 55, firnice_temp_calib_knn_file
line = ''
for k = 0l, anz-1l do begin
    readf, 55, line
    line = strtrim(line, 2)
    if strmid(line, 0, 1) eq '#' or line eq '' then continue
    parts = strsplit(line, /extract)
    if n_elements(parts) lt 4 then continue
    if n_caliknn eq 0 then begin
        firnicecaliknn_id       = [parts[0]]
        firnicecaliknn_pf_delta = [double(parts[1])]
        firnicecaliknn_ds_delta = [double(parts[2])]
        firnicecaliknn_z0_delta = [double(parts[3])]
    endif else begin
        firnicecaliknn_id       = [firnicecaliknn_id,       parts[0]]
        firnicecaliknn_pf_delta = [firnicecaliknn_pf_delta, double(parts[1])]
        firnicecaliknn_ds_delta = [firnicecaliknn_ds_delta, double(parts[2])]
        firnicecaliknn_z0_delta = [firnicecaliknn_z0_delta, double(parts[3])]
    endelse
    n_caliknn++
endfor
close, 55

print, '  [firnicetemp calib-knn] loaded ' + strtrim(n_caliknn, 2) + ' glacier entries from ' + firnice_temp_calib_knn_file

read_firnicecaliknn_done:
