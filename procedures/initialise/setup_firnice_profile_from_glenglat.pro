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
;   Data lines: glacier_id  elev1[:depth1]  elev2[:depth2]  ...  (space-separated, elevations
;   in m a.s.l.). The optional depth is the deepest observation in that band [m]; it is
;   returned in firnice_profile_maxdepth so the temperature model can run its column at least
;   that deep. A plain elevation with no depth gives -1 (no override).
;
; If the current glacier is not found in the lookup, firnice_profile is
; left unchanged (fractional fall-back remains active).
;
; Modifies (glogem.pro scope): firnice_profile, firnice_profile_ID, firnice_profile_maxdepth
; -----------------------------------------------------------------------
compile_opt idl2

; reset per glacier -- these are @-include globals and would otherwise persist from the last one
firnice_profile_maxdepth = [-1.d]

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
            ev_l = dblarr(n_elev)
            md_l = dblarr(n_elev) - 1.d
            for kk = 0l, n_elev-1l do begin
                tok = strsplit(parts[kk+1l], ':', /extract)
                ev_l[kk] = double(tok[0])
                if n_elements(tok) ge 2 then md_l[kk] = double(tok[1])
            endfor
            firnice_profile          = ev_l
            firnice_profile_maxdepth = md_l
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
