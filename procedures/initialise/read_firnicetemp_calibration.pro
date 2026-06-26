; *************************************************************
; read_firnicetemp_calibration
;
; Reads the per-glacier firn temperature calibration file
; (firnice_temp_calib_file) into outer-scope arrays.
;
; Called once at startup (inside `if firnice_temperature eq 'y'`)
; when firnice_temp_calib_file ne ''.
;
; Calibration file format (space-separated, one line per glacier):
;   # glacier_id  perm_frac  dT_scale
;   00773  0.40  1.30
;   00774  0.25  1.60
;   ...
; Lines starting with '#' are treated as comments and skipped.
;
; Sets outer-scope arrays (used by apply_firnicetemp_calibration.pro):
;   firnicecali_id        — string array of glacier IDs
;   firnicecali_perm_frac — double array of perm_frac values
;   firnicecali_dT_scale  — double array of dT_scale values
; *************************************************************

compile_opt idl2

firnicecali_id        = ['']
firnicecali_perm_frac = [0.d]
firnicecali_dT_scale  = [0.d]
n_cali = 0l

if ~file_test(firnice_temp_calib_file) then begin
    print, '  [firnicetemp calib] WARNING: calibration file not found: ' + firnice_temp_calib_file
    goto, read_firnicecalib_done
endif

anz = file_lines(firnice_temp_calib_file)
openr, 55, firnice_temp_calib_file
line = ''
for k = 0l, anz-1l do begin
    readf, 55, line
    line = strtrim(line, 2)
    if strmid(line, 0, 1) eq '#' or line eq '' then continue
    parts = strsplit(line, /extract)
    if n_elements(parts) lt 3 then continue
    if n_cali eq 0 then begin
        firnicecali_id        = [parts[0]]
        firnicecali_perm_frac = [double(parts[1])]
        firnicecali_dT_scale  = [double(parts[2])]
    endif else begin
        firnicecali_id        = [firnicecali_id,        parts[0]]
        firnicecali_perm_frac = [firnicecali_perm_frac, double(parts[1])]
        firnicecali_dT_scale  = [firnicecali_dT_scale,  double(parts[2])]
    endelse
    n_cali++
endfor
close, 55

print, '  [firnicetemp calib] loaded ' + strtrim(n_cali, 2) + ' glacier entries from ' + firnice_temp_calib_file

read_firnicecalib_done:
