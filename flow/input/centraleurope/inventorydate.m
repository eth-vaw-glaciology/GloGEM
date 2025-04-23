close all
clear
clc

data=import_rgi_data('rgi/11_rgi60_CentralEurope.csv')
i=find(data==-9999999);data(i)=NaN;

date=zeros([length(data) 1]);

for i=1:length(data)
    date_start=data(i,3);
    date_end=data(i,4);
    date(i)=nanmean([date_start date_end]);
    if isnan(date(i))==1 % If unknown: take the inventory date from previous glacier
        date(i)=date(i-1);
    end
end

inventory_date=round(date/10000)

save('inventory_date.mat','inventory_date')

