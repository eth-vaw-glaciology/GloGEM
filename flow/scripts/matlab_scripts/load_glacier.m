% Load the glacier geometry by Matthias (defined per elevation band) and 
% transform to be compatible to our 1-D equidistant model grid

function [sur_input,th_input,width_input,x_input,dx,volume_Huss_1d_fixeddistance,area_Huss_1d_fixeddistance,length_fixeddistance]=load_glacier(glacier_id,region,dx,frontal_length,display_during_flag)

%% Read in the data
glacier_geom=import_glacier_geometry(['../input/',region,'/flowline_geom/',num2str(glacier_id,'%05d'),'.dat']);  

%% Sometimes there is no mass in the lowest elevation bands --> remove these bands
i=find(glacier_geom(:,5)==0);
glacier_geom(i,:)=[];

%% (potentially) plot some figures illustrating this data (normally never plotted, but was useful for initial debugging)
if display_during_flag==1
    %%
    figure
    plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2,'LineWidth',2); hold on;
    plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2-glacier_geom(:,5),'LineWidth',2); hold on;
    ylabel('Elevation (m a.s.l)')
    xlabel('Distance (m)')
    grid minor;
    set(gca,'FontSize',16);
    
    %%
    figure
    yyaxis left;
    A(1)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2,'LineWidth',2); hold on;
    A(2)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2-glacier_geom(:,5),'LineWidth',2); hold on;
    ylabel('Elevation (m a.s.l)')
    %
    yyaxis right;
    A(1)=plot(glacier_geom(:,7),glacier_geom(:,4),'LineWidth',2); hold on;
    ylabel('Area (km^{2})')
    %
    xlabel('Distance (m)')
    grid minor;
    set(gca,'FontSize',16);
    
    %%
    figure
    yyaxis left;
    A(1)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2,'LineWidth',2); hold on;
    A(2)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2-glacier_geom(:,5),'LineWidth',2); hold on;
    ylabel('Elevation (m a.s.l)')
    %
    yyaxis right;
    A(1)=plot(glacier_geom(:,7),glacier_geom(:,6),'LineWidth',2); hold on;
    ylabel('Width (m)')
    %
    xlabel('Distance (m)')
    grid minor;
    set(gca,'FontSize',16);
    
    %%
    figure
    yyaxis left;
    A(1)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2,'LineWidth',2); hold on;
    A(2)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2-glacier_geom(:,5),'LineWidth',2); hold on;
    ylabel('Elevation (m a.s.l)')
    %
    yyaxis right;
    A(1)=plot(glacier_geom(:,7),(glacier_geom(:,4)*1e6).*glacier_geom(:,5),'LineWidth',2); hold on;
    ylabel('Volume (m^3)')
    %
    xlabel('Distance (m)')
    grid minor;
    set(gca,'FontSize',16);
end

%% Determine the original horizontal resolution in data Matthias (not equidistant, as is derived from elevation bands and slope between them!)
[length_glacier_geom b]=size(glacier_geom);
for i=2:length_glacier_geom
    dx_original(i)=glacier_geom(i,7)-glacier_geom(i-1,7);
end

%% Other potential figure to be displayed, showing the variation in the spatial resolution in data Matthias (again, may be useful for debugging)
if display_during_flag==1
    figure;
    plot(dx_original,'LineWidth',2);
    ylabel('Horizontal resolution of data Matthias (m)')
    grid minor;
    set(gca,'FontSize',16);
end

%% Interpolation to a regular (i.e. equidistant) grid:
if dx==0 % If dx is not defined: 100 grid cells over domain --> this is normally always used (for all simulations in the paper)
    dx=round(glacier_geom(length_glacier_geom,7)/100);
end
dx
grid_cells=floor(glacier_geom(length_glacier_geom,7)/dx);

for i=1:grid_cells
    x(i)=i*dx;
end

glacier_geom_lookup_x=glacier_geom(:,7);                         % m
glacier_geom_lookup_sur=(glacier_geom(:,2)+glacier_geom(:,3))/2; % m
glacier_geom_lookup_width=glacier_geom(:,6);                     % m
glacier_geom_lookup_th=glacier_geom(:,5);                        % m

i=find(glacier_geom_lookup_width==0); % Remove elevation bands with no ice
glacier_geom_lookup_x(i)=[];glacier_geom_lookup_sur(i)=[];glacier_geom_lookup_width(i)=[];glacier_geom_lookup_th(i)=[];

sur_x=interp1(glacier_geom_lookup_x,glacier_geom_lookup_sur,x,'linear','extrap');
width_x=interp1(glacier_geom_lookup_x,glacier_geom_lookup_width,x,'linear','extrap');
i=find(x<glacier_geom_lookup_x(1));width_x(i)=glacier_geom_lookup_width(1); % Width for cells lower than first point on Huss grid: same as width first point Huss grid
th_x=interp1(glacier_geom_lookup_x',glacier_geom_lookup_th',x,'linear','extrap');
i=find(x<glacier_geom_lookup_x(1));th_x(i)=glacier_geom_lookup_th(1); % Thickness for cells lower than first point on Huss grid: same as thickness first point Huss grid
bed_x=sur_x-th_x;

