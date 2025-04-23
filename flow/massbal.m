% Calculate the surface mass balance for every point (based on elevation
% dependent fit that was calculated before the time loop, in 'load_smb').
% Eventually a sinusoidal signal can be applied on top of this 
% (was used for first experiments/tests; now never used normally)

%% Elevation used to calculate the SMB
if mb_sur_flag==0 % Calculate mass balance based on observed geometry (i.e. not based on modelled transient geometry)
    mb_sur=obs_sur;
elseif mb_sur_flag==1 % Calculate mass balance based on modelled transient geometry (i.e. not based on observed geometry)
    obs_surf=obs_sur';
    mb_sur=sur; 
    z=find(sur>obs_surf);mb_sur(z)=obs_surf(z); % For points where ice thickness is larger than observation --> take observed elevation to calculate SMB (to avoid the very occasional problems where the SMB-elevation feedback would lead to an explosion..)
end

%% Define the SMB year
smb_year=floor(time+1); % e.g. if time = 1999 (1990.0 = end of summer 1990) --> smb-year = 2000 = 1999-2000.
if smb_year>2100; smb_year=2100; end % Can be the case at last time step

%% Define the SMB for every point on the grid:
if mb_type_flag==1 % Impose SMB profile (normally never used anymore)
    ela=mb_bias;
    for i=1:xnum
        if sur(i)<ela
            bal(i)=(mb_sur(i)-ela)*0.008;
        else
            bal(i)=(mb_sur(i)-ela)*0.003;
        end
    end
    bal(1)=0;
    bal(2)=0;
elseif mb_type_flag==5 % 5 = '1960-1990 mean' + bias eventually (this bias was already applied in 'load_smb.m')
    for i=1:xnum
        bal(i)=fit_order2_smb_mean(1)*mb_sur(i).^2+fit_order2_smb_mean(2)*mb_sur(i)+fit_order2_smb_mean(3);
    end
elseif mb_type_flag==6 % Every year separately: 1950/1990-->2100
    for i=1:xnum
        bal(i)=fit_order2_smb(smb_year-1950,1)*mb_sur(i).^2+fit_order2_smb(smb_year-1950,2)*mb_sur(i)+fit_order2_smb(smb_year-1950,3);
        if th(i)==0 && bal(i)>0; bal(i)=0; end; % To avoid that area increases rapidly if year with positive SMB (if positive SMB under glaciated area)
    end
end

%% if a committed loss experiments is considered: only apply the forcing after 2017
if chain>100 && smb_year>2017
    for i=1:xnum
        bal(i)=fit_order2_smb_mean(1)*mb_sur(i).^2+fit_order2_smb_mean(2)*mb_sur(i)+fit_order2_smb_mean(3);
    end
end

%% Determine the ELA
ela=(-fit_order2_smb_mean(2)+sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1));
if isreal(ela)==0 || isnan(ela)==1
    ela=-fit_order1_smb_mean(2)/fit_order1_smb_mean(1); % Rely on first order solution
end

%% Impose a sinusoidal signal on top (normally never used; just for tests)
if smb_sinus_flag>0
    freq=smb_sinus_flag;   % a
    amplitude=.75;         % m i.e. a^{-1}
    %
    a=mod(time,freq);
    b=sind((a/freq)*360);
    bal=bal+b*amplitude;
end








