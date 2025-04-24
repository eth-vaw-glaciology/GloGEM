% Calculate the ice thickness at the next time step through the continuity
% equation. Notice that the diffusivity factor was calculated earlier.
% Evolution towards geometry at next time step occurs in 3 steps 
% (updating the geometry and recalculating the flux divergence and 
% surface gradient at each of these 'sub-steps')

for j=1:3 % 3 sub-steps used. Worked well. Maybe not really needed or better solutions --> will have to be tested for other regions in the world 
    
    %% Define unstaggered grid for flux (fun)
    fun = zeros(xnum,1); % Flux on unstaggered grid
    for i=3:xnum
        fun(i)=((df(i-1)+df(i))/2.0)*((sur(i)-sur(i-1))/dx);
    end
    
    %% Calculate new ice thickness
    for i=2:xnum-1
        fluxdiv(i) = ((fun(i+1)-fun(i))/dx);
        grad(i)=((sur(i+1)-sur(i-1))/(2*dx)); % surface gradient
        term1(i)=fluxdiv(i)*width_mid(i);
        term2(i)=((width_mid(i+1)-width_mid(i-1))/(2*dx))*grad(i)*df(i);
        term3(i)=(term1(i)+term2(i))/width_surface(i);
        if isnan(term3(i))==1;term3(i)=0;end; % to avoid problems when width_surface == 0
        th(i)=th(i)+(1/3)*dt*(term3(i)+bal(i));
    end
    i=find(th<0);th(i)=0; % Faster than using 'if' statement in loop
    th(xnum)=th(xnum-1); % Thickness at last grid cell equals the thickness at penultimate grid cell
   
    variables_renew; % script to renew various variables at these sub time-steps (surface elevation, width_mid and width_surface)
end