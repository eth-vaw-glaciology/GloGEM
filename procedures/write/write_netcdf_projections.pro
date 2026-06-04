; *************************************************************
; write_netcdf_projections
;
; Finalise GlacierMIP4-compliant NetCDF output for a projection
; run. Called once per region/GCM/SSP combination after the
; glacier loop has completed. Writes regional aggregate arrays
; to all open NetCDF files and closes all handles, including
; split past and future files when nc_has_split eq 1.
;
; Follows @init_netcdf_projections.pro and @write_netcdf_glacier.
;
; Variables consumed from scope:
;   Full period: nc_ann, nc_sub, nc_ann_i, nc_sub_i
;   Split past:  nc_sp_ann, nc_sp_sub, nc_sp_ann_i, nc_sp_sub_i
;   Split future: nc_sf_ann, nc_sf_sub, nc_sf_ann_i, nc_sf_sub_i
;   nc_vid_*, nc_vid_sp_*, nc_vid_sf_*
;   nc_reg_*, nc_reg_sp_*, nc_reg_sf_*
;   nc_has_split, nc_years, nc_n_sub
;   nc_years_past, nc_n_sub_past, nc_years_fut, nc_n_sub_fut
; *************************************************************

compile_opt idl2

; Finalise area-weighted regional temperature (full period)
nc_reg_temp = fltarr(nc_n_sub)
ii = where(nc_reg_temp_a gt 0, ci)
if ci gt 0 then nc_reg_temp[ii] = float(nc_reg_temp_w[ii] / nc_reg_temp_a[ii])
jj = where(nc_reg_temp_a le 0, cj)
if cj gt 0 then nc_reg_temp[jj] = nc_fv

; Write full-period regional data
ncdf_varput, nc_ann, nc_vid_area, nc_reg_area
ncdf_varput, nc_ann, nc_vid_mass, nc_reg_mass
ncdf_varput, nc_ann, nc_vid_mbsl, nc_reg_mbsl
ncdf_varput, nc_ann, nc_vid_fabl, nc_reg_fabl
ncdf_varput, nc_sub, nc_vid_acc,  nc_reg_acc
ncdf_varput, nc_sub, nc_vid_melt, nc_reg_melt
ncdf_varput, nc_sub, nc_vid_refr, nc_reg_refr
ncdf_varput, nc_sub, nc_vid_run,  nc_reg_run
ncdf_varput, nc_sub, nc_vid_prec, nc_reg_prec
ncdf_varput, nc_sub, nc_vid_temp, nc_reg_temp

; Close full-period files
ncdf_close, nc_ann
ncdf_close, nc_sub
ncdf_close, nc_ann_i
ncdf_close, nc_sub_i

if ~nc_has_split then goto, write_proj_done

; --- split past ---
nc_reg_sp_temp = fltarr(nc_n_sub_past)
ii = where(nc_reg_sp_temp_a gt 0, ci)
if ci gt 0 then nc_reg_sp_temp[ii] = float(nc_reg_sp_temp_w[ii] / nc_reg_sp_temp_a[ii])
jj = where(nc_reg_sp_temp_a le 0, cj)
if cj gt 0 then nc_reg_sp_temp[jj] = nc_fv

ncdf_varput, nc_sp_ann, nc_vid_sp_area, nc_reg_sp_area
ncdf_varput, nc_sp_ann, nc_vid_sp_mass, nc_reg_sp_mass
ncdf_varput, nc_sp_ann, nc_vid_sp_mbsl, nc_reg_sp_mbsl
ncdf_varput, nc_sp_ann, nc_vid_sp_fabl, nc_reg_sp_fabl
ncdf_varput, nc_sp_sub, nc_vid_sp_acc,  nc_reg_sp_acc
ncdf_varput, nc_sp_sub, nc_vid_sp_melt, nc_reg_sp_melt
ncdf_varput, nc_sp_sub, nc_vid_sp_refr, nc_reg_sp_refr
ncdf_varput, nc_sp_sub, nc_vid_sp_run,  nc_reg_sp_run
ncdf_varput, nc_sp_sub, nc_vid_sp_prec, nc_reg_sp_prec
ncdf_varput, nc_sp_sub, nc_vid_sp_temp, nc_reg_sp_temp
ncdf_close, nc_sp_ann
ncdf_close, nc_sp_sub
ncdf_close, nc_sp_ann_i
ncdf_close, nc_sp_sub_i

; --- split future ---
nc_reg_sf_temp = fltarr(nc_n_sub_fut)
ii = where(nc_reg_sf_temp_a gt 0, ci)
if ci gt 0 then nc_reg_sf_temp[ii] = float(nc_reg_sf_temp_w[ii] / nc_reg_sf_temp_a[ii])
jj = where(nc_reg_sf_temp_a le 0, cj)
if cj gt 0 then nc_reg_sf_temp[jj] = nc_fv

ncdf_varput, nc_sf_ann, nc_vid_sf_area, nc_reg_sf_area
ncdf_varput, nc_sf_ann, nc_vid_sf_mass, nc_reg_sf_mass
ncdf_varput, nc_sf_ann, nc_vid_sf_mbsl, nc_reg_sf_mbsl
ncdf_varput, nc_sf_ann, nc_vid_sf_fabl, nc_reg_sf_fabl
ncdf_varput, nc_sf_sub, nc_vid_sf_acc,  nc_reg_sf_acc
ncdf_varput, nc_sf_sub, nc_vid_sf_melt, nc_reg_sf_melt
ncdf_varput, nc_sf_sub, nc_vid_sf_refr, nc_reg_sf_refr
ncdf_varput, nc_sf_sub, nc_vid_sf_run,  nc_reg_sf_run
ncdf_varput, nc_sf_sub, nc_vid_sf_prec, nc_reg_sf_prec
ncdf_varput, nc_sf_sub, nc_vid_sf_temp, nc_reg_sf_temp
ncdf_close, nc_sf_ann
ncdf_close, nc_sf_sub
ncdf_close, nc_sf_ann_i
ncdf_close, nc_sf_sub_i

write_proj_done:
