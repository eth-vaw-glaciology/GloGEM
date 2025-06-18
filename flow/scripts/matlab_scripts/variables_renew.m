% Renew the variables while the solving of the continuity equation (which
% is performed in three intermediate steps)

sur(2:xnum)=bed(2:xnum)+th(2:xnum);
width_surface=width_base(:)+lambda(:).*th(:);
width_mid=(width_base(:)+width_surface(:))/2;