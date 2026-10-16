; *************************************************************
; write_snowline_results
;
; Calibration file lines with calibrate_snowline = 'y'. A glacier run
; in this pass is written as usual and its run is kept; a glacier that
; is done is written again from its last run, so that every phase file
; lists all scanned glaciers. Glaciers not calibrated here are left out.
; *************************************************************

compile_opt idl2

snowcal_g = gg[g]
if snowcal_ran then begin
  snowcal_st_ann[snowcal_g, 0, *] = mb & snowcal_st_ann[snowcal_g, 1, *] = wb
  snowcal_st_ann[snowcal_g, 2, *] = ela & snowcal_st_ann[snowcal_g, 3, *] = aar
  snowcal_st_ann[snowcal_g, 4, *] = dbdz & snowcal_st_ann[snowcal_g, 5, *] = btongue
  snowcal_st_par[snowcal_g, *] = [area1, DDFsnow, DDFice, c_prec, t_offset, flag, ccj[0]]
endif else if snowcal_flag[snowcal_g] eq 2 then begin
  mb = reform(snowcal_st_ann[snowcal_g, 0, *]) & wb = reform(snowcal_st_ann[snowcal_g, 1, *])
  ela = reform(snowcal_st_ann[snowcal_g, 2, *]) & aar = reform(snowcal_st_ann[snowcal_g, 3, *])
  dbdz = reform(snowcal_st_ann[snowcal_g, 4, *]) & btongue = reform(snowcal_st_ann[snowcal_g, 5, *])
  area1 = snowcal_st_par[snowcal_g, 0]
  DDFsnow = snowcal_st_par[snowcal_g, 1] & DDFice = snowcal_st_par[snowcal_g, 2]
  c_prec = snowcal_st_par[snowcal_g, 3] & t_offset = snowcal_st_par[snowcal_g, 4]
  flag = fix(snowcal_st_par[snowcal_g, 5]) & ccj = long(snowcal_st_par[snowcal_g, 6])
  n = indgen(years) + tran[0] & pp = where(n gt calimb_p0[ccj[0]] and n le calimb_p1[ccj[0]])
  flux_calv = dblarr(years) & ar_gl = 0.d
endif
if snowcal_flag[snowcal_g] ge 0 then begin
  @procedures/calibration/write_calibration_results.pro
endif
