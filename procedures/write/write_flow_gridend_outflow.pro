; *************************************************************
; write_flow_gridend_outflow
;
; One row per glacier in *_flow_gridend_outflow.dat (unit 36, opened in
; initialise_results_files): ice that left the downstream end of the
; flowline grid in each year, in m w.e. over that year's Area (the unit
; of Frontal_ablation), after the bed elevation of the last active
; flowline cell and how the outflow was booked (flow_gridend_outflow):
;   frontal  as frontal ablation
;   melt     as ice melt ('melt_if_land' and bed at or above 0 m)
;   none     the flow model did not run for this glacier
; *************************************************************

compile_opt idl2

if flow_ge_bed eq -9999d0 then wg_book = 'none' $
else if flow_gridend_outflow eq 'melt_if_land' and flow_ge_bed ge 0d0 then wg_book = 'melt' $
else wg_book = 'frontal'
printf,36,id[gg[g]],flow_ge_bed,wg_book,flow_gridend,fo='(a,f10.1,a9,'+strcompress(string(years),/remove_all)+'f10.5)'
