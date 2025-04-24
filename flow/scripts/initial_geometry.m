% Define the observed geometry and generate the initial state

%% First ice covered cell (for the observed geometry at inventory date):
for i=1:xnum
    if th_input(i)>0
        first_icp=i;
        break
    end
end

%% Observed volume per grid and surface elevation
for i=1:xnum
    x(i)=(i/xnum)*domainsize;
    obs_vol(i)=th_input(i)*width_input(i)*dx;
    obs_sur(i)=sur_input(i);  % In some cases 'obs_sur' is needed for SMB calculations (when this is based on observed geometry and not on modelled geometry)
end
obs_vol_flowlinemodel=sum(obs_vol) % can be slightly different than 'volume_Huss_1d_fixeddistance', because of very slight smoothing at the end of 'load_glacier'

%% Observed surface width
if width_flag==1 || width_flag==2 % Rectangle or trapezium
    for i=1:xnum
        width_surface(i)=width_input(i);
        if width_surface(i)==0; width_surface(i)=mean(width_input(first_icp:first_icp+10)); end % For pre-frontal region: impose the average surface width of 10 lowest glacier covered cells
    end
end

%%  Observed bedrock and ice thickness
% Notice that here, in case of trapezium (width_flag==2) --> ice thickness 
% and bedrock elevation will be modified (vs. data from Matthias): to 
% ensure that the volume, area and surface elevation are conserved:
obs_vol_trapezium=0;
for i=xnum:-1:1 % In inverse direction (needed for triangle transect)
    if width_flag<2 % Constant width or rectangle shape
        obs_th(i)=th_input(i);
        lambda(i)=0;
        width_base(i)=width_surface(i);
    elseif width_flag==2 % Trapezium shape
        lambda(i)=lambda_standard;
        if width_input(i)==0 % for cells without ice: make sure that obs_th equals zero
            obs_th(i)=0;
        elseif width_input(i)>0 % ice covered cell
            a(i)=-dx*lambda(i)/2;
            b(i)=width_surface(i)*dx;
            c(i)=-1*(obs_vol(i));
            D(i)=b(i)^2-4*a(i)*c(i);
            obs_th(i)=(-b(i)+sqrt(D(i)))/(2*a(i));
        end
        
        % Width at the base and eventually correct lambda:
        if isreal(obs_th(i))==1
            width_base(i)=width_surface(i)-lambda(i)*obs_th(i);
            if width_base(i)<width_surface(i)/3
                width_base(i)=width_surface(i)/3;
                obs_th(i)=obs_vol(i)/(dx*(width_surface(i)+width_base(i))/2);
                lambda(i)=(width_surface(i)-width_base(i))/obs_th(i);
            end
        else % D was smaller than zero --> cannot repdroduce the observed volume for this cell with the imposed lambda (i.e. would need negative basal width). Determine the new lambda
            width_base(i)=width_surface(i)/3;
            obs_th(i)=obs_vol(i)/(dx*(width_surface(i)+width_base(i))/2);
            lambda(i)=(width_surface(i)-width_base(i))/obs_th(i);
        end
    end
    
    % To be done in every case (independent of width_flag)
    width_mid(i)=(width_surface(i)+width_base(i))/2;
    obs_vol_trapezium=obs_vol_trapezium+obs_th(i)*width_mid(i)*dx;
    bed(i)=obs_sur(i)-obs_th(i);
    width_mid_obs(i)=width_base(i)+0.5*lambda(i)*obs_th(i); % Needed for hypsometry plots
end

obs_vol_trapezium % Should be equal to obs_vol_flowlinemodel !

%%
if display_during_flag==1 % typically not displayed, but may be useful for debugging
    figure
    plot(th_input);hold
    plot(obs_th);
    title('th')
    legend('th input','obs th')
    grid minor
    set(gca,'FontSize',18);
    %
    figure
    plot(sur_input); hold on;
    plot(bed);
    %
    figure
    plot(atand(lambda/2))
    ylim([0 max(atand(lambda/2))*1.01])
end

%%  Initial state for modelling
if flag_startobs==0 % Start from situation without ice
    for i=1:xnum
        sur(i)=bed(i);
        th(i)=0; % not really needed, as is defined as an array with only zeros. But just for clarity
    end
elseif flag_startobs==1 % Start from observed state at inventory date
    for i=1:xnum
        sur(i)=obs_sur(i);
        th(i)=sur(i)-bed(i);
    end
elseif flag_startobs==2 % Start from modelled state (can be steady state or transient)
    % Nothing needs to be done, 'sur' and 'th' were already loaded in 'geom_files_load_and_transform.m'
end

%%  Set boundary conditions (could potentially be removed it seems)
  bed(1)        = bed(3);
  bed(2)        = bed(3);
  bed(xnum)     = bed(xnum-1);
%
  obs_sur(1)     = bed(3);
  obs_sur(2)     = bed(3);
%
  th(1)=0;
  th(2)=0;

%%
if display_during_flag==1 % typically not displayed, but may be useful for debugging
    figure
    plot(width_base); hold on
    plot(width_mid); hold on;
    plot(width_surface)
    title('width')
end

%% Points needed to check if ice is leaving the domain (if so, the time loop will be stopped, see glacier.m). Depends on the flow direction (i.e. from 'left to right' or 'from right to left')
if sur(2)<sur(xnum) % Ice flow from 'right to left'
    domain_exit_index=3;
else % Ice flow from 'left to right'
    domain_exit_index=xnum-2
end