; *************************************************************
; write_netcdf_hindcast
;
; Finalise GlacierMIP4-compliant NetCDF output for a hindcast run.
; Called once per region after the glacier loop has completed.
; Writes regional aggregate arrays to the regional files and
; closes all open NetCDF file handles.
;
; Follows @init_netcdf_hindcast.pro (which creates files and
; initialises accumulators) and @write_netcdf_glacier.pro (which
; fills per-glacier slices and accumulates regional sums).
;
; Variables consumed from scope (set by init and write_glacier):
;   nc_ann, nc_sub, nc_ann_i, nc_sub_i    - file handles
;   nc_vid_*                              - variable IDs
;   nc_reg_area, nc_reg_mass, nc_reg_mbsl, nc_reg_fabl
;   nc_reg_acc, nc_reg_melt, nc_reg_refr
;   nc_reg_run, nc_reg_prec
;   nc_reg_temp_w, nc_reg_temp_a          - weighted temp numerator/denominator
;   nc_years, nc_n_sub                    - dimensions
; *************************************************************

compile_opt idl2

; Finalise area-weighted regional temperature
nc_reg_temp = fltarr(nc_n_sub)
ii = where(nc_reg_temp_a gt 0, ci)
if ci gt 0 then nc_reg_temp[ii] = float(nc_reg_temp_w[ii] / nc_reg_temp_a[ii])
jj = where(nc_reg_temp_a le 0, cj)
if cj gt 0 then nc_reg_temp[jj] = nc_fv

; Write regional annual data
ncdf_varput, nc_ann, nc_vid_area, nc_reg_area
ncdf_varput, nc_ann, nc_vid_mass, nc_reg_mass
ncdf_varput, nc_ann, nc_vid_mbsl, nc_reg_mbsl
ncdf_varput, nc_ann, nc_vid_fabl, nc_reg_fabl

; Write regional sub-annual data
ncdf_varput, nc_sub, nc_vid_acc,  nc_reg_acc
ncdf_varput, nc_sub, nc_vid_melt, nc_reg_melt
ncdf_varput, nc_sub, nc_vid_refr, nc_reg_refr
ncdf_varput, nc_sub, nc_vid_run,  nc_reg_run
ncdf_varput, nc_sub, nc_vid_prec, nc_reg_prec
ncdf_varput, nc_sub, nc_vid_temp, nc_reg_temp

; Flush the buffered individual-glacier arrays -- see the matching block
; in write_netcdf_projections.pro / init_netcdf_hindcast.pro (2026-08-31).
ncdf_varput, nc_ann_i, nc_vid_i_rgid,  nc_buf_rgiid
ncdf_varput, nc_ann_i, nc_vid_i_area,  nc_buf_area
ncdf_varput, nc_ann_i, nc_vid_i_mass,  nc_buf_mass
ncdf_varput, nc_ann_i, nc_vid_i_mbsl,  nc_buf_mbsl
ncdf_varput, nc_ann_i, nc_vid_i_fabl,  nc_buf_fabl
ncdf_varput, nc_ann_i, nc_vid_i_ela,   nc_buf_ela
ncdf_varput, nc_ann_i, nc_vid_i_aar,   nc_buf_aar

ncdf_varput, nc_sub_i, nc_vid_i_rgid_s, nc_buf_rgiid
ncdf_varput, nc_sub_i, nc_vid_i_run,    nc_buf_run
ncdf_varput, nc_sub_i, nc_vid_i_rbas,   nc_buf_rbas
ncdf_varput, nc_sub_i, nc_vid_i_acc,    nc_buf_acc
ncdf_varput, nc_sub_i, nc_vid_i_melt,   nc_buf_melt
ncdf_varput, nc_sub_i, nc_vid_i_refr,   nc_buf_refr
ncdf_varput, nc_sub_i, nc_vid_i_prec,   nc_buf_prec
ncdf_varput, nc_sub_i, nc_vid_i_temp,   nc_buf_temp
ncdf_varput, nc_sub_i, nc_vid_i_snln,   nc_buf_snln

; Close all files
ncdf_close, nc_ann
ncdf_close, nc_sub
ncdf_close, nc_ann_i
ncdf_close, nc_sub_i
