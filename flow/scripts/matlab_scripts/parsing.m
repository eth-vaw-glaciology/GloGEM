% Parsing: makes sure the parameters (that may or may not have been given as an input to the glacier function) are assigned
% This script doesn't do anything special. Just making sure that all the
% parameters are defined. Should not be changed normally

parse(p,varargin{:});

aflow  = p.Results.aflow;
calibration_method = p.Results.calibration_method;
dx = p.Results.dx;
display_during_flag = p.Results.display_during_flag;
display_end_flag = p.Results.display_end_flag;
dtfactor = p.Results.dtfactor;
dt_flag = p.Results.dt_flag;
flag_startobs = p.Results.flag_startobs;
frontal_length = p.Results.frontal_length;
mb_bias_flag = p.Results.mb_bias_flag;
mb_sur_flag = p.Results.mb_sur_flag;
mb_type_flag = p.Results.mb_type_flag;
nyears = p.Results.nyears;
smb_sinus_flag = p.Results.smb_sinus_flag;
ss_criterion = p.Results.ss_criterion;
start_year = p.Results.start_year;
width_flag = p.Results.width_flag;