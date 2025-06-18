% ----------------------------------------------------------------------- %
% ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)---- %
% ------ Length calibration function (called from 'main' script)  ------- %
% ----------------------------------------------------------------------- %

function length_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate)

%% First length calibration effort
% Start with a volume calibration:
[vol]=volume_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate)
% Load the results from this volume calibration:
load(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_',num2str(inventorydate),'_tr.mat'],'glacier_length','length_fixeddistance','aflow'); % load observed length ('length_fixeddistance'), modelled one ('glacier_length') and deformation-sliding factor ('aflow')
% Check length:
length_ratio=glacier_length/length_fixeddistance % Ratio between Modelled ('glacier_length') and observed length ('length_fixeddistance')

%% Write results from this first length calibration effort down in 'rmse_length'
rmse_length(1,1)=ela_change;
rmse_length(1,2)=glacier_length;
rmse_length(1,3)=aflow;
rmse_length(1,4)=abs(length_ratio-1)*100; % how many percent off the observed length

%% Plot first length calibration effort
figure
set(gcf,'Units','normalized');
set(gcf,'position',[0.5 0 .4 .4])
area([-5000 5000],[length_fixeddistance*1.01 length_fixeddistance*1.01],length_fixeddistance*0.99,'FaceColor',[.8 .8 1],'EdgeColor','none','FaceAlpha',.8);hold on; % Plot shaded area: where we want to end (i.e. calibration should bring us in this range)
plot(rmse_length(:,1),rmse_length(:,2),'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 0 0]);hold on;
plot([ela_change-50 ela_change+50],[length_fixeddistance length_fixeddistance],'LineWidth',3,'LineStyle','--','Color','k'); hold on;
xlabel('ELA change vs. 1960-1990 (m)')
ylabel('Glacier length (m)')
set(gca,'FontSize',16);
xlim([ela_change-50 ela_change+50])
grid minor
drawnow

%% Perform checks and potentially proceed to second (and eventually third/fourth/...) length calibration effort
if length_ratio>0.99 && length_ratio<1.01 % Length fit was immediately OK: do not need additional tests
    disp('Correct length reached at first attempt...Succesful length calibration procedure')
elseif isnan(vol)==1 | vol==0
    disp('Instability at first length calibration attempt...Stopped length calibration procedure')
elseif  vol=='out'
    disp('Ice leaving the domain at first length calibration attempt...Stopped length calibration procedure')
else %% Proceed to second attempt:
    if length_ratio<1 % Glacier at first attempt was too small --> should drop ELA. Deformation-sliding factor should (slightly) increase
        aflow_guess1=aflow+0.2e-16;
        ela_change=ela_change-10;
    elseif length_ratio>1 % Glacier at first attempt was too large --> should increase ELA. Deformation-sliding factor should (slightly) decrease
        aflow_guess1=aflow-0.2e-16; if aflow_guess1<0; aflow_guess1=1e-17; end
        ela_change=ela_change+10;
    end
    % Volume calibration:
    [vol]=volume_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate) % run 'classic' volume calibration
    % Load the results from this volume calibration
    load(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_',num2str(inventorydate),'_tr.mat'],'glacier_length','length_fixeddistance','aflow'); % load observed length, modelled one and deformation-sliding factor
    % Check length:
    length_ratio=glacier_length/length_fixeddistance
    %% Write results from this second length calibration effort down in 'rmse_length'
    rmse_length(2,1)=ela_change;
    rmse_length(2,2)=glacier_length;
    rmse_length(2,3)=aflow;
    rmse_length(2,4)=abs(length_ratio-1)*100; % how many percent off the observed length
    %% Plot second length calibration effort
    plot([ela_change-10 ela_change+10],[length_fixeddistance length_fixeddistance],'LineWidth',3,'LineStyle','--','Color','k'); hold on;
    plot(rmse_length(:,1),rmse_length(:,2),'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 0 0]);hold on; drawnow
    
    %% Perform checks and potentially proceed to third (and eventually fourth/fifth/...) length calibration effort
    if length_ratio>0.99 && length_ratio<1.01 %% Length fit was OK at second attempt
        disp('Correct length reached at second attempt...Succesful length calibration procedure')
    elseif isnan(vol)==1 | vol==0
        disp('Instability at second length calibration attempt...Stopped length calibration procedure')
    elseif  vol=='out'
        disp('Ice leaving the domain at second length calibration attempt...Stopped length calibration procedure')
    else % Use information from previous attempts to find the 'ela_change' that provides correct length change: can have a total of 6 attempt (including the two ones already conducted at this point)
        points=2; % Number of previous attempts / number of points/bullets that were drawn on the figure
        while (length_ratio<0.99 || length_ratio>1.01) && points<=6 % Do not continue if length is within 1% or if this is the 7th attempt
            %% Next guess for 'ela_change' is based on polynomial fit through all previous attempts
            p = polyfit(rmse_length(:,1),rmse_length(:,2),points-1);
            p_lengthobs=p;
            p_lengthobs(length(p_lengthobs))=p_lengthobs(length(p_lengthobs))-length_fixeddistance;
            r=roots(p_lengthobs);
            % take ela_change as the one closest to the previously guessed 'ela_change' (in some cases several values are possible)
            r_minlength=r-ela_change;
            [dummy,index]=min(abs(r_minlength));
            ela_change=r(index);
            
            % in case the polynomial fit did not work (e.g. when based on first and second guess, which were equal) --> opt for a linear fit
            if isreal(ela_change)==0 % Re-do, with linear approach between two points
                a=find(rmse_length(:,2)<length_fixeddistance);
                b=find(rmse_length(:,2)>length_fixeddistance);
                if mean(a)>0 && mean(b)>0 % if there's an underestimation and overestimation for the length: linear fit (=polyfit from order 1) uses the closest under/overestimations
                    rmse_length_under=rmse_length;rmse_length_under(b,:)=[];[dummy,I1]=sort(abs(rmse_length_under(:,3)));
                    rmse_length_over=rmse_length;rmse_length_over(a,:)=[];[dummy,I2]=sort(abs(rmse_length_over(:,3)));
                    p = polyfit([rmse_length_under(I1(1),1) rmse_length_over(I2(1),1)],[rmse_length_under(I1(1),2) rmse_length_over(I2(1),2)],1);
                else % if there's no underestimation and overestimation for the length: linear fit (=polyfit from order 1) uses the two previous guesses
                    p = polyfit(rmse_length(points-1:points,1),rmse_length(points-1:points,2),1);
                end
                p_lengthobs=p;
                p_lengthobs(length(p_lengthobs))=p_lengthobs(length(p_lengthobs))-length_fixeddistance;
                r=roots(p_lengthobs);
                ela_change=r(1)
            end
            
            %% Check whether something went wrong
            if ela_change<-500 || ela_change>500 % Something went wrong
                disp('ELA change is unrealistic...Stopped length calibration procedure')
                vol='ela_problem';
                if calibration_method==1
                    save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1990_ss.mat'],'vol'); % save 'vol'
                elseif calibration_method==2
                    save(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_1950_ss.mat'],'vol'); % save 'vol'
                end
                break
            end
            
            %% Before we can proceed to volume calibration: also need to estimate the deformation-sliding factor (aflow): will also use information from previous calibration efforts for this:
            [dummy,index]=sort(rmse_length(:,1));
            clear z; z=find(rmse_length(end,1)==rmse_length(1:end-1,1)); if length(z)>0;rmse_length(end,1)=rmse_length(end,1)*1.001;end % trick to very slightly modify the ela change to avoid problem for interpolation with two same values (minimal effect on next guess for 'aflow')
            aflow_interp=interp1(rmse_length(index,1),rmse_length(index,3),ela_change,'linear','extrap');
            if aflow_interp<0; aflow_interp=.5e-16; end
            aflow_guess1=aflow_interp;
            
            %% New volume calibration effort:
            [vol]=volume_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate) % run volume calibration
            points=points+1;
            if isnan(vol) | vol==0; break; end
            if vol=='out'; break; end
            %% Load the results from this volume calibration
            load(['../output/',region,'/data_rcm/chain',num2str(chain,'%02d'),'/calibration',num2str(calibration_method),'/variables_',num2str(glacier_id,'%05d'),'_',num2str(inventorydate),'_tr.mat'],'glacier_length','length_fixeddistance','aflow'); % load observed length, modelled one and deformation-sliding factor
            % Check length:
            length_ratio=glacier_length/length_fixeddistance
            %% Write results from this length calibration effort down in 'rmse_length'
            rmse_length(points,1)=ela_change;
            rmse_length(points,2)=glacier_length;
            rmse_length(points,3)=aflow;
            rmse_length(points,4)=abs(length_ratio-1)*100; % how many percent off the observed length
            
            %% Plot new length calibration effort:
            plot(rmse_length(:,1),rmse_length(:,2),'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 0 0]); hold on; drawnow
        end
        
        %% If reach this point in the code: 6 attempts were performed and did not succeed in getting within 1% of the observed length --> take the attempt that is the closest
        if length_ratio<0.99 || length_ratio>1.01 
            [value,index]=min(rmse_length(:,4))
            ela_change=rmse_length(index,1)
            aflow_guess1=rmse_length(index,3)
            % re-run for the attempt that was the closest (as this may not have been the last one, and results need to be written down again)
            [vol]=volume_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate) % run volume calibration
        end
    end
    
    
end

    close % close the 'ela_change vs. length' figure (i.e. the 'length calibration' figure and not the 'volume calibration' figure) 
end

