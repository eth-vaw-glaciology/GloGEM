close all
clear
clc

%% Glacier
load(['../../input/centraleurope/glacier_stats.mat']); % Load indices of glacier larger than 1 km (#=791 for 'centraleurope'), larger than 1 km2 (#=403 for 'centraleurope')
% id=index_larger_than_1_km2_glaciers_save';
id=3900:3927;
id_start=0;
id_end=5000;
i=find(id<id_start);id(i)=[];
i=find(id>id_end);id(i)=[];

core_flag=1;               % X = number of cores (1 = serial computing on one core; > 1 = parallel computing)

if core_flag==1
    delete(gcp('nocreate')) % Shut down parallel pool that may still be running
elseif core_flag>1
    p=gcp('nocreate') % Get current pool (without creating a new one)
    [a b]=size(p);
    if a==0 % parallel pool does not exist
        parpool(core_flag) % create parallel pool
    else % parallel pool does exist
        if p.NumWorkers~=core_flag
            delete(gcp('nocreate')) % Shut down parallel pool
            parpool(core_flag)
        end
    end
end
parforcores=core_flag;
if parforcores==1;parforcores=0;end

parfor (i=1:length(id),parforcores)
    glacier_id=id(i);
    load_lowerpart_function(glacier_id,5,8) % function load_lowerpart_function(glacier_id,dist,min_dist_to_previous)
end









