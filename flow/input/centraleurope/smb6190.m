% ----------------------------------------------------------------------- %
% --- This script calculates the 1960-1990 SMB for the geometry at the -- %
% ------------- inventory date (static, i.e. no ice dynamics)------------ %
% ----------------------------------------------------------------------- %

close all
clear
clc

chain_id=[1] % Past: always taken from chain01
figure_flag=0; % 0 = don't display any figures; 1 = display figures

rho=900

load(['glacier_stats.mat']);
id=index_larger_than_1_km_glaciers_save';
id_start=0;
id_end=4000;
i=find(id<id_start);id(i)=[];
i=find(id>id_end);id(i)=[];
i=find(id==3678);id(i)=[];

start_year_smb=1961 % 1961
end_year_smb=1990   % 1990
% need start_year_smb=1961 && end_year_smb=1990 to save files for run for chain 01 (because need SMB info for first guess ELA change)

for chain=chain_id
    for glacier_id=id
        glacier_id
        clearvars -except glacier_id id rho start_year_smb end_year_smb chain figure_flag
        mb_obs_eobs=import_glacier_smb(['smb_rcm/chain',num2str(chain,'%02d'),'/belev_',num2str(glacier_id,'%05d'),'.dat']); % SMB as calculated based on OBS/RCM output (Data from Matthias from March 2018)
        glacier_geom=import_glacier_geometry_1d(['flowline_geom/',num2str(glacier_id,'%05d'),'.dat']);
        
        i=find(mb_obs_eobs(:,2)==-99);mb_obs_eobs(i,:)=[];glacier_geom(i,:)=[];
        
        mb_obs_eobs(:,2:end)=mb_obs_eobs(:,2:end)/(rho/1000); % column 2 = 1950-1951; column 142 = 2099-2100 !!!!! From m w.e. to m i.e. !!!! (all calculations in our model are in m i.e.)
        [rows,columns]=size(mb_obs_eobs);
        for i=1:rows
            mean_mb(i)=mean(mb_obs_eobs(i,start_year_smb-1949:end_year_smb-1949));
        end
        
        % Best SMB mean fit (2nd order, i.e. parabola) over the [start_year_smb]-[end_year_smb] period:
        fit_order2_smb_mean=polyfit(mb_obs_eobs(:,1),mean_mb',2);
        ela_observed=(-fit_order2_smb_mean(2)+sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1)); % Observed ELA based on [start_year_smb]-[end_year_smb] mean (first possible value)
        
        % Calculate the average SMB ([start_year_smb]->[end_year_smb]), based on best-fit:
        sum_smb=0;
        counter=0;
        for i=1:rows
            warning('off')
            counter=counter+glacier_geom(i,4); % glacier_geom(i,4) = area for this elevation band
            bal_this_elevation=fit_order2_smb_mean(1)*mb_obs_eobs(i,1)^2+fit_order2_smb_mean(2)*mb_obs_eobs(i,1)+fit_order2_smb_mean(3);
            sum_smb=sum_smb+bal_this_elevation*glacier_geom(i,4);
        end
        bal_mean_observed=sum_smb/counter; % [start_year_smb]-[end_year_smb] mean SMB (based on geometry at inventory date)
        
        % Repeat, with different ELAs (to find which ELA dif is needed to have a zero MB)
        ela_counter=0;
        for ela_change=-200:10:200
            ela_counter=ela_counter+1;
            sum_smb=0;
            counter=0;
            for i=1:rows
                counter=counter+glacier_geom(i,4); % glacier_geom(i,4) = area for this elevation band
                bal_this_elevation=fit_order2_smb_mean(1)*(mb_obs_eobs(i,1)-ela_change)^2+fit_order2_smb_mean(2)*(mb_obs_eobs(i,1)-ela_change)+fit_order2_smb_mean(3);
                sum_smb=sum_smb+bal_this_elevation*glacier_geom(i,4);
            end
            bal_mean_observed_different_ela=sum_smb/counter; % [start_year_smb]-[end_year_smb] mean SMB (based on geometry at inventory date)
            ela_change_matrix(ela_counter,1)=ela_change;
            ela_change_matrix(ela_counter,2)=bal_mean_observed_different_ela;
        end
        
        % ELA at which the SMB = 0: based on linear interpolation.
        ela_dif_tohave0smb=interp1(ela_change_matrix(:,2),ela_change_matrix(:,1),0,'linear','extrap');
        % Check that SMB is really (close to) zero for this ELA:
        sum_smb=0;
        counter=0;
        for i=1:rows
            counter=counter+glacier_geom(i,4); % glacier_geom(i,4) = area for this elevation band
            bal_this_elevation=fit_order2_smb_mean(1)*(mb_obs_eobs(i,1)-ela_dif_tohave0smb)^2+fit_order2_smb_mean(2)*(mb_obs_eobs(i,1)-ela_dif_tohave0smb)+fit_order2_smb_mean(3);
            sum_smb=sum_smb+bal_this_elevation*glacier_geom(i,4);
        end
        bal_mean_want_to_be_zero=sum_smb/counter; % 1960-1990 mean SMB (based on geometry at inventory date)
        
        if start_year_smb==1961 && end_year_smb==1990 && chain==1 % This will be used for simulations for past evolution
            ela_dif_tohave0smb_6190=ela_dif_tohave0smb;
            save(['smb_rcm/chain',num2str(chain,'%02d'),'/smb6190_',num2str(glacier_id,'%05d')],'bal_mean_observed','ela_observed','ela_dif_tohave0smb_6190')
        end
    end
    
end