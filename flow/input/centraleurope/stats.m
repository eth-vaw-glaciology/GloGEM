close all
clear
clc

tic

data_glaciers=zeros([3927 3]);

data_rgi=import_rgi_data('rgi/11_rgi60_CentralEurope.csv');
load('inventory_date.mat')

for glacier_id=1:3927 % Range over which geometry files exist
    glacier_id
    glacier_geom=import_glacier_geometry_1d(['flowline_geom/',num2str(glacier_id,'%05d'),'.dat']);
    [length_array b]=size(glacier_geom);
    data_glaciers(glacier_id,1)=glacier_geom(length_array,7)/1000; % Glacier length (km)
    data_glaciers(glacier_id,2)=sum(glacier_geom(:,4)); % Glacier area (km^2)
    vol=0;
    for i=1:length_array
        vol=vol+glacier_geom(i,4)*glacier_geom(i,5)/1000; % area*thick
    end
    data_glaciers(glacier_id,3)=vol; % Glacier volume (km^3)
end

%%
figure;
plot(data_glaciers(:,1),'o')
xlabel('Glacier ID')
ylabel('Length (km)')
set(gca,'FontSize',18);
grid minor

figure;
plot(data_glaciers(:,2),'o')
xlabel('Glacier ID')
ylabel('Area (km^2)')
set(gca,'FontSize',18);
grid minor

figure;
plot(data_glaciers(:,3),'o')
xlabel('Glacier ID')
ylabel('Volume (km^3)')
set(gca,'FontSize',18);
grid minor

%% Subdivide in category:
index_larger_than_1_km_glaciers=find(data_glaciers(:,1)>1);
index_larger_than_1_km2_glaciers=find(data_glaciers(:,2)>1);
index_larger_than_1_km3_glaciers=find(data_glaciers(:,3)>1);
index_smaller_than_1_km_glaciers=find(data_glaciers(:,1)<1);
index_2003inventorydate_glaciers=find(inventory_date==2003);

%% Calculate some areas and volume
area_total=sum(data_glaciers(:,2))
area_larger_than_1_km_glaciers=sum(data_glaciers(index_larger_than_1_km_glaciers,2))
area_larger_than_1_km2_glaciers=sum(data_glaciers(index_larger_than_1_km2_glaciers,2))
area_larger_than_1_km3_glaciers=sum(data_glaciers(index_larger_than_1_km3_glaciers,2))
area_2003inventorydate_glacier=sum(data_glaciers(index_2003inventorydate_glaciers,2))

vol_total=sum(data_glaciers(:,3))
vol_larger_than_1_km_glaciers=sum(data_glaciers(index_larger_than_1_km_glaciers,3))
vol_larger_than_1_km2_glaciers=sum(data_glaciers(index_larger_than_1_km2_glaciers,3))
vol_larger_than_1_km3_glaciers=sum(data_glaciers(index_larger_than_1_km3_glaciers,3))
vol_2003inventorydate_glacier=sum(data_glaciers(index_2003inventorydate_glaciers,3))

%% Before saving: check if corresponding SMB file ('belev_..') exists
index_larger_than_1_km_glaciers_save=index_larger_than_1_km_glaciers;
index_larger_than_1_km2_glaciers_save=index_larger_than_1_km2_glaciers;
index_larger_than_1_km3_glaciers_save=index_larger_than_1_km3_glaciers;
index_smaller_than_1_km_glaciers_save=index_smaller_than_1_km_glaciers;

counter=0;
for i=1:length(index_larger_than_1_km_glaciers_save)
    z=find(index_larger_than_1_km2_glaciers_save==index_larger_than_1_km_glaciers_save(i));
    if length(z)==0
        counter=counter+1;
        index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save(counter)=index_larger_than_1_km_glaciers_save(i);
    end
end

%% Save variables
save('glacier_stats','index_larger_than_1_km_glaciers_save','index_larger_than_1_km2_glaciers_save','index_larger_than_1_km3_glaciers_save','index_smaller_than_1_km_glaciers_save','index_smaller_than_1_km2_glaciers_but_longer_than_1_km_save')

toc



