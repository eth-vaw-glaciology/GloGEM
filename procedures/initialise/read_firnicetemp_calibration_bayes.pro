; *************************************************************
; read_firnicetemp_calibration_bayes
;
; Reads the per-glacier Kennedy-O'Hagan (KO) Bayesian residual-correction
; file (firnice_temp_calib_bayes_file) into outer-scope arrays.
;
; Called once at startup (inside `if firnice_temperature eq 'y'`)
; when firnice_temp_calib_bayes_file ne ''.
;
; Same additive-residual mechanism as read_firnicetemp_calibration_knn.pro
; (delta_rf/delta_is/delta_av ADDED to the flat per-band settings.pro defaults,
; not overwriting them — see apply_firnicetemp_calibration_bayes.pro), but the
; residuals here come from a proper Bayesian calibration (Python
; icetemp.calibration.writeback.ResidualWriter): a Kennedy-O'Hagan model
; y = G(x;theta) + delta(x) + epsilon, with theta's posterior sampled by
; emcee against a surmise PCGPwM emulator of the real transient GloGEM
; model, and delta(x) a zero-mean spatial GP (replacing the k-NN file's
; undamped nearest-neighbour copy — the diagnosed cause of that scheme's
; negative real-world R²). Two extra columns carry the posterior standard
; deviation of each residual, written for diagnostic/QA use (not consumed by
; apply_firnicetemp_calibration_bayes.pro, which only uses the means).
;
; Calibration file format (space-separated, one line per glacier):
;   # glacier_id  delta_rf  delta_is  delta_av  std_rf  std_is  std_av
;   00773  -0.2748  -0.1763  -0.0135  0.0561  0.4895  0.0000
;   00774  -0.2975  -0.1335  -0.0135  0.0541  0.4907  0.0000
;   ...
; Lines starting with '#' are treated as comments and skipped. The three
; std_* columns are optional for backward compatibility with a 4-column
; (id + 3 deltas) file; missing std values are set to 0.
;
; Sets outer-scope arrays (used by apply_firnicetemp_calibration_bayes.pro):
;   firnicecalibayes_id       — string array of glacier IDs
;   firnicecalibayes_rf_delta — double array of refreeze_frac residuals
;   firnicecalibayes_is_delta — double array of insul_scale residuals
;   firnicecalibayes_av_delta — double array of adv_scale residuals
;   firnicecalibayes_pf_std   — double array of refreeze_frac residual std (diagnostic)
;   firnicecalibayes_ds_std   — double array of insul_scale residual std (diagnostic)
;   firnicecalibayes_z0_std   — double array of adv_scale residual std (diagnostic)
; *************************************************************

compile_opt idl2

firnicecalibayes_id       = ['']
firnicecalibayes_rf_delta = [0.d]
firnicecalibayes_is_delta = [0.d]
firnicecalibayes_av_delta = [0.d]
firnicecalibayes_pf_std   = [0.d]
firnicecalibayes_ds_std   = [0.d]
firnicecalibayes_z0_std   = [0.d]
n_calibayes = 0l

if ~file_test(firnice_temp_calib_bayes_file) then begin
    print, '  [firnicetemp calib-bayes] WARNING: calibration file not found: ' + firnice_temp_calib_bayes_file
    goto, read_firnicecalibayes_done
endif

if firnice_temp_calib ne 'y' then begin
    print, '  [firnicetemp calib-bayes] WARNING: firnice_temp_calib_bayes_file is set but ' + $
        'firnice_temp_calib is not "y" — there is no per-band baseline to correct.'
endif

anz = file_lines(firnice_temp_calib_bayes_file)
openr, 56, firnice_temp_calib_bayes_file
line = ''
for k = 0l, anz-1l do begin
    readf, 56, line
    line = strtrim(line, 2)
    if strmid(line, 0, 1) eq '#' or line eq '' then continue
    parts = strsplit(line, /extract)
    if n_elements(parts) lt 4 then continue
    has_std = n_elements(parts) ge 7
    if n_calibayes eq 0 then begin
        firnicecalibayes_id       = [parts[0]]
        firnicecalibayes_rf_delta = [double(parts[1])]
        firnicecalibayes_is_delta = [double(parts[2])]
        firnicecalibayes_av_delta = [double(parts[3])]
        firnicecalibayes_pf_std   = [has_std ? double(parts[4]) : 0.d]
        firnicecalibayes_ds_std   = [has_std ? double(parts[5]) : 0.d]
        firnicecalibayes_z0_std   = [has_std ? double(parts[6]) : 0.d]
    endif else begin
        firnicecalibayes_id       = [firnicecalibayes_id,       parts[0]]
        firnicecalibayes_rf_delta = [firnicecalibayes_rf_delta, double(parts[1])]
        firnicecalibayes_is_delta = [firnicecalibayes_is_delta, double(parts[2])]
        firnicecalibayes_av_delta = [firnicecalibayes_av_delta, double(parts[3])]
        firnicecalibayes_pf_std   = [firnicecalibayes_pf_std,   has_std ? double(parts[4]) : 0.d]
        firnicecalibayes_ds_std   = [firnicecalibayes_ds_std,   has_std ? double(parts[5]) : 0.d]
        firnicecalibayes_z0_std   = [firnicecalibayes_z0_std,   has_std ? double(parts[6]) : 0.d]
    endelse
    n_calibayes++
endfor
close, 56

print, '  [firnicetemp calib-bayes] loaded ' + strtrim(n_calibayes, 2) + ' glacier entries from ' + firnice_temp_calib_bayes_file

read_firnicecalibayes_done:
