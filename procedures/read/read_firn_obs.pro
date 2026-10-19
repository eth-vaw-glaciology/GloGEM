; *************************************************************
; read_firn_obs
;
; Observed band balances for the perfect-firn test (firnice_firn_obs_dir; diagnostic only):
; firnobs_<id>.dat holds one header line and rows of year, band elevation [m] and observed band
; balance [m w.e.]; year 0 is the start balance of the ledger. Sets fo_b[years, nb] (NaN where a
; band and year has no observation) and fo_b0[nb] (NaN where none).
; *************************************************************

fo_b = dblarr(years, nb) + !values.d_nan
fo_b0 = dblarr(nb) + !values.d_nan
fo_fn = firnice_firn_obs_dir + '/firnobs_' + id[gg[g]] + '.dat'
fo_n = file_test(fo_fn) ? file_lines(fo_fn) - 1l : 0l
if fo_n gt 0 then begin
   fo_d = dblarr(3, fo_n) & fo_h = ''
   openr, fo_u, fo_fn, /get_lun & readf, fo_u, fo_h & readf, fo_u, fo_d & free_lun, fo_u
   for fo_k = 0l, fo_n-1 do begin
      fo_dz = min(abs(elev - fo_d[1,fo_k]), fo_i)
      if fo_dz ge 1d or gl[fo_i] eq noval then continue
      if fo_d[0,fo_k] eq 0 then fo_b0[fo_i] = fo_d[2,fo_k] else begin
         fo_ye = long(fo_d[0,fo_k]) - long(tran[0])
         if fo_ye ge 0 and fo_ye lt years then fo_b[fo_ye,fo_i] = fo_d[2,fo_k]
      endelse
   endfor
   print, '  [perfect-firn test] ' + strtrim(long(total(finite(fo_b0))),2) + ' bands with observed balances (' + fo_fn + ')'
endif
