% Calculate and save a few values. Not at every time step, this is
% performed at every 'dtdiag' time steps (typically once a year)

counter_diag=counter_diag+1;
disp(['Time = ',num2str(floor(time)),' (exact time is ',num2str(time),')']) % When this is not printed on screen: slightly faster (ca. 5-10%): so could potentially comment this out

%% Calculate a few things:

% Length:
    for i=xnum-2:-1:1 % Glacier length: start from top --> go down
        if th(i)==0
            glacier_length=((xnum-1-i)+1)*dx;
            break
        end
    end

% Area:
    glacier_area=0;
    for i=1:xnum
        if th(i)>0
            glacier_area=glacier_area+dx*width_surface(i);
        end
    end

% Volume:
    vol=0;
    for i=1:xnum
        if width_flag==0
            vol=vol+dx*th(i)*700; % in m^3 (need to assume the width)
        elseif width_flag==1 || width_flag==2 || width_flag==3
            vol=vol+dx*th(i)*width_mid(i); % in m^3
        end
    end
    
% SMB:
    sum_smb=0;
    counter=0;
    %
    if width_flag==0 % Same width over entire glacier
        width_surface=ones(length(sur));
        width_mid=ones(length(sur));
    end
    for i=2:xnum-1
        if th(i)>0
            counter=counter+width_surface(i);
            sum_smb=sum_smb+bal(i)*width_surface(i);
        end
    end

% Max diffusivity
if df(i)>df_max
    df_max=df(i);
end
    
% Flux divergence plot: how to plot the flux divergence (--> will be used in 'plot_final.m')
    for i=1:xnum-1
        fluxdiv_plot(i)=(term1(i)+term2(i))/width_surface(i); % cf. see continuity equation
    end
    fluxdiv_plot2=fluxdiv_plot;
    for i=3:xnum-1 % Do not show where it nears zero: visually nicer
        if fluxdiv_plot(i)==0 || fluxdiv_plot(i-1)==0 || fluxdiv_plot(i-2)==0
            fluxdiv_plot2(i)=NaN;
        end
    end

% Velocity (average: vertically integrated)
    for i=2:xnum-1
        if th(i)>0
            vel(i)=-df(i)*grad(i)/th(i);
        end
    end

% Update the first and last ice covered point (icp) (needed for plotting in 'plot_final.m')
    for i=1:xnum
        if th(i)>0
            first_icp=i;
            break
        end
    end
    for i=xnum:-1:1
        if th(i)>0
            last_icp=i;
            break
        end
    end
    if sum(th)>0 % Need at least one ice covered point
        if first_icp<first_icp_min; first_icp_min=first_icp; end
        if last_icp>last_icp_max; last_icp_max=last_icp; end
    end

%% Fill the '*_hist' files:
area_hist(counter_diag)=glacier_area;
aflow_hist(counter_diag) = aflow;
bal_hist(counter_diag,1:xnum)=bal(1:xnum);
bal_mean_hist(counter_diag)=sum_smb/counter;
df_max_hist(counter_diag)=max(df);
dt_hist(counter_diag) = dt;
fluxdiv_plot_hist(counter_diag,1:xnum-1)=fluxdiv_plot2(1:xnum-1);
time_hist(counter_diag) = time;
length_hist(counter_diag)=glacier_length;
th_hist(counter_diag,1:xnum)=th(1:xnum);
vol_hist(counter_diag) = vol/1e9;  % /1e9: from m^3 to km^3