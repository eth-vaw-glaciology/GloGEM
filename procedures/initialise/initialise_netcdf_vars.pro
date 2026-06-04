; *************************************************************
; initialise_netcdf_vars
;
; Initialise and accumulate NetCDF output variables over the
; initial (constant) glacierized area, for both monthly and
; daily model configurations. Used for GlacierMIP4-compliant
; output when write_netcdf eq 'y'.
;
; Four variables are tracked here that are not part of the standard
; GloGEM output routines:
;
;   tempmo_ini  - near-surface air temperature [K], area-weighted
;                 mean over the initial glacierized area, monthly
;   precmo_ini  - total precipitation [m w.e. x km2] summed over
;                 the initial glacierized area, monthly
;   tempday_ini - same as tempmo_ini but at daily resolution
;   precday_ini - same as precmo_ini but at daily resolution
;
; Precipitation is stored as an unnormalised total (m w.e. x km2)
; so that values from multiple glaciers can be summed directly
; before converting to kg in the write procedure (multiply by 1e9).
;
; This procedure serves a dual role:
;   (1) Initialisation: on the first time step of each glacier
;       (ccmon eq 1) all arrays are reset to snoval.
;   (2) Accumulation: on every call the values for the current
;       time step are stored at index ccmon-1.
;
; It is designed to be called once per time step (monthly or daily)
; from the main model loop, directly after @store_output_variables.
;
; Expected variables in scope (provided by glogem.pro):
;   ccmon            - cumulative time step counter (1-based)
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

; Reset all arrays at the start of each new glacier run
if ccmon eq 1 then begin
    tempmo_ini  = dblarr(years*12)  + snoval
    precmo_ini  = dblarr(years*12)  + snoval
    tempday_ini = dblarr(years*365) + snoval
    precday_ini = dblarr(years*365) + snoval
endif

area_ini_total = total(area_ini)
if area_ini_total eq 0 then goto, skip_netcdf_vars

if time_resolution eq 'monthly' then begin
    ; Area-weighted mean temperature converted from deg C to K
    tempmo_ini[ccmon-1] = total((tg + 273.15d) * area_ini) / area_ini_total
    ; Total precipitation (solid + liquid) over the initial area [m w.e. x km2]
    precmo_ini[ccmon-1] = total((psg + plg) * area_ini)
endif else begin
    tempday_ini[ccmon-1] = total((tg + 273.15d) * area_ini) / area_ini_total
    precday_ini[ccmon-1] = total((psg + plg) * area_ini)
endelse

skip_netcdf_vars:
