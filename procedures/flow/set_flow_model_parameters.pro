; ---------------------------------

; This script sets the flow parameters for GloGEMflow

; ---------------------------------

; Define default parameters
compile_opt idl2
aflow = 1e-16 ; X = value of deformation-sliding factor (10^-16 Pa^-3 a^-1)
dtfactor = 0.9 ; X = multiply dt by a certain factor --> can be used to avoid numerical instability
dt_flag = 0 ; 0 = adaptive time step (dynamic); X = time step in years
flag_startobs = 1 ; 0 = start from zero ice thickness; 1 = start from observed geometry (at RGI inventory date); 2 = start from modelled geometry
frontal_length = 1.0 / 4.0 ; X = length of proglacial area (defined as fraction of glacier length: e.g. 0.5 --> if glacier is 5 km long, a proglacial area of 2.5 km will be added)
nyears = 5000 ; X = number of years for simulation (will stop earlier if steady state is reached, if numerical instability occurred, if ice is leaving the domain, or if there is no ice)
start_year = 0 ; X = year in which the simulation starts (typically 0 for steady state experiments, and real year (e.g. 1950/1990) for transient simulations)
width_flag = 2 ; 0 = same width along the flowline (never used, may even not work anymore; was used for initial tests); 1 = rectangle transect (only used for sensitivity tests in paper); 2 = trapezium transect (classic)
