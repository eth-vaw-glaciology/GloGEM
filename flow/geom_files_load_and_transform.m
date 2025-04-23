% Inventory date is loaded and the glacier geometry is loaded from files
% provided by Matthias Huss. Subsequently, the geometric info from a
% previous model run can eventually be loaded.

%% RGI inventory date
load(['../input/',region,'/inventory_date.dat']) % Load the RGI inventory_date of all glaciers
inventory_date_id=inventory_date(glacier_id); % RGI inventory date for specific glacier
clear inventory_date % Clear the RGI inventory_date of all glaciers (not needed anymore)

%% Load geometry from the files of Matthias with 'load_glacier' function (this needs to be done in every case, also when simulations will start from a modelled glacier geometry)
[sur_input,th_input,width_input,x_input,dx,volume_Huss_1d_fixeddistance,area_Huss_1d_fixeddistance,length_fixeddistance]=load_glacier(glacier_id,region,dx,frontal_length,display_during_flag);

%% If needed: can load data from a modelled geometry (can be a steady state or a transient geometry --> in paper: always start simulations in 1950/1990 from a steady state)
if flag_startobs==2 % Start from a modelled state
    % Keep the observed surface (sur_input), observed thickness (th_input), observed width (width_input), observed volume (volume_Huss_1d_fixeddistance), observed area (area_Huss_1d_fixeddistance) and observed length (length_fixeddistance) (observed = at RGI inventory date)
    
    % Load/Overwrite: 'x_input','dx','sur','th' from calibrated geometry (is always from chain01)
    if start_year==1950 % Calibration method == 2
        load(['../output/',region,'/data_rcm/chain01/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1950_ss.mat'],'x_input','dx','sur','th');
    elseif start_year==1990 % Calibration method == 1
        load(['../output/',region,'/data_rcm/chain01/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1990_ss.mat'],'x_input','dx','sur','th');
    % Could eventually also add cases where start from other periods (e.g. at inventory date or in 2017), but this is not used so far (all transient simulations start at the steady state date)
    end
end