%% Additional figures displaying the interpolated data (normally never plotted, but was useful for initial debugging)
if display_during_flag==1
    figure;
    A(1)=plot(glacier_geom(:,7),glacier_geom(:,6),'LineWidth',2); hold on;
    A(2)=plot(x,width_x,'LineWidth',2); hold on;
    xlabel('Horizontal distance (m)')
    ylabel('Width (m)')
    legend(A,'Original data','Interpolated (X m regular grid)')
    grid minor
    set(gca,'FontSize',16);
    
    figure;
    A(1)=plot(glacier_geom(:,7),glacier_geom(:,5),'LineWidth',2); hold on;
    A(2)=plot(x,th_x,'LineWidth',2); hold on;
    xlabel('Horizontal distance (m)')
    ylabel('Thickness (m)')
    legend(A,'Original data','Interpolated (X m regular grid)')
    grid minor
    set(gca,'FontSize',16);
    
    figure;
    A(1)=plot(glacier_geom(:,7),(glacier_geom(:,2)+glacier_geom(:,3))/2,'LineWidth',2); hold on;
    A(2)=plot(x,sur_x,'LineWidth',2); hold on;
    xlabel('Horizontal distance (m)')
    ylabel('Surface elevation (m)')
    legend(A,'Original data','Interpolated (X m regular grid)')
    grid minor
    set(gca,'FontSize',16);
end

%% Check how much the volume and area have changed:
volume_Huss_1d=sum(glacier_geom(:,4)*1e6.*glacier_geom(:,5))
volume_Huss_1d_fixeddistance=sum(width_x(:).*th_x(:)*dx)
area_Huss_1d=sum(glacier_geom(:,4)*1e6)
area_Huss_1d_fixeddistance=sum(width_x(:).*dx)
i=find(th_x>1);length_fixeddistance=length(i)*dx;

%% Add geometric information for parts lower than glacier at inventory date
extra_grids=ceil((x(length(x))*frontal_length)/dx); % downstream of present-day glacier
x_concat(1:extra_grids)=x(length(x))+dx:dx:x(length(x))+extra_grids*dx; % will be placed upstream of present-day glacier
th_concat=zeros([1 extra_grids]);         % downstream of present-day glacier
width_concat=zeros([1 extra_grids]);      % downstream of present-day glacier

% load the bedrock in pre-frontal region (spacing = 125 m between each point):
load(['../input/',region,'/dem_extended/prefrontal_elev_',num2str(glacier_id,'%05d'),'.mat']); % Loads 'lowest_point_save'
prefrontal_elev=(lowest_point_save(3:end,3));
prefrontal_elev(1:end,2)=125:125:length(prefrontal_elev)*125;
highest_elev_pre_frontal=prefrontal_elev(1,1);
lowest_elev_pre_frontal=prefrontal_elev(end,1);
highest_x_pre_frontal=prefrontal_elev(1,2);
lowest_x_pre_frontal=prefrontal_elev(end,2);
slope=(highest_elev_pre_frontal-lowest_elev_pre_frontal)/(lowest_x_pre_frontal-highest_x_pre_frontal);
prefrontal_elev(end+1,1)=0;
prefrontal_elev(end,2)=lowest_elev_pre_frontal/slope+lowest_x_pre_frontal; % Distance at which elevation would be equal to zero (based on slope prefrontal area)

% Add the frontal elevation (where it is ice covered) also:
prefrontal_elev_final(1,1)=sur_x(1);
prefrontal_elev_final(1,2)=0;
prefrontal_elev_final=[prefrontal_elev_final;prefrontal_elev];

% Surface elevation in pre-frontal region:
for i=extra_grids:-1:1
    distance_from_front=(extra_grids+1-i)*dx;
    % Determine the surface elevation based on 'prefrontal_elev_final' array with interp1:
    sur_concat(i)=interp1(prefrontal_elev_final(:,2),prefrontal_elev_final(:,1),distance_from_front,'linear','extrap');    
end

% (Very slightly) adapt this transition to make it smooth: 
slope_bed=bed_x(2)-bed_x(1);
bias=(bed_x(1)-slope_bed)-sur_concat(end);
sur_concat=sur_concat+bias;

x_input=horzcat(x,x_concat);
sur_input=horzcat(sur_concat,sur_x);
th_input=horzcat(th_concat,th_x);
width_input=horzcat(width_concat,width_x); % values for the pre-frontal width (i.e. width_concat) are filled in later, in 'initial_geometry.m'

%% Apply a little smoothing, but make sure you do not create any new pre-frontal ice. i.e. Do not smooth frontal area
smooth_range=2;
i=find(th_input>0);front_pos=min(i);
th_input_smooth=smooth2a(th_input,smooth_range);
sur_input_smooth=smooth2a(sur_input,smooth_range);
th_input(front_pos+smooth_range:end)=th_input_smooth(front_pos+smooth_range:end);
sur_input(front_pos+smooth_range:end)=sur_input_smooth(front_pos+smooth_range:end);

%% Yet another plot that may be useful for debugging:
if display_during_flag==1
    figure
    plot(sur_input); hold on;
    plot(sur_input-th_input); % bedrock
end

end




