; *************************************************************
; store_elevationband_massbalance
;
; Store elevation-band mass balance and refreezing at year-end.
;
; At the end of the mass balance year, stores the winter balance
; (bwb), annual balance (bmb), and refreezing (refr) per
; elevation band into their respective output arrays.
; *************************************************************

compile_opt idl2

if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then wb[ye]=total(bal*area)/ar_gl
if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then wb[ye]=total(bal*area)/ar_gl

; set bal-array to noval in case there is no glacier
ii=where(gl eq noval,ci) & if ci gt 0 then bal[ii]=snoval

if write_mb_elevationbands eq 'y' then begin
   if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then elev_bwb[ye,*]=bal
   if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then elev_bwb[ye,*]=bal
   if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_bmb[ye,*]=bal
   if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_bmb[ye,*]=bal
   if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_refr[ye,*]=refreeze*1000.
   if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_refr[ye,*]=refreeze*1000.
   ; band_extension_glacier: bands without ice get the balance an ice surface would have (virtual_ice_balance_glacier.pro)
   if band_extension_glacier eq 'y' and ci gt 0 then begin
      ; below the front the balance may not rise going down: a band where the blend into the
      ; regional parameters would make it rise takes the value of the band above
      bal_vm=bal_v
      if m eq dd_thresholds[0] or m eq dd_thresholds[2] or m eq dd_thresholds[0]-1 or m eq dd_thresholds[2]-1 then $
        for v_k=i_front_v-1,0,-1 do bal_vm[v_k]=bal_vm[v_k] < bal_vm[v_k+1]
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[0] then elev_bwb[ye,ii]=bal_vm[ii]
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[2] then elev_bwb[ye,ii]=bal_vm[ii]
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_bmb[ye,ii]=bal_vm[ii]
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_bmb[ye,ii]=bal_vm[ii]
   endif
   if eval_mbelevsensitivity eq 'y' then begin
      if bal_month eq dd_thresholds[2] then if m eq dd_thresholds[2]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]=bal
      if bal_month eq dd_thresholds[0] then if m eq dd_thresholds[0]-1 then elev_mbsensall[count_mbelevsens+1,ye,*]=bal
   endif
endif
