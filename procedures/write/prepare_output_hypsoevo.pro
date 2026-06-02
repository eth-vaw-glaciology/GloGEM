; ********************************************
; Prepare output for hypsometry-evolution file
; ********************************************
; This procedure prepares the output files for hypsometry-evolution. It creates the necessary directories and files, 
; and writes the headers for the output data. The actual data will be written in a later step.

compile_opt idl2

b='/files'+mtt+'/'+GCM_model[gcms]+'/'+GCM_rcp[rcps]
if reanalysis_direct eq 'y' then b='/PAST'
c=findfile(dirres+dir_region+b+'/hypsometry')

if c[0] eq '' then spawn,'mkdir '+dirres+dir_region+b+'/hypsometry' & if b[0] eq '' then spawn,'chmod a+rx '+dirres+dir_region+b+'/hypsometry'
openw,9,dirres+dir_region+b+'/hypsometry/hypso_'+id[gg[g]]+'.dat'
openw,34,dirres+dir_region+b+'/hypsometry/volume_'+id[gg[g]]+'.dat'
openw,35,dirres+dir_region+b+'/hypsometry/temp_'+id[gg[g]]+'.dat'

ctt=0 & h=strarr(1)
for i=tran[0],tran[1] do begin
    if i mod 10 eq 0 then begin
        ctt=ctt+1 & h=h+string(i,fo='(i4)')+'        '
    endif
endfor
hypso_file=dblarr(4,ctt,nb)+snoval &  printf,9,h &  printf,34,h &  printf,35,h & chypso=0
