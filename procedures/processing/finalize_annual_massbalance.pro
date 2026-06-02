; *************************************************************
; Finalize annual mass balance and compute glacier statistics.
;
; Stores the annual balance, updates firn coverage based on a
; 5-year running mean, computes area/volume/ELA/AAR/dBdz
; statistics, stores decadal hypsometry snapshots, and saves
; glacier geometry for the advance scheme lookup table.
; *************************************************************

compile_opt idl2

; calculate balance - store results
if ar_gl ne 0 then mb[ye]=total(bal*area)/ar_gl
baly[ye,*]=bal
if nb gt elev_range_p/step and plot eq 'y' then begin
   ii=where(gl eq noval,ci) & if ci gt 0 then melt[ii]=noval
   accy[ye,*]=acc & mely[ye,*]=melt & refry[ye,*]=refreeze
endif
balv=bal*area*1000000.

snostor=sno

; update firn coverage: look 5 years back, firn where average mb > 0
if ye gt 4 then begin
   balm=dblarr(nb)
   for i=0,nb-1 do balm[i]=mean(baly[ye-4:ye,i])
   firn=dblarr(nb) & ii=where(balm gt 0 and gl ne noval,ci) & if ci gt 0 then firn[ii]=1
endif

; statistics (area and volume stored BEFORE surface updating)
area1=total(area) & areas[ye]=area1 & volume1=total(thick*area)/1000. & volumes[ye]=volume1
area_stor=area
bb=where(bed_elev lt 0 and bed_elev gt -800. and thick gt 0,cb)
if cb gt 0 then vol_bz[ye]=vol_bz[ye]-0.001*total(bed_elev[bb]*area[bb])

; ELA, AAR, mass balance gradient
jj=where(thick gt 0,cj)
if cj gt 0 then begin
   ht1=elev[jj[0]]
   ii=where(bal[jj] gt 0,ci) & if ci gt 0 then aar[ye]=total(area_stor[jj[ii]])*100./area1 else aar[ye]=0
   btongue[ye]=min(bal[jj],ind) & if ci gt 0 then ela[ye]=elev[jj[ii[0]]] else ela[ye]=max(elev)
   da=(elev[jj[ind]]-ela[ye]) & if abs(da) gt 20 then dbdz[ye]=btongue[ye]/da else dbdz[ye]=0.
endif else ht1=max(elev)
hmin_g[ye]=ht1

jj=where(gl eq noval,cj) & if cj gt 0 then sur[jj]=noval
if outf_names[n_elements(where(outf_names ne ''))-1] eq 'n' then if cj eq nb then ye=1000

; store decadal hypsometry snapshot
if write_hypsometry_files eq 'y' then begin
   if (ye+tran[0]) mod 10 eq 0 then begin
      hypso_file[0,chypso,*]=elev & hypso_file[1,chypso,*]=area & hypso_file[2,chypso,*]=area*thick
      hypso_file[3,chypso,*]=tgs_cum/(10*12.) & tgs_cum=dblarr(nb)
      chypso=chypso+1
   endif
endif

; store glacier geometry for advance scheme lookup table
if adv_lookup eq 'y' then begin
   adv_lookup_data[0,0,ye]=volume1
   adv_lookup_data[1,*,ye]=area
   adv_lookup_data[2,*,ye]=thick
endif
