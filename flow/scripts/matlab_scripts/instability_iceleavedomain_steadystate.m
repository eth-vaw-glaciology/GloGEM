% This functions checks whether an instability occurs, whether ice is
% leaving the domain, whether a steady state is reached, or whether there
% is no ice left. If this is the case --> breakindex will be equal to 1 and
% in the 'glacier.m' the time-loop will be interupted and left

function [breakindex,vol] = instability_iceleavedomain_steadystate(glacier_id,th,smb_sinus_flag,vol_hist,counter_diag,ss_criterion,time,start_year,glacier_length,domain_exit_index,vol,obs_vol_flowlinemodel,mb_type_flag)

breakindex=0;
if isnan(mean(th))==1 || mean(th)==Inf
    disp(['Numerical instability! Glacier id = ',num2str(glacier_id)]);
    breakindex=1
    vol=nan % in case mean(th)==Inf --> give it nan value, for volume_calibration
elseif th(domain_exit_index)>0 && smb_sinus_flag==0 % Ice can leave domain for sinuosoidal: no problem
    disp(['Ice is leaving the domain! Glacier id = ',num2str(glacier_id)]);
    th(:)=NaN;
    if vol<5*obs_vol_flowlinemodel % volume is smaller than 5x observed volume (likely that no 'explosion' occured...)
        vol='out'
    else % Likely that a kind of explosion occured (i.e. numerical instability): vol = nan
        vol=nan
    end
    breakindex=1
end
%
if counter_diag>2 && mb_type_flag~=6 % Check for steady state
    if abs((vol_hist(counter_diag)-vol_hist(counter_diag-1))/vol_hist(counter_diag))<ss_criterion/100 && smb_sinus_flag==0 && time>start_year+50+sqrt(glacier_length) %volume change less than [ss criterion] %) && Not for sinusoidal modus
        disp('Steady state reached!');
        breakindex=1
    end
    if vol==0
        disp('Ice free!');
        breakindex=1
    end
end
%

end

