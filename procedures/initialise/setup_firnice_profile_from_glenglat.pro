; -----------------------------------------------------------------------
; setup_firnice_profile_from_glenglat
;
; Called from glogem.pro just before @prepare_output_firnicetemp when
; firnice_glenglat_lookup is set to a non-empty path.
;
; Reads the per-glacier borehole elevation lookup file and overrides
; firnice_profile (and firnice_profile_ID) so that IDX profile output is
; written at the actual glenglat borehole elevations rather than the fixed
; fractional positions in settings.pro.
;
; Lookup file format (see GloGEM/test/data/glenglat_borehole_elevations_CentralEurope.dat):
;   Lines starting with '#' are comments.
;   Data lines: glacier_id  elev1  elev2  ...  (space-separated, elevations in m a.s.l.)
;
; If the current glacier is not found in the lookup, firnice_profile is
; left unchanged (fractional fall-back remains active).
;
; Modifies (glogem.pro scope): firnice_profile, firnice_profile_ID
; -----------------------------------------------------------------------
compile_opt idl2

openr, 77, firnice_glenglat_lookup
line = ''
found = 0b
while not eof(77) do begin
    readf, 77, line
    line = strtrim(line, 2)
    if strlen(line) eq 0 then continue
    if strmid(line, 0, 1) eq '#' then continue
    parts = strsplit(line, /extract)
    if parts[0] eq id[gg[g]] then begin
        n_elev = n_elements(parts) - 1l
        if n_elev ge 1l then begin
            firnice_profile    = double(parts[1:*])
            firnice_profile_ID = string(indgen(n_elev) + 1l, fo='(i0)')
            found = 1b
        endif
        break
    endif
endwhile
close, 77

if found then $
    print, '  glenglat IDX elevations: ' + strjoin(strtrim(string(fix(firnice_profile)), 2), ', ') + ' m' $
else $
    print, '  glenglat lookup: no entry for glacier ' + id[gg[g]] + ' — using default firnice_profile'
