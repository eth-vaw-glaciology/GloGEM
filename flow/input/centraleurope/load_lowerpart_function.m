function load_lowerpart_function(glacier_id,dist,min_dist_to_previous)

    %% Surface elevation (DEM)
    tic
    glacier_id
%     gridread(['dem_extended2/dem_',num2str(glacier_id,'%05d'),'.grid']);
    gridread(['dem_extended/dem_',num2str(glacier_id,'%05d'),'.grid']);
%     classic=ans;
    toc

    ncols=ans(1,1)
    nrows=ans(2,1)
    dx=ans(5,2)
    xllcorner=ans(3,2)
    yllcorner=ans(4,2)
    
    % Tranform matrix to array:
    data_array=reshape(ans(7:length(ans),:)',[],1);
    i=find(isnan(data_array)==1);data_array(i)=[];
    % From array to (correct) matrix:
    data_matrix=reshape(data_array,[ncols,nrows]);
    dem2d=data_matrix';
    i=find(dem2d<-1000);dem2d(i)=NaN; % Bugs: e.g. for glacier with id: 1559
    
    %% Glacier mask
    tic
%     if exist(['gl/gl_',num2str(glacier_id,'%05d'),'.grid'], 'file') == 2
%         import_gl(['gl/gl_',num2str(glacier_id,'%05d'),'.grid']);
%     elseif exist(['gl/gl_',num2str(glacier_id,'%05d'),'.agr'], 'file') == 2
%         import_gl(['gl/gl_',num2str(glacier_id,'%05d'),'.agr']);
    gridread(['thickness_extended/thick_',num2str(glacier_id,'%05d'),'.agr']);
    toc
    
%     ncols=ans(1,1)
%     nrows=ans(2,1)
    
    % Tranform matrix to array:
    data_array=reshape(ans(7:length(ans),:)',[],1);
    i=find(isnan(data_array)==1);data_array(i)=[];
    % From array to (correct) matrix:
    data_matrix=reshape(data_array,[ncols,nrows]);
    thick2d=data_matrix';
    
    %% Plots
    thick2d_plot=thick2d;i=find(thick2d_plot==0);thick2d_plot(i)=NaN;
    % figure;
    % pcolor(0:dx:(ncols-1)*dx,0:dx:(nrows-1)*dx,flipud(dem2d)); shading flat
    % xlabel('Distance (m)');
    % ylabel('Distance (m)');
    % title('Surface elevation (m a.s.l.)');
    % colorbar
    % grid minor
    % set(gca,'FontSize',16)
    %
    % figure;
    % pcolor(0:dx:(ncols-1)*dx,0:dx:(nrows-1)*dx,flipud(thick2d_plot)); shading flat
    % xlabel('Distance (m)');
    % ylabel('Distance (m)');
    % title('Ice thickness (m)');
    % colorbar
    % grid minor
    % set(gca,'FontSize',16)
    
    
    %% Reconstruct the bedrock for the lower parts:
    % Start by finding the position and elevation of front:
    [rows cols]=size(thick2d);
    counter=0;
    for i=1:rows
        for j=1:cols
            if thick2d(i,j)>0 % There is ice
                if thick2d(i-1,j+1)==0 || thick2d(i-1,j)==0 || thick2d(i-1,j-1)==0 || thick2d(i,j+1)==0 || thick2d(i,j-1)==0 || thick2d(i+1,j+1)==0 || thick2d(i+1,j)==0 || thick2d(i+1,j-1)==0 % must be a point at the edge of domain
                    counter=counter+1;
                    lowest_point_candidate(counter,1)=i;
                    lowest_point_candidate(counter,2)=j;
                    lowest_point_candidate(counter,3)=dem2d(i,j);
                end
            end
        end
    end
    
    [value index]=min(lowest_point_candidate(:,3));
    lowest_point(1)=lowest_point_candidate(index,1)
    lowest_point(2)=lowest_point_candidate(index,2)
    lowest_point(3)=lowest_point_candidate(index,3)
    lowest_point_save(1,1:3)=lowest_point; % Put in the lowest value in first two rows (needed for later)
    lowest_point_save(2,1:3)=lowest_point; % Put in the lowest value in first two rows (needed for later)
    
    figure;
    pcolor(thick2d_plot); shading flat; hold on
    plot(lowest_point(2)+.5,lowest_point(1)+.5,'o','MarkerFaceColor','r','MarkerEdgeColor',[1 1 1],'MarkerSize',10); hold on;
    contour(dem2d,'LineColor','k','ShowText','on');
%     caxis([min(min(thick2d_plot)) max(max(thick2d_plot))]);
    xlabel('Column');
    ylabel('Row');
%     title('Ice thickness (m)');
%     colorbar
    grid minor
    set(gca,'FontSize',16)    
    
    counter2=2
    while lowest_point(1)-dist>0 && lowest_point(1)+dist<rows && lowest_point(2)-dist>0 && lowest_point(2)+dist<cols
        counter2=counter2+1
        counter=0;
        clear lowest_point_candidate
        for i=lowest_point(1)-dist:lowest_point(1)+dist
            for j=lowest_point(2)-dist:lowest_point(2)+dist
                distance=round(sqrt((i-lowest_point(1))^2+(j-lowest_point(2))^2));
                distances_to_previous=round(sqrt((i-lowest_point_save(1:counter2-2,1)).^2+(j-lowest_point_save(1:counter2-2,2)).^2));
                if counter2==3; distances_to_previous=99999; end % For first attempt, do not have a previous guess. Circumvent
                if distance==dist && min(distances_to_previous)>min_dist_to_previous %&& thick2d(i,j)==0 % distance must be more than X compared to any previous frontal points + cannot be on part that is ice covered today
                    counter=counter+1;
                    lowest_point_candidate(counter,1)=i;
                    lowest_point_candidate(counter,2)=j;
                    lowest_point_candidate(counter,3)=dem2d(i,j);
                end
            end
        end
        
        [value index]=min(lowest_point_candidate(:,3));
        lowest_point(1)=lowest_point_candidate(index,1);
        lowest_point(2)=lowest_point_candidate(index,2);
        lowest_point(3)=lowest_point_candidate(index,3);
        lowest_point
        
        lowest_point_save(counter2,1:3)=lowest_point;
        
        plot(lowest_point(2)+.5,lowest_point(1)+.5,'o','MarkerFaceColor','r','MarkerEdgeColor',[1 1 1],'MarkerSize',10); hold on; drawnow;
        pause(.1)
    end
    save(['dem_extended/prefrontal_elev_',num2str(glacier_id,'%05d')],'lowest_point_save')
    
    fig=gcf;fig.PaperPositionMode='auto';
    fig_pos=fig.PaperPosition;fig.PaperSize = [fig_pos(3) fig_pos(4)]; % Needed to have correct aspect in saved figure
    print(gcf,strcat('dem_extended/',num2str(glacier_id,'%05d'),'_flowline_front.pdf'),'-dpdf');
    
%     close

end

