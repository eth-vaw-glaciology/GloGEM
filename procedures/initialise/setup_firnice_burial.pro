; *************************************************************
; setup_firnice_burial
;
; Perfect-burial diagnostic (firnice_burial_dir ne ''): the measured long-term net accumulation
; replaces the thermal model's reference balance b_ref at listed bands, so burial (vertical
; advection), the thermal firn mask and the Herron-Langway firn depth all take it. The mass
; balance is untouched.
; Reads firnice_burial_dir/burial_<glacier id>.dat: lines starting with '#' are comments; data
; lines: band elevation [m a.s.l.] and the accumulation [m w.e./yr], positive. Each line goes to
; the glacierised band whose inventory elevation elev0 lies within 5 m. A glacier without a file
; keeps its own b_ref (printed).
; Called from firnice_reference_forcing.pro after b_ref is set.
; *************************************************************

compile_opt idl2

fn_bu = firnice_burial_dir + path_sep() + 'burial_' + id[gg[g]] + '.dat'
if file_test(fn_bu) then begin
    openr, lun_bu, fn_bu, /get_lun
    line_bu = '' & set_bu = bytarr(nb) & txt_bu = ''
    while not eof(lun_bu) do begin
        readf, lun_bu, line_bu
        line_bu = strtrim(line_bu, 2)
        if strlen(line_bu) eq 0 then continue
        if strmid(line_bu, 0, 1) eq '#' then continue
        parts_bu = double(strsplit(line_bu, /extract))
        if n_elements(parts_bu) ne 2 then message, 'firnice_burial: ' + fn_bu + ': expected 2 numbers, got: ' + line_bu
        dz_bu = min(abs(elev0 - parts_bu[0]), jb_bu)
        if dz_bu gt 5d then message, 'firnice_burial: ' + fn_bu + ': no band within 5 m of ' + strtrim(parts_bu[0], 2)
        if gl[jb_bu] eq noval then message, 'firnice_burial: ' + fn_bu + ': band ' + strtrim(round(elev0[jb_bu]), 2) + $
            ' is not glacierised'
        if set_bu[jb_bu] then message, 'firnice_burial: ' + fn_bu + ': band ' + strtrim(round(elev0[jb_bu]), 2) + ' given twice'
        if parts_bu[1] le 0d then message, 'firnice_burial: ' + fn_bu + ': accumulation must be positive: ' + line_bu
        txt_bu = txt_bu + ' ' + strtrim(round(elev0[jb_bu]), 2) + ': ' + strtrim(string(b_ref[jb_bu], fo='(f6.2)'), 2) + $
            ' -> ' + strtrim(string(parts_bu[1], fo='(f6.2)'), 2)
        b_ref[jb_bu] = parts_bu[1]
        set_bu[jb_bu] = 1b
    endwhile
    free_lun, lun_bu
    print, '  [burial] ' + id[gg[g]] + ' measured accumulation [m w.e./a] at' + txt_bu
endif else print, '  [burial] ' + id[gg[g]] + ': no file, model b_ref'
