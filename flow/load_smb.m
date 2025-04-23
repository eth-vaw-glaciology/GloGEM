% Load the SMB from Matthias and transform to elevation-dependent
% relationship (for the 1961-1990 period, needed for steady state
% simulations), or for individual years (needed for transient runs).
% Biases can be applied on top of this if needed (see end of this script)

%% Load SMB data
if chain<=100 % chain from EURO-CORDEX ensemble
    mb_obsrcm=import_glacier_smb(['../input/',region,'/smb_rcm/chain',num2str(chain,'%02d'),'/belev_',num2str(glacier_id,'%05d'),'.dat']); % SMB as calculated based on OBS/RCM output (data from Matthias)
else % For committed loss experiments: load data from chain01 (because are based on pre-2017 climate, and this is the same in every chain)
    mb_obsrcm=import_glacier_smb(['../input/',region,'/smb_rcm/chain01/belev_',num2str(glacier_id,'%05d'),'.dat']); % SMB as calculated based on OBS/RCM output (data from Matthias)
end

%% Remove NaN's (-99 in data Matthias) and transform to m i.e. a^-1
i=find(mb_obsrcm(:,2)==-99);mb_obsrcm(i,:)=[];
mb_obsrcm(:,2:end)=mb_obsrcm(:,2:end)/(rho/1000); % column 2 = 1950-1951; column 142 = 2099-2100 !!!!! From m w.e. to m i.e. !!!! (all calculations in our model are in m i.e.)

%% Determine the mean SMB over the period 1960-1990 or over a specific period for the committed loss simulations
[rows,columns]=size(mb_obsrcm);
for i=1:rows
    mean_mb(i)=mean(mb_obsrcm(i,12:41)); % 1960-1990 average: classic
    if chain>100 % Committed loss experiments
        start_year_com=floor(chain/100)
        end_year_com=chain-100*start_year_com
        if start_year_com<20; start_year_com=start_year_com+100; end
        if end_year_com<20; end_year_com=end_year_com+100; end
        mean_mb(i)=mean(mb_obsrcm(i,start_year_com-49:end_year_com-49));
    end
end

%% Generate a second-order elevation-dependent fit through these points: 
% Best SMB mean fit (2nd order, i.e. parabola) over the 1960-1990 period:
fit_order2_smb_mean=polyfit(mb_obsrcm(:,1),mean_mb',2);
% Best SMB fit (2nd order, i.e. parabola) for every individual year
for i=1:columns-1
    fit_order2_smb(i,1:3)=polyfit(mb_obsrcm(:,1),mb_obsrcm(:,i+1),2);
end

%% Observed ELA
% % From data:
% [C, ia, ic]=unique(mean_mb);
% ela_observed=interp1(mean_mb(ia)',glacier_geom_lookup_sur(ia),0)
% From best fit (best option, because then obtain the same ELA at end of run, if SMB bias = 0)
ela_observed1=(-fit_order2_smb_mean(2)+sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1)); % Observed ELA based on 1960-1990 mean (first possible value)
ela_observed2=(-fit_order2_smb_mean(2)-sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1)); % Observed ELA based on 1960-1990 mean (second possible value)
ela_observed=ela_observed1

%% Potentially adapt the fit to a linear fit if a problem occurred:
if isreal(ela_observed)==0 % Problem occured with 2-D fit, because max is lower than 0 (i.e. can't find ELA) --> redo with linear fit
    fit_order1_smb_mean=polyfit(mb_obsrcm(:,1),mean_mb',1);
    for i=1:columns-1
        fit_order1_smb(i,1:2)=polyfit(mb_obsrcm(:,1),mb_obsrcm(:,i+1),1);
    end
    % Fill in the 'fit_order2_smb' structure:
    fit_order2_smb_mean(1)=0;fit_order2_smb_mean(2:3)=fit_order1_smb_mean(1:2);
    fit_order2_smb(:,1)=0;fit_order2_smb(:,2:3)=fit_order1_smb(:,1:2);
    %
    ela_observed=-fit_order1_smb_mean(2)/fit_order1_smb_mean(1)
end

%% Calculate the average SMB (1960-1990)
sum_smb=0;
counter=0;
for i=2:xnum-1
    if obs_th(i)>0 % Only for elevations that are ice covered
        counter=counter+width_surface(i);
        bal_this_elevation=fit_order2_smb_mean(1)*obs_sur(i).^2+fit_order2_smb_mean(2)*obs_sur(i)+fit_order2_smb_mean(3);
        sum_smb=sum_smb+bal_this_elevation*width_surface(i);
    end
end
bal_mean_observed=sum_smb/counter % 1960-1990 mean SMB (based on geometry at inventory date)

%% Potentially display the fit
if display_during_flag==1
    figure
    plot(mb_obsrcm(:,1),mean_mb,'LineWidth',3);hold on;
    plot(mb_obsrcm(:,1),fit_order2_smb_mean(1)*mb_obsrcm(:,1).^2+fit_order2_smb_mean(2)*mb_obsrcm(:,1)+fit_order2_smb_mean(3),'LineWidth',2,'LineStyle','--')
    xlabel('Elevation (m)');
    ylabel('Average SMB (over selected time period)');
    title('Best fit SMB (before applying eventual SMB bias)')
    grid minor
    set(gca,'FontSize',16);
end

%% Apply potential biases
if mb_bias_flag==0
    bias_to_be_applied=0;
elseif mb_bias_flag=='on' % have an integrated SMB of 0 over the glacier (typically not used anymore; was used for initial tests)
    bias_to_be_applied=-1*bal_mean_observed
elseif mb_bias_flag~=0
    bias_to_be_applied=-1*(fit_order2_smb_mean(1)*(ela_observed+mb_bias_flag)^2+fit_order2_smb_mean(2)*(ela_observed+mb_bias_flag)+fit_order2_smb_mean(3)) % SMB at elevation where want ELA to be (multiplied by -1)
end
fit_order2_smb_mean(3)=fit_order2_smb_mean(3)+bias_to_be_applied;
fit_order2_smb(:,3)=fit_order2_smb(:,3)+bias_to_be_applied;

%% For some RCM chains --> no 2099-2100 SMB --> take the one from the previous year (2098-2099) in this case and impose this as the 2099-2100 SMB
if isnan(fit_order2_smb(end,1))==1
    fit_order2_smb(end,1:3)=fit_order2_smb(end-1,1:3);
end