; *************************************************************
; prepare_output_mb_in_bins
;
; *  Prepare output files for mass balance in elevation bins  *
; This procedure prepares the output files for mass balance in elevation bins.
; It creates the necessary directories and files, and writes the headers for the output data.
; The actual data will be written in a later step.
; *************************************************************


compile_opt idl2

; Route .dat output into _original subfolders
if single_glacier ne '' then begin
    subpath='/files/files_original/SINGLE/'
endif else if reanalysis_direct eq 'y' then begin
    subpath='/PAST/PAST_original/'
endif else begin
    subpath='/files/files_original/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]+'/'
endelse

if reanalysis_direct eq 'y' then b='/PAST'+mtt

if write_mb_elevationbands eq 'y' then begin

   c=file_search(dirres+'/'+time_resolution+'/'+dir_region+subpath+'/mb_elevation')
   if c[0] eq '' then begin
      mb_elevation_dir = dirres + '/' + time_resolution + '/' + dir_region + subpath + '/mb_elevation'
      file_mkdir, mb_elevation_dir
      file_chmod, mb_elevation_dir, /a_read, /a_execute
   endif

   openw,8,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/mb_elevation/belev_'+id[gg[g]]+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
   printf,8,'Elev  '+a
   elev_bmb=dblarr(years,nb)+snoval
   elev_bwb=elev_bmb 
   ; elevation-specified refreezing files 
   c=file_search(dirres+'/'+time_resolution+'/'+dir_region+subpath+'/refr_elevation')
   if c[0] eq '' then begin
      refr_elevation_dir = dirres+'/'+time_resolution+'/'+dir_region+subpath+'/refr_elevation'
      file_mkdir, refr_elevation_dir
      file_chmod, refr_elevation_dir, /a_read, /a_execute
   endif
   openw,40,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/refr_elevation/refrelev_'+id[gg[g]]+'.dat'
   a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
   printf,40,'Elev  '+a &  elev_refr=dblarr(years,nb)+snoval 

   if debris_supraglacial eq 'y' then begin
   ; elevation-specified debris files 
      c=file_search(dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation')
      if c[0] eq '' then begin
         debris_elevation_dir = dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation'
         file_mkdir, debris_elevation_dir
         file_chmod, debris_elevation_dir, /a_read, /a_execute
      endif
      openw,41,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation/debthick_'+id[gg[g]]+'.dat'
      a='' & for i=0,years-1 do a=a+string(i+tran[0],fo='(i4)')+'  '
      printf,41,'Elev  '+a &  elev_debthick=dblarr(years,nb)+snoval 

      openw,42,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation/debfrac_'+id[gg[g]]+'.dat'
      printf,42,'Elev  '+a &  elev_debfrac=dblarr(years,nb)+snoval 

      openw,43,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation/debfactor_'+id[gg[g]]+'.dat'
      printf,43,'Elev  '+a &  elev_debfactor=dblarr(years,nb)+snoval 

      openw,44,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation/pondarea_'+id[gg[g]]+'.dat'
      printf,44,'Elev  '+a &  elev_pondarea=dblarr(years,nb)+snoval 

      if eval_mbelevsensitivity eq 'y' then begin
         openw,44,dirres+'/'+time_resolution+'/'+dir_region+subpath+'/debris_elevation/mbsensitivity_'+id[gg[g]]+'.dat'
         printf,44,'Elev  '+a &  elev_mbsens=dblarr(years,nb)+snoval &  elev_mbsensall=dblarr(count_mbelevsens_v0+1,years,nb)+snoval 
      endif
   endif
