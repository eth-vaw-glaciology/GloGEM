; ----------------------------------------------------------------------- ;
; ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)---- ;
; ------------ Adaptation into idl by: Janosch Beer (2025) -------------- ;
; ------- glacierflow function: time-evolution of the glacier   --------- ;
; ----------------------------------------------------------------------- ;

; Define default parameters
compile_opt idl2
aflow = 1e-16 ; X = value of deformation-sliding factor (10^-16 Pa^-3 a^-1)
calibration_method = 0 ; 0 = no calibration (for tests/examples, is not used in paper); 1 = 1990 steady state --> match inventory date length and volume; 2 = 1950 steady state --> match inventory date volume (important for read-in and read-out of various files)
dx = 0 ; 0 = resolution will be chosen to ensure that the observed glacier is divided into 100 grid cells; X = resolution (m)
display_during_flag = 0 ; 0 = do not display anything during run (geometry and smb stuff); 1 = display during run --> may be useful for debugging/checks (is normally not used)
display_end_flag = 0 ; 0 = do not display anything in the end; 1 = save one final figure; 2 = display all, but no movie; 3 = time lapse movie with only geometry, 4 = time lapse movie with only geometry + save movie .pdf files; 5 = 'full' time lapse movie, 6 = full movie + save movie as .pdf files
dtfactor = 1 ; X = multiply dt by a certain factor --> can be used to avoid numerical instability
dt_flag = 0 ; 0 = adaptive time step (dynamic); X = time step in years
flag_startobs = 1 ; 0 = start from zero ice thickness; 1 = start from observed geometry (at RGI inventory date); 2 = start from modelled geometry
frontal_length = 1.0 / 4.0 ; X = length of proglacial area (defined as fraction of glacier length: e.g. 0.5 --> if glacier is 5 km long, a proglacial area of 2.5 km will be added)
mb_bias_flag = 0 ; 0 = run with original climatic data (no bias); 'on' = will impose mb bias on top of 1981-2016 (so that specific SMB observed geometry = 0), is typically not used; X = Bias to be applied on top of calculated SMB field (formulated as a change in ELA)
mb_sur_flag = 1 ; 0 = SMB is calculated based on observed geometry (i.e. no SMB-elevation feedback); 1 = dynamic, SMB is calculated based on prognostic geometry
mb_type_flag = 5 ; 1 = imposed ELA and SMB gradients (normally not used); 2 = 1980-2016 mean from GCM output; 3 = every year from 1980 to 2016 (from GCM) individually, in sequence; 4 = every year from 1990 to 2016 (from GCM) individually, in sequence; 5 = 1960-1990 mean from E-OBS (+ eventual perturbation); 6 = 1951-2099/2100 from E-OBS + EURO-CORDEX (transient runs)
nyears = 5000 ; X = number of years for simulation (will stop earlier if steady state is reached, if numerical instability occurred, if ice is leaving the domain, or if there is no ice)
smb_sinus_flag = 0 ; 0 = no perturbation on SMB signal; X = put sinusoidal signal on SMB, with frequency of X years (deviation is X m i.e. a^{-1} --> modify in massbal.m) (should only be used for testing purposes, never used for paper)
ss_criterion = 0.01 ; X = steady state is reached when the volume change is less than X percent per dtdiag (i.e. typically when the volume change is less than 0.01% per year)
start_year = 0 ; X = year in which the simulation starts (typically 0 for steady state experiments, and real year (e.g. 1950/1990) for transient simulations)
width_flag = 2 ; 0 = same width along the flowline (never used, may even not work anymore; was used for initial tests); 1 = rectangle transect (only used for sensitivity tests in paper); 2 = trapezium transect (classic)

; TODO: conversion of vertically equidistant grid to horizontally equidistant grid
@geom_files_load_and_transform

; ------------------------------------------ ;
; Update the time and the time step
@update_time_dt

; ------------------------------------------ ;
; Diffusivity factor calculation
@diffusivity

; ------------------------------------------ ;
; Ice thickness change calculation (i.e. solve continuity equation)
@ice_thickness
