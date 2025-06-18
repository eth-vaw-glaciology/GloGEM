% ----------------------------------------------------------------------- %
% ----- GloGEMflow over European Alps (Zekollari, Huss and Farinotti)---- %
% ------------------ Volume calibration function   ---------------------- %
% ----- (called from 'main' script if opt for volume calib. only or ----- %
% from 'length_calibration' function if apply the 'volume+length' calib.) %
% ----------------------------------------------------------------------- %

function [vol]=volume_calibration(glacier_id,region,chain,poly_fit_flag,ela_change,frontal_length,dtfactor,calibration_method,aflow_guess1,inventorydate)

%% Define a few parameters (does normally not need to be modified)
if calibration_method==1     % Classic, volume+length calibration: 1990 steady state --> match inventory date length and volume
    start_year=1990;
elseif calibration_method==2 % Sensitivity experiment for paper: volume calibraion only: 1950 steady state --> match inventory date volume
    start_year=1950;
end
nyears=inventorydate-start_year;
vol_precision=0.01; % Want the volume to be matched within 1%

%% First attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias on this ('mb_bias_flag',ela_change). These runs start from an ice-free topography ('flag_startobs',0)
[vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess1,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % 1950/1990 steady state
% Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
while vol=='out' | isnan(vol)==1 % Need this 'while loop' to avoid problems when switch from 'nan' --> 'out'
    if vol=='out' % Ice is leaving the domain, re-run, with bigger larger frontal area
        while vol=='out'
            frontal_length=frontal_length+0.25
            [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess1,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
            if frontal_length>1.5 % Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
                vol=NaN;
            end
        end
    end
    if isnan(vol)==1 % Instability. Re-run, with smaller time-step
        while isnan(vol)==1 | vol=='out'
            dtfactor=dtfactor*0.5
            if dtfactor<5e-2; break; end
            [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess1,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
            if vol=='out'; vol=NaN; end % to not leave loop in the case vol is 'out'
        end
        if dtfactor<5e-2; vol=NaN; break; end
    end
end
%% First attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003). This run starts from the modelled state-state geometry ('flag_startobs',2)
[vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess1,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
if isnan(vol)==1 | vol=='out' % in case a problem occurs in the transient run (SS --> inventory date): launch one more with a smaller time step:
    dtfactor=dtfactor/2;
    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess1,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
end

if isnan(vol)==1 | vol=='out' | vol==0 % Stop calculations
    disp('First volume calibration effort was unsuccesful (instability/ice leaving the domain)...Stopped volume calibration procedure')
else % Continue!
    
    %% Write results from this first volume calibration effort down in 'rmse_vol'
    rmse_vol(1,1)=aflow_guess1;
    rmse_vol(1,2)=vol;
    rmse_vol(1,3)=vol-vol_obs;
    
    %% Estimate 'aflow' for second attempt (needed for following plot; may not be needed for calculations if modelled volume first test was within X% of observed)
    vol_multiplication=vol_obs/vol % factor by which the volume of the first test needs to be multiplied to obtain the observed volume
    aflow_guess2=aflow_guess1*(vol_multiplication)^(-4)
    
    %% Plot first attempt
    figure
    set(gcf,'Units','normalized');
    set(gcf,'position',[0.5 0.5 .4 .4])
    area([0 aflow_guess1*100],[vol_obs/1e9*(1+vol_precision) vol_obs/1e9*(1+vol_precision)],[vol_obs/1e9]*(1-vol_precision),'FaceColor',[.8 .8 1],'EdgeColor','none','FaceAlpha',.8);hold on;
    plot(rmse_vol(:,1),rmse_vol(:,2)/1e9,'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 1 1]);hold on;
    plot([0 max(aflow_guess1,aflow_guess2)],[vol_obs vol_obs]/1e9,'LineWidth',3,'LineStyle','--','Color','k'); hold on;
    xlabel('Deformation-sliding factor a (Pa^{-3} a^{-1})')
    ylabel('Volume total (km^3)')
    set(gca,'FontSize',16);
    grid minor
    xlim([0 max(aflow_guess1,aflow_guess2)])
    drawnow
    
    %% If the first attempt was not within X% of the observed volume (X=vol_precision*100) --> proceed to second attempt
    if abs((vol-vol_obs)/vol_obs)>vol_precision 
        
        %% Second attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias on this ('mb_bias_flag',ela_change). These runs start from an ice-free topography ('flag_startobs',0)
        [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess2,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % 1950/1990 steady state
        % Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
        while vol=='out' | isnan(vol)==1 % Need this 'while loop' to avoid problems when switch from 'nan' --> 'out'
            if vol=='out' % Ice is leaving the domain, re-run, with bigger larger frontal area
                while vol=='out'
                    frontal_length=frontal_length+0.25
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess2,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
                    if frontal_length>1.5 % Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
                        vol=NaN;
                    end
                end
            end
            if isnan(vol)==1 % Instability. Re-run, with smaller time-step
                while isnan(vol)==1 | vol=='out'
                    dtfactor=dtfactor*0.5
                    if dtfactor<5e-2; break; end
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess2,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
                end
                if dtfactor<5e-2; vol=NaN; break; end
            end
        end
        %% Second attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003). This run starts from the modelled state-state geometry ('flag_startobs',2)
        [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess2,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
        if isnan(vol)==1  | vol=='out' % in case a problem occurs in the transient run (SS --> inventory date): launch one more with a smaller time step:
            dtfactor=dtfactor/2;
            [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow_guess2,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
        end
        
        %% Only continue if second test resulted in a real value:
        if isnan(vol)==1 | vol=='out'
            disp('Second volume calibration effort was unsuccesful (instability/ice leaving the domain)...Stopped volume calibration procedure')
        else
            %% Write results from this second volume calibration effort down in 'rmse_vol'
            rmse_vol(2,1)=aflow_guess2;
            rmse_vol(2,2)=vol;
            rmse_vol(2,3)=vol-vol_obs;
            %% Plot second attempt:
            plot([0 aflow_guess2],[vol_obs vol_obs]/1e9,'LineWidth',3,'LineStyle','--','Color','k');
            plot(rmse_vol(:,1),rmse_vol(:,2)/1e9,'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 1 1]); hold on; drawnow
            
            %% Estimate new value for deformation-sliding factor (a) based on first two attempts:
            p = polyfit(rmse_vol(:,1),rmse_vol(:,2),1);
            p_volobs=p;
            p_volobs(length(p_volobs))=p_volobs(length(p_volobs))-vol_obs;
            r=roots(p_volobs);
            aflow=r(1)
            if aflow<0; aflow=.5*min(rmse_vol(:,1)); end
            
            if poly_fit_flag==0 % For linear fit only
                % If needed: change order, to make sure that closest value is on second row (as this will be used for the next polyfit, at end of the 'for' loop)
                if rmse_vol(1,3)<rmse_vol(2,3)
                    a=rmse_vol(1,:);
                    rmse_vol(1,:)=rmse_vol(2,:);
                    rmse_vol(2,:)=a;
                end
            end
            
            %% If the second guess was not within X% of the observed volume (X=vol_precision*100) --> proceed to additional attempts (#3 to #6)
            if abs((vol-vol_obs)/vol_obs)>vol_precision 
                for i=3:6
                    aflow
                    %% Next attempt: run the model ('glacier') into steady with mean climatic conditions ('mb_type_flag',5) + eventual bias on this ('mb_bias_flag',ela_change). These runs start from an ice-free topography ('flag_startobs',0)
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % 1950/1990 steady state
                    % Perform some checks to see if this worked, and if necessary modify 'frontal_length' and/or 'dt_factor'
                    while vol=='out' | isnan(vol)==1 % Need this 'while loop' to avoid problems when switch from 'nan' --> 'out'
                        if vol=='out' % Ice is leaving the domain, re-run, with bigger larger frontal area
                            while vol=='out'
                                frontal_length=frontal_length+0.25
                                [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
                                if frontal_length>1.5 % Most likely an intability ('explosion') occurred and it is better to switch to a 'reduction in dt' mode
                                    vol=NaN;
                                end
                            end
                        end
                        if isnan(vol)==1 % Instability. Re-run, with smaller time-step
                            while isnan(vol)==1 | vol=='out'
                                dtfactor=dtfactor*0.5
                                if dtfactor<5e-2; break; end
                                [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method);
                            end
                            if dtfactor<5e-2; vol=NaN; break; end
                        end
                    end
                    %% Next attempt: transient run ('glacier' with 'mb_type_flag',6) from SS date (1950/1990) to inventory date (typically 2003). This run starts from the modelled state-state geometry ('flag_startobs',2)
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
                    if isnan(vol)==1 | vol=='out' % in case a problem occurs in the transient run (SS --> inventory date): launch one more with a smaller time step:
                        dtfactor=dtfactor/2;
                        [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
                    end
                    
                    if isnan(vol)==0 & vol~='out' %% If a 'real' volume is obtained for 'vol' (i.e. not 'out' or 'NaN') --> continue
                        %% Write results from this volume calibration effort down in 'rmse_vol'
                        rmse_vol(i,1)=aflow;
                        rmse_vol(i,2)=vol;
                        rmse_vol(i,3)=vol-vol_obs;
                        
                        %% Plot this new attempt:
                        plot([0 max(rmse_vol(:,1))],[vol_obs vol_obs]/1e9,'LineWidth',3,'LineStyle','--','Color','k'); drawnow; hold on;
                        plot(rmse_vol(i,1),rmse_vol(i,2)/1e9,'o','MarkerSize',20,'MarkerEdgeColor','k','LineWidth',3,'MarkerFaceColor',[1 1 1]); hold on;
                        xlim([0 max(rmse_vol(:,1))]); drawnow
                        
                        %% Check whether it was a succesful attempt:
                        if abs((vol-vol_obs)/vol_obs)<vol_precision % If the guess is within X% of the observed volume (X=vol_precision*100)
                            disp(['Within less than ',num2str(vol_precision),'% of observed volume. Number of interations: ',num2str(i),', aflow = ',num2str(aflow)])
                            break
                        end
                        
                        %% Estimate new value for deformation-sliding factor (a) based on previous attempts:
                        if poly_fit_flag==0 % Linear fit (polyfit of order n=1)
                            a=find(rmse_vol(:,2)<vol_obs);
                            b=find(rmse_vol(:,2)>vol_obs);
                            if mean(a)>0 && mean(b)>0 % if there's an underestimation for the volume and an overestimation: use the closest under/overestimations for the polyfit
                                rmse_vol_under=rmse_vol;rmse_vol_under(b,:)=[];[B,I1]=sort(abs(rmse_vol_under(:,3)));
                                rmse_vol_over=rmse_vol;rmse_vol_over(a,:)=[];[B,I2]=sort(abs(rmse_vol_over(:,3)));
                                p = polyfit([rmse_vol_under(I1(1),1) rmse_vol_over(I2(1),1)],[rmse_vol_under(I1(1),2) rmse_vol_over(I2(1),2)],1);
                            else % Fit based on two previous guesses
                                p = polyfit(rmse_vol(i-1:i,1),rmse_vol(i-1:i,2),1);
                            end
                            p_volobs=p;
                            p_volobs(length(p_volobs))=p_volobs(length(p_volobs))-vol_obs;
                            r=roots(p_volobs);
                            aflow=r(1)
                        elseif poly_fit_flag==1 % Polynomial fit
                            % Best fit based on all runs
                            p = polyfit(rmse_vol(:,1),rmse_vol(:,2),i-1);
                            p_volobs=p;
                            p_volobs(length(p_volobs))=p_volobs(length(p_volobs))-vol_obs;
                            r=roots(p_volobs);
                            
                            % take aflow as the one closest to previous guess for aflow (as in some cases several values are possible)
                            r_minvol=r-aflow;
                            [dummy,index]=min(abs(r_minvol))
                            aflow=r(index);
                            
                            % in case the polynomial fit did not work (e.g. when based on first and second guess, which were equal) --> opt for a linear fit
                            if isreal(aflow)==0
                                a=find(rmse_vol(:,2)<vol_obs);
                                b=find(rmse_vol(:,2)>vol_obs);
                                if mean(a)>0 && mean(b)>0 % if there's an underestimation for the volume and an overestimation: use the closest under/overestimations for the polyfit
                                    rmse_vol_under=rmse_vol;rmse_vol_under(b,:)=[];[dummy,I1]=sort(abs(rmse_vol_under(:,3)));
                                    rmse_vol_over=rmse_vol;rmse_vol_over(a,:)=[];[dummy,I2]=sort(abs(rmse_vol_over(:,3)));
                                    p = polyfit([rmse_vol_under(I1(1),1) rmse_vol_over(I2(1),1)],[rmse_vol_under(I1(1),2) rmse_vol_over(I2(1),2)],1);
                                else % Fit based on two previous guesses
                                    p = polyfit(rmse_vol(i-1:i,1),rmse_vol(i-1:i,2),1);
                                end
                                p_volobs=p;
                                p_volobs(length(p_volobs))=p_volobs(length(p_volobs))-vol_obs;
                                r=roots(p_volobs);
                                aflow=r(1)
                            end
                        end
                        
                        if aflow<0; aflow=.5*min(rmse_vol(:,1)); end
                    else
                        break
                    end
                end
                if abs((vol-vol_obs)/vol_obs)>vol_precision % Did not succeed to get within X% of observed volume after 6 attempts --> take one that is closest
                    [value,index]=min(abs(rmse_vol(:,3)))
                    aflow=rmse_vol(index,1)
                    
                    % re-run for the attempt that was the closest (as this may not have been the last one, and results need to be written down again)
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',ela_change,'mb_type_flag',5,'flag_startobs',0,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % 1950/1990 steady state
                    [vol_obs,vol]=glacier(glacier_id,region,chain,'aflow',aflow,'mb_bias_flag',0,'mb_type_flag',6,'flag_startobs',2,'nyears',nyears,'start_year',start_year,'frontal_length',frontal_length,'dtfactor',dtfactor,'calibration_method',calibration_method); % Transient: 1950/1990 --> inventory date
                end
            end
        end
    else
        disp('Volume was within X% at first attempt! Succesful volume calibration')
    end
end
close % close the 'aflow vs. volume' figure (i.e. the 'volume calibration' figure and not the 'length calibration' figure)

end



