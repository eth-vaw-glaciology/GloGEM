; *************************************************************
; nc_hydro_month_time
;
; Time values (days since ref_jd) for monthly NetCDF output, which is stored
; in model order: index 0 is month bal_month of the year before first_year,
; the first month of hydrological year first_year.
; *************************************************************

function nc_hydro_month_time, n_months, first_year, bal_month, ref_jd
  compile_opt idl2
  t = lonarr(n_months)
  for k = 0L, n_months - 1L do begin
    mm = long(bal_month) - 1L + k
    t[k] = long(julday(mm mod 12 + 1, 1, first_year - 1L + mm / 12) - ref_jd)
  endfor
  return, t
end
