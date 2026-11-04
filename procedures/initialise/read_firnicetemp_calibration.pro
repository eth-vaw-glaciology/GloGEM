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
;   # glacier_id  refreeze_frac  insul_scale  advection_scale
;   00773  0.850  1.10  1.20
;   00774  0.400  0.75  0.85
;   ...
; Lines starting with '#' are treated as comments and skipped.
; A 3-column file (no advection_scale column) is accepted; the missing
; advection_scale is filled with firnice_adv_scale (default from settings.pro).
;
; The columns are POSITIONAL and have been reused twice (perm_frac/dT_scale/z0,
; then perm_frac/dT_scale/adv, now refreeze_frac/insul_scale/adv), so a stale
; file parses cleanly with the wrong meaning -- e.g. an old z0 of 200 m read as
; an advection multiplier of 200. The header check below refuses such files.
;
; Sets outer-scope arrays (used by apply_firnicetemp_calibration.pro):
;   firnicecali_id         — string array of glacier IDs
;   firnicecali_refreeze_frac  — double array of refreeze_frac values (slot 1)
;   firnicecali_insul_scale   — double array of insul_scale values (slot 2)
;   firnicecali_adv_scale  — double array of advection_scale values
; *************************************************************

compile_opt idl2

firnicecali_id         = ['']
firnicecali_refreeze_frac  = [0.d]
firnicecali_insul_scale   = [0.d]
firnicecali_adv_scale  = [0.d]
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
    ; refuse a pre-swap file: its columns mean something else (see header)
    if strmid(line, 0, 1) eq '#' then begin
        lc = strlowcase(line)
        if strpos(lc, 'perm_frac') ge 0 or strpos(lc, 'dt_scale') ge 0 then begin
            close, 55
            print, '  [firnicetemp calib] ERROR: ' + firnice_temp_calib_file + $
                   ' uses the old perm_frac/dT_scale columns.'
            print, '  [firnicetemp calib] Expected: # glacier_id  refreeze_frac  insul_scale  advection_scale'
            message, 'stale firn/ice temperature calibration file -- refusing to run'
        endif
    endif
    if strmid(line, 0, 1) eq '#' or line eq '' then continue
    parts = strsplit(line, /extract)
    if n_elements(parts) lt 3 then continue
    adv_val = (n_elements(parts) ge 4) ? double(parts[3]) : firnice_adv_scale
    if n_cali eq 0 then begin
        firnicecali_id         = [parts[0]]
        firnicecali_refreeze_frac  = [double(parts[1])]
        firnicecali_insul_scale   = [double(parts[2])]
        firnicecali_adv_scale  = [adv_val]
    endif else begin
        firnicecali_id         = [firnicecali_id,        parts[0]]
        firnicecali_refreeze_frac  = [firnicecali_refreeze_frac, double(parts[1])]
        firnicecali_insul_scale   = [firnicecali_insul_scale,  double(parts[2])]
        firnicecali_adv_scale  = [firnicecali_adv_scale, adv_val]
    endelse
    n_cali++
endfor
close, 55

print, '  [firnicetemp calib] loaded ' + strtrim(n_cali, 2) + ' glacier entries from ' + firnice_temp_calib_file

read_firnicecalib_done:
