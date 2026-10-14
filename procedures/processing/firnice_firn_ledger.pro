; *************************************************************
; firnice_firn_ledger
;
; firnice_perm_limit 'firn': the annual firn layers of each band [m w.e.], newest first, kept by
; the band's mass balance at the end of each hydrological year, with the rules of the firn model
; of Beer et al. (2026): a positive balance adds a layer stamped with the year; a negative balance
; removes its amount from the newest layers first; layers older than firnice_firn_age years
; become ice. Read in firnice_temperature_model.pro as the depth meltwater can reach.
; Included from finalize_annual_massbalance.pro (bal = this year's band balance).
; *************************************************************

fl_year = long(tran[0]) + ye
for fl_i = 0l, nb-1 do begin
   if gl[fl_i] eq noval then begin
      fl_we[fl_i,*] = 0d & fl_yr[fl_i,*] = 0l
      continue
   endif
   fl_b = bal[fl_i]
   if fl_b gt 0d then begin
      fl_we[fl_i,1:n_fl-1] = fl_we[fl_i,0:n_fl-2] & fl_yr[fl_i,1:n_fl-1] = fl_yr[fl_i,0:n_fl-2]
      fl_we[fl_i,0] = fl_b & fl_yr[fl_i,0] = fl_year
   endif else begin
      fl_rem = -fl_b
      for fl_k = 0l, n_fl-1 do begin
         if fl_rem le 0d then break
         fl_take = fl_rem < fl_we[fl_i,fl_k]
         fl_we[fl_i,fl_k] = fl_we[fl_i,fl_k] - fl_take & fl_rem = fl_rem - fl_take
      endfor
   endelse
   ; ageing, then close the gaps (newest first)
   fl_keep = where(reform(fl_we[fl_i,*]) gt 0d and reform(fl_yr[fl_i,*]) ge fl_year - long(firnice_firn_age), fl_nk)
   fl_w = dblarr(n_fl) & fl_y = lonarr(n_fl)
   if fl_nk gt 0 then begin
      fl_w[0:fl_nk-1] = reform(fl_we[fl_i,fl_keep]) & fl_y[0:fl_nk-1] = reform(fl_yr[fl_i,fl_keep])
   endif
   fl_we[fl_i,*] = fl_w & fl_yr[fl_i,*] = fl_y
   if firnice_write[0] eq 'y' then begin
      fll_we[ye,fl_i] = total(fl_w)
      fll_z[ye,fl_i]  = interpol(fl_znode, fl_cumwe, total(fl_w) < max(fl_cumwe))
      fll_n[ye,fl_i]  = fl_nk
      if fl_nk gt 0 then fll_old[ye,fl_i] = min(fl_y[0:fl_nk-1])
   endif
endfor
