% A few operations to be performed at the end of the transient simulation 
% (i.e. at the end of the run): calculate the final ELA, save the variables in the
% workspace in a file, and potentially perform some final plotting

%% ELA, based on best fit (best option, because then obtain the same ELA as at begin of run, if SMB bias = 0)
ela_ss1=(-fit_order2_smb_mean(2)+sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1));
% ela_ss2=(-fit_order2_smb_mean(2)-sqrt(fit_order2_smb_mean(2)^2-4*fit_order2_smb_mean(1)*fit_order2_smb_mean(3)))/(2*fit_order2_smb_mean(1));
ela_ss=ela_ss1;

%% Some final plotting
if vol~='out' & isnan(vol)==0
    if isnan(vol)==0 % in seperate 'if': otherwise crash if vol=='out'
        if display_end_flag>0
            plot_final
        end
    end
end

%% Remove unnecessary rows in matrices and some variables that we do not want to save (to reduce the total file size!)
aflow_hist(counter_diag+1:end)=[];
area_hist(counter_diag+1:end)=[];
bal_mean_hist(counter_diag+1:end)=[];
time_hist(counter_diag+1:end)=[];
dt_hist(counter_diag+1:end)=[];
df_max_hist(counter_diag+1:end)=[];       
height_front_hist(counter_diag+1:end)=[];
length_hist(counter_diag+1:end)=[];    
vol_hist(counter_diag+1:end)=[];
% 
bal_hist(counter_diag+1:end,:)=[];
fluxdiv_plot_hist(counter_diag+1:end,:)=[];
th_hist(counter_diag+1:end,:)=[];

%
clear fluxdiv_plot_hist mb_obsrcm matrix matrix_obs % Other files don't matter: they do not need to be deleted, as they are anyway small...

%% Saving the files
if mb_type_flag==5
    if calibration_method==1
        save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1990_ss.mat'])
    elseif calibration_method==2
        save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1950_ss.mat'])
    end
elseif mb_type_flag==6 && floor(time)<2017
    save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_',num2str(inventory_date_id),'_tr.mat'])
elseif mb_type_flag==6 && floor(time)==2017
    save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_2017_tr.mat'])
elseif mb_type_flag==6 && floor(time)>=2100
    save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_',num2str(floor(time)),'_tr.mat'])
end

if calibration_method==0 % Only for test-cases. Normally not used
    save('example_output.mat')
end