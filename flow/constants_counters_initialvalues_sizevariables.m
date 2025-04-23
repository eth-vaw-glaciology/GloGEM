% Define constants, initialize counters, variables and parameters and set their size

%% Constants
g            = 9.81;		 % Gravitational acceleration in m/s^2
nflow        = 3;            % Flow law exponent n
rho          = 900;		     % Density of ice in kg/m^3

%% Counters, variables and parameters to be initialized

% Mass transport:
df_max         = 0; % Maximum modelled diffusivity factor 
df_lim=(length_fixeddistance^2)/2; % maximum value allowed for the diffusivity factor is related to the observed glacier length at inventory date (will likely have to be modified for other regions than the Alps)

% Time:
counter_diag   = 0;
if dt_flag==0 % Dynamic time step (i.e. dt changes over time). First value to be used is based on CFL-criterion
    dt = dtfactor*dx^2/(df_lim);
else
    dt = dt_flag;
end
dtdiag = 1;                  % Time step diagnostic output (years)
dtmb   = 1;                  % Time step surface mass balance model
next_time_diag = start_year; % Next time that diagnostic model output will be written out: set equal to start_year --> will immediately write out
next_time_mb   = start_year; % Next time that diagnostic model output will be written out: set equal to start_year --> will immediately write out
t              = 0;          % number of timesteps that have occurred so far
time           = start_year; % Time (in years)

% Geometry:
domainsize = x_input(length(x_input));  % in meter; from 'x_input', which was generated in 'load_glacier'
first_icp_min=9999;
% lambda_standard=tand(0)+tand(0); % sensitivity test in paper --> saved in 'calibration 3' folder (manually) 
lambda_standard=tand(45)+tand(45); % i.e. lamda = 2
% lambda_standard=tand(80)+tand(80); % sensitivity test in paper --> saved in 'calibration 4' folder (manually)

last_icp_max=0;                       % last ice covered point (icp) (index)
xnum      = floor(domainsize/dx);     % number of grid cells
if xnum>length(width_input)
    xnum=xnum-1;
end

% SMB:
ela_ss=0;
    
%% Size variables that will (in most cases) be updated (i.e. overwritten) at every (few) time step(s)
bal           = zeros(xnum,1);	    % Mass balance
bed           = zeros(xnum,1);		% Bedrock elevation
df            = zeros(xnum,1);	    % Diffusivity factor
fluxdiv       = zeros(xnum,1);      % Flux divergence	        
fluxdiv_plot  = zeros(xnum,1);      % Flux divergence to be plotted
fluxdiv_plot2 = zeros(xnum,1);      % Flux divergence to be plotted
grad          = zeros(xnum,1);      % Surface gradient
lambda        = zeros(xnum,1);      % Lambda: angle trapezium describing the glacier cross section
if flag_startobs ~=2 % If start from modelled geometry, don't want to set the surface elevation to zero
    sur           = zeros(xnum,1);  % Surface elevation
end
term1         = zeros(xnum,1);      % Part of the continuity equation (see 'ice_thickness.m'), also used for fluxdiv_plot, in 'diagnostic_write.m'
term2         = zeros(xnum,1);      % Part of the continuity equation (see 'ice_thickness.m'), also used for fluxdiv_plot, in 'diagnostic_write.m'
if flag_startobs ~=2 % If start from modelled geometry, don't want to set the ice thickness to zero
    th            = zeros(xnum,1);	% Ice thickness
end
vel           = zeros(xnum,1);      % Velocities

%% Size prognostic variables that are written out every dtdiag timesteps (typically used to have overview at end of the run)

% scalars:
aflow_hist          = zeros(ceil(nyears/dtdiag),1);
area_hist           = zeros(ceil(nyears/dtdiag),1);
bal_mean_hist       = zeros(ceil(nyears/dtdiag),1);
time_hist           = zeros(ceil(nyears/dtdiag),1);
dt_hist             = zeros(ceil(nyears/dtdiag),1);
df_max_hist         = zeros(ceil(nyears/dtdiag),1);
height_front_hist   = zeros(ceil(nyears/dtdiag),1);
length_hist         = zeros(ceil(nyears/dtdiag),1);
vol_hist            = zeros(ceil(nyears/dtdiag),1);

% vectors:
bal_hist            = zeros(ceil(nyears/dtdiag),xnum);
fluxdiv_plot_hist   = zeros(ceil(nyears/dtdiag),xnum);
th_hist             = zeros(ceil(nyears/dtdiag),xnum);