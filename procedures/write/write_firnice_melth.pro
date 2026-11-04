; *************************************************************
; write_firnice_melth
;
; firnice_write_melth = 'y': the thermal model's degree-day melt before the orientation factor
; (firnice_melth_<id>.dat, m w.e. per month) and its air temperature (firnice_tairth_<id>.dat, C),
; per year (GloGEM's year label, as in temp_ID files), month and band (header: band elevations elev0).
; Months the main run did not reach hold noval.
; *************************************************************

compile_opt idl2

for wm_k = 0, 1 do begin
    wm_name = (wm_k eq 0) ? 'melth' : 'tairth'
    wm_val = (wm_k eq 0) ? melth_log : tairth_log
    get_lun, wm_lun
    openw, wm_lun, firnice_dir + '/firnice_' + wm_name + '_' + id[gg[g]] + '.dat', width = 20000
    printf, wm_lun, '# ' + ((wm_k eq 0) ? 'thermal degree-day melt before the orientation factor [m w.e. per month]' : $
        'thermal air temperature [C]') + ', glacier ' + id[gg[g]] + '; columns: year month, then one per band'
    printf, wm_lun, 'year month ' + strjoin(strtrim(string(round(reform(elev0))), 2), ' ')
    for wm_y = 0l, years - 1l do for wm_m = 1, 12 do $
        printf, wm_lun, wm_y + tran[0], wm_m, reform(wm_val[wm_y, wm_m - 1, *]), $
            format = '(2i6,' + strtrim(nb, 2) + '(e14.6))'
    free_lun, wm_lun
endfor
