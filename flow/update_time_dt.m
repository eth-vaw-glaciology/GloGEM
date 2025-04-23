% Update the maximum time step allowed (dt_max), the time step itself (dt)
% and the time indeces ('t' and 'time')

% Note that this is specific for Alps and was found with some 'trial and
% error'. Will need other values for other regions in the world (e.g. with
% longer glaciers)

dt_max=time/(dx*2); % Maximum allowed dt (dt will never be larger than this, even if the CFL criterion would allow for it). Small in the beginning --> increases with time
if dt_max<0.1
    dt_max=0.1; % Maximum time step should at least be 0.1 years (because otherwise very small in the beginning --> takes too long)
elseif dt_max>dtmb % Don't want the time step to be larger than the time step of DTMB (typically 1 year)
    dt_max=dtmb;
end

if dt_flag==0 && t>2  % Adapt the time step:
    dt = (dx^2/(max(df)))*dtfactor; % CFL type of criterion, multiplied with the 'dtfactor'
    if dt>dt_max; dt=dt_max; end % If needed: impose limit on the dt 
end

t=t+1;        % timestep (integer)
time=time+dt; % time (in years)