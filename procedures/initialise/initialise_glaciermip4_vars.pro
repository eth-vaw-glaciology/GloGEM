; *************************************************************
; initialise_glaciermip4_vars
;
; Initialise and accumulate GlacierMIP4-specific monthly output
; variables over the initial (constant) glacierized area.
;
; Two variables are tracked here that are not part of the standard
; GloGEM output routines, both required by GlacierMIP4:
;
;   tempmo_ini  - near-surface air temperature [K], area-weighted
;                 mean over the initial (time-invariant) glacierized
;                 area per elevation band
;   precmo_ini  - total precipitation [m w.e. x km2] summed over
;                 the initial glacierized area (solid + liquid).
;                 Stored as an unnormalised total so that values
;                 from multiple glaciers can be summed directly
;                 before converting to kg in the write procedure
;                 (multiply by 1e9).
;
; This procedure serves a dual role:
;   (1) Initialisation: on the first time step of each glacier
;       (ccmon eq 1) the arrays are reset to snoval.
;   (2) Accumulation: on every monthly call the values for the
;       current time step are stored at index ccmon-1.
;
; It is designed to be called once per monthly time step from the
; main model loop, directly after @store_output_variables.pro.
;
; Expected variables in scope (provided by glogem.pro):
;   ccmon            - cumulative monthly counter (1-based)
;   years            - total number of years in the run
;   snoval           - no-data fill value (e.g. -99)
;   tg[nb]           - near-surface air temperature per elevation
;                      band [deg C], already lapse-rate corrected
;   psg[nb]          - solid precipitation per elevation band [m w.e.]
;   plg[nb]          - liquid precipitation per elevation band [m w.e.]
;   area_ini[nb]     - initial glacier area per elevation band [km2],
;                      held constant throughout the run
;   time_resolution  - 'monthly' or 'daily'
; *************************************************************

compile_opt idl2

; Reset arrays at the start of each new glacier run
if ccmon eq 1 then begin
    tempmo_ini = dblarr(years*12) + snoval
    precmo_ini = dblarr(years*12) + snoval
endif

; Accumulate for the current monthly time step (monthly model only)
if time_resolution eq 'monthly' then begin
    area_ini_total = total(area_ini)
    if area_ini_total gt 0 then begin
        ; Area-weighted mean temperature converted from deg C to K
        tempmo_ini[ccmon-1] = total((tg + 273.15d) * area_ini) / area_ini_total
        ; Total precipitation (solid + liquid) over the initial area [m w.e. x km2]
        precmo_ini[ccmon-1] = total((psg + plg) * area_ini)
    endif
endif
