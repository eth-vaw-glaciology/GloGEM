; *************************************************************
; initialise_results_files
;
; initializing opening results files
; This procedure opens the results files for writing, and writes the header lines.
; *************************************************************

compile_opt idl2


if reanalysis_direct eq 'y' then a='PAST'+version_past else a=GCM_model[gcms]+'/'+GCM_rcp[rcps]
if single_glacier ne '' then a='SINGLE'

if meltmodel eq '3' then plf='_m3' else plf='' 
if meltmodel eq '1' and calperiod_ID eq 8 then  plf='_debris' else plf='' 
subpath='/files'+plf+'/'+a+'/'

if meltmodel eq '1' then mtt='' else mtt='_m3'
if meltmodel eq '1' and calperiod_ID eq 8 then  mtt='_debris' else mtt=''  

if past_out eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/'
if past_out eq 'y' and hindcast_dynamic eq 'y' and reanalysis_direct eq 'y' then subpath='/PAST'+version_past+mtt+'/dyn/'

if catchment_selection ne '' then cc='_'+catchment_selection else cc=''

openw,6,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+sub_region+cc+'.dat'
printf,6,'ID    lat  lon    Area0    Volume0  dA(%)  dV(%)'

y=indgen(years)+tran[0]
for fid=10,10+n_elements(where(outf_names ne ''))-1 do begin
    openw,string(fid,fo='(i2)'),dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+sub_region+'_'+outf_names[fid-10]+'_'+experi_short+cc+'.dat'
    if fid lt 23 then printf,string(fid,fo='(i2)'),'ID  '+string(y,fo='('+strcompress(string(years),/remove_all)+'i6)') $
        else printf,string(fid,fo='(i2)'),'ID  hydr.year  Area(km2) day 274 275 ... 1 2 3 ... 273 (unit: mm/day) '
endfor

openw,5,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+sub_region+cc+'_bias.dat'
printf,5,'Lat  Lon(rea) dtemp  dprec  dvariab'

openw,7,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+sub_region+cc+'_SLE_volbz.dat'
printf,7,'Year  vol_<0masl(km3)'

openw,33,dirres+'/'+time_resolution+'/'+dir_region+subpath+long_GCM+sub_region+cc+'_calving_flux.dat'
printf,33,'ID  frontal ablation (Gt/a)'
