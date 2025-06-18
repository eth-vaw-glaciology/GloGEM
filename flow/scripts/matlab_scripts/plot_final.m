% Final ploting!

%% In for a movie? --> get the popcorn ready!
if display_end_flag>2 % flow line movie
    figure;
    set(gcf,'Units','centimeters');
    if display_end_flag==3 || display_end_flag==4
        set(gcf,'Position',[0 1 35 30]);
    else
        set(gcf,'Position',[0 1 60 30]);
    end
    for i=1:counter_diag
        pause(0.0005*dtdiag)
        %
        if display_end_flag>=5
            subplot(2,3,[1 2 4 5])
        end
%             area(x/1000,zeros(size(bed)),'FaceColor',[0 0 1]); hold on
            area(x/1000,bed+th_hist(i,:)','FaceColor',[0 .8 1]);hold on; % Color everything under surface in blue
            area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on; % Color the bedrock in light grey
%             if start_year==1950 || start_year==1990 % Dotted line is observed geometry at inventory date
                C=plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
                l=legend(C,['Observed glacier geometry (in ',num2str(inventory_date_id),', at inventory date)'])
                l.Location='NorthWest';
%             else % Dotted line is modelled geometry at inventory date
%                 C=plot(x/1000,bed+th_hist(15,:)','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
%                 legend(C,'Glacier geometry in 2017')
%             end
            xlabel('Distance (km)');
            ylabel('Elevation (km)');
            title(['Year ',num2str(floor(time_hist(i)))]);
            set(gca,'FontSize',22);
            xlim([dx (domainsize-dx)]/1000)
            ylim([min(bed)-20 max(bed)+100])
            hold off;
        if display_end_flag>=5
        subplot(2,3,3)
            yyaxis left
            plot(time_hist(1:i),vol_hist(1:i),'LineWidth',2);
            ylabel('Volume (km^3)');
            ylim([min(vol_hist(1:counter_diag))*0.98 max(vol_hist(1:counter_diag))*1.02])
            %
            yyaxis right
            plot(time_hist(1:i),bal_mean_hist(1:i),'LineWidth',2);
            ylabel('Specific SMB (m ice eq. a^{-1})');
            ylim([min(bal_mean_hist(1:counter_diag))*0.98 max(bal_mean_hist(1:counter_diag))*1.02])
            %
            xlabel('Time (a)');
%             title([num2str(floor(time_hist(i))) ' a'])
            set(gca,'FontSize',22);
            xlim([start_year time])
        subplot(2,3,6)
            yyaxis left
            plot(x(2:xnum-1)/1000,bal_hist(i,2:xnum-1),'LineWidth',2);hold on;
            ylabel('SMB (m i.e a^{-1})')
            ylim([min(min(bal_hist)) max(max(bal_hist))])
            hold off
            %
            yyaxis right
            plot(x(2:xnum-1)/1000,-fluxdiv_plot_hist(i,2:xnum-1),'LineWidth',2);
            ylabel('- Flux divergence (m a^{-1})')
            ylim([min(min(bal_hist)) max(max(bal_hist))])
            %
            xlabel('Distance (km)');
%             title([num2str(floor(time_hist(i))) ' a'])
            set(gca,'FontSize',22);
            xlim([dx (domainsize-dx)]/1000)
        end
 %         %
        if display_end_flag==4 || display_end_flag==6
            set(gcf,'PaperPositionMode','auto')  % Need this to have correct aspect ratio in saved figure
            if time_hist(i)==0
                print(gcf,'-r80',strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_geom_year000000.png'),'-dpng');
            elseif time_hist(i)<10
                print(gcf,'-r80',strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_geom_year00000',num2str(floor(time_hist(i))),'.png'),'-dpng');
            elseif time_hist(i)<100
                print(gcf,'-r80',strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_geom_year0000',num2str(floor(time_hist(i))),'.png'),'-dpng');
            elseif time_hist(i)<1000
                print(gcf,'-r80',strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_geom_year000',num2str(floor(time_hist(i))),'.png'),'-dpng');
            elseif time_hist(i)<10000
                print(gcf,'-r80',strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_geom_year00',num2str(floor(time_hist(i))),'.png'),'-dpng');
            end
%             pause(0.4)
        end
    end
end

if display_end_flag>1
%% Evolution of variables over time

figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[0 1 40 20]);
%
yyaxis left
plot(time_hist(1:counter_diag),vol_hist(1:counter_diag),'LineWidth',2)
xlabel('Time (a)');
ylabel('Volume (km^3)');
set(gca,'FontSize',16);
%
yyaxis right
plot(time_hist(1:counter_diag),bal_mean_hist(1:counter_diag),'LineWidth',2)
ylabel('Specific SMB (m ice eq. a^{-1})');
%
grid minor;


figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[0 1 40 20]);
%
yyaxis left
plot(time_hist(1:counter_diag),df_max_hist(1:counter_diag),'LineWidth',2); hold on;
plot([start_year time],[df_lim df_lim],'LineWidth',2,'LineStyle','--')
ylim([0.9*min(df_max_hist) 1.1*max(df_max_hist)])
xlabel('Time (a)');
ylabel('Maximum diffusivity factor (m^{2} a^{-1})');
%
yyaxis right
plot(time_hist(1:counter_diag),dt_hist(1:counter_diag),'LineWidth',2); hold on;
ylim([0.9*min(dt_hist) 1.1*max(dt_hist)])
ylabel('\delta t (a)');
%
set(gca,'FontSize',16);
grid minor;

%% Final situation plots

fig1=figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[20 1 35 30]);
set(fig1,'defaultAxesColorOrder',[[0 0 0];[0 0 0]]);
yyaxis left;
%     area(x/1000,zeros(size(bed)),'FaceColor',[0 0 1]); hold on
    area(x/1000,sur,'FaceColor',[0 .8 1]); hold on;
    area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on;
    plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
    ylim([min(bed)-20 max(bed)+100])
    ylabel('Elevation (m)');
yyaxis right;
    A(1)=plot(x(first_icp:last_icp)/1000,bal(first_icp:last_icp),'LineWidth',2,'Color','g'); hold on;
    A(2)=plot(x(first_icp:last_icp)/1000,-fluxdiv_plot(first_icp:last_icp),'LineWidth',3,'LineStyle','--','Color','r'); hold on;
    plot([0 domainsize]/1000,[0 0],'LineStyle','--','Color','k'); hold on;
    ylabel('SMB / flux divergence (m a^{-1})')
    legend(A(1:2),'Surface mass balance','- Flux divergence')
xlim([dx domainsize-dx]/1000)
xlabel('Distance (km)');
set(gca,'FontSize',16);
grid minor;

fig2=figure;
if bed(1)<bed(length(bed))
    vel_plot=-vel;
else
    vel_plot=vel;
end
set(gcf,'Units','centimeters');
set(gcf,'Position',[20 1 35 30]);
set(fig2,'defaultAxesColorOrder',[[0 0 0];[1 0 0]]);
yyaxis left;
    area(x/1000,sur,'FaceColor',[0 .8 1]); hold on;
    area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on;
    plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
    ylim([min(bed)-20 max(bed)+100])
    ylabel('Elevation (m)');
yyaxis right;
    plot(x(first_icp:last_icp)/1000,vel_plot(first_icp:last_icp)); hold on;
    ylabel('Mean velocity (m a^{-1}) (vertically integrated)');
xlim([dx (domainsize-dx)]/1000)
xlabel('Distance (km)');
set(gca,'FontSize',16);
grid minor;

fig3=figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[20 1 35 30]);
set(fig3,'defaultAxesColorOrder',[[0 0 0];[1 0 0]]);
yyaxis left;
    area(x/1000,sur,'FaceColor',[0 .8 1]); hold on;
    area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on;
    plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
    ylim([min(bed)-20 max(bed)+100])
    ylabel('Elevation (m)');
yyaxis right;
    plot(x(first_icp:last_icp)/1000,df(first_icp:last_icp)); hold on;
    ylabel('Diff (m^{2} a^{-1})');
xlim([dx (domainsize-dx)]/1000)
xlabel('Distance (km)');
set(gca,'FontSize',16);
grid minor;

fig4=figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[20 1 35 30]);
set(fig4,'defaultAxesColorOrder',[[0 0 0];[1 0 0]]);
yyaxis left;
    area(x/1000,sur,'FaceColor',[0 .8 1]); hold on;
    area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on;
    plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on;
    ylim([min(bed)-20 max(bed)+100])
    ylabel('Elevation (m)');
yyaxis right;
    plot(x/1000,th.*width_mid*dx); hold on;
    plot(x/1000,obs_th.*width_mid_obs*dx,'LineStyle','--'); hold on;
    ylabel('Volume for this elevation band');
xlim([dx domainsize-dx]/1000)
xlabel('Distance (km)');
set(gca,'FontSize',16);
grid minor;
end

%% Hypsometric info
matrix=zeros([5000 1]);
matrix_obs=zeros([5000 1]);
for j=1:length(width_mid)
    bed_round100=round(bed(j)/100)*100;
    % Modelled geometry
    matrix(bed_round100)=matrix(bed_round100)+th(j)*width_mid(j)*dx;
    % Observed geometry (at inventory date)
    matrix_obs(bed_round100)=matrix_obs(bed_round100)+obs_th(1,j)*width_mid_obs(j)*dx;
end

%% Final overview plot (can be saved, isn't that amazing?)
figure;
set(gcf,'Units','centimeters');
set(gcf,'Position',[20 1 50 30]);
subplot(1,6,[1 2 3 4 5])
area(x/1000,sur,'FaceColor',[0 .8 1]); hold on;
area(x/1000,bed,min(bed)-50,'FaceColor',[.94 .94 .94]); hold on;
%
A(1)=plot(x/1000,obs_sur','LineWidth',2,'Color',[.5 .5 .5],'LineStyle','--'); hold on; % Dotted line is observed geometry at inventory date
if mb_type_flag==5 % For the 1950/1990 steady state:
    A(2)=plot([0 domainsize]/1000,[ela_observed ela_observed],'LineWidth',2,'Color',[0 1 0],'LineStyle','--'); hold on;
    A(3)=plot([0 domainsize]/1000,[ela_ss ela_ss],'LineWidth',2,'Color',[1 0 0],'LineStyle','--'); hold on;
end
ha=legend(A,...
    ['Observed glacier geometry (in ',num2str(inventory_date_id),', at inventory date)'],...
    ['Observed ELA over 1960-1990 period = ',num2str(ela_observed,4),' m (SMB = ',num2str(bal_mean_observed,2),' m ice eq. a^{-1})'],...
    ['Imposed ELA = ',num2str(ela_ss,4),' m (applied SMB bias vs. 1960-1990 = ',num2str(bias_to_be_applied,2),' m ice eq. a^{-1})']);
set(ha,'Location','NorthWest')
title(['Modelled geometry (Glacier ID = ',num2str(glacier_id,'%05d'),'; A = ',num2str(aflow),' Pa^{-3} a^{-1}; dx = ',num2str(dx),' m)'])
xlim([dx domainsize-dx]/1000)
ylim([min(bed)-20 max(bed)+100])
xlabel('Distance (km)');
ylabel('Elevation (m)');
set(gca,'FontSize',22);
grid minor;
subplot(1,6,6)
barh(1000:100:5000,matrix(1000:100:5000)/1e9,'FaceColor',[.8 .8 .8],'EdgeColor','none'); hold on
barh(1000:100:5000,matrix_obs(1000:100:5000)/1e9,'FaceColor','none','LineWidth',1.5,'LineStyle','--');
grid minor
xlabel('Volume (km^3)')
ylim([min(bed)-20 max(bed)+100])
xlim([0 max(matrix_obs/1e9)*1.5])
set(gca,'FontSize',22);

if display_end_flag==1  
    fig=gcf;fig.PaperPositionMode='auto';
    fig_pos=fig.PaperPosition;fig.PaperSize = [fig_pos(3) fig_pos(4)]; % Needed to have correct aspect in saved figure
    if mb_type_flag==5
        if calibration_method==1
            print(gcf,strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_1990_ss.pdf'),'-dpdf');
        elseif calibration_method==2
            print(gcf,strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_1950_ss.pdf'),'-dpdf');
        end
    elseif mb_type_flag==6 && floor(time)<2017
        print(gcf,strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_',num2str(inventory_date_id),'_tr.pdf'),'-dpdf');
    elseif mb_type_flag==6 && floor(time)==2017
        print(gcf,strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_2017_tr.pdf'),'-dpdf');
    elseif mb_type_flag==6 && floor(time)>=2100
        print(gcf,strcat('../output/',region,'/figures_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/',num2str(glacier_id,'%05d'),'_',num2str(floor(time)),'_tr.pdf'),'-dpdf');
    end
    close
end
