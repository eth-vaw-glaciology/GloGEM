% Calculate the diffusivity factor (D) that will be used to solve the
% continuity equation (will be solved as a diffusion type equation in 'ice_thickness.m')

for i=2:xnum-1
  df(i)=0.0;
  if(th(i)~=0.0) % if ice is present
    te1 = 2*aflow/(nflow+2);
    te2 = (rho*g)^(nflow);
    te3 = (th(i))^(nflow+2);
    te4 = ((sur(i+1)-sur(i-1))/(2.0*dx))^(nflow-1);
    df(i) = te1*te2*te3*te4;
  end

  if df(i)>df_lim % impose a limit on the diffusivity (is defined in 'constants_counters_initialvalues_sizevariables.m'; will likely also have to be modified for other regions than the Alps)
      df(i)=df_lim;
  end
end