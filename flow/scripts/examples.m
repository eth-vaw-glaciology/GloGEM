% Some examples to get to know the model:
 
close all
clear
clc

% Run the evolution of glacier 1450 (Grosser Aletsch) for model chain01
% from the EURO-CORDEX ensemble. For various parameters the standard values
% are taken: e.g.  aflow = 1e-16; start from observed geometry
% ('flag_startobs' = 1); a constant 1961-1990 climate is applied
% ('mb_type_flag',5); the time steps is adapted automatically ('dt_flag',0)
% the simulations runs until a steady state is obtained (or stops after
% 5000 years if this is not the case) (steady state when volume change is
% smaller than 0.01%
glacier(1450,'centraleurope',1)
% --> Steady state reached after 206 years

%%
glacier(1450,'centraleurope',1,'flag_startobs',0) % same experiment, but starting from zero ice thickness
% Takes 427 years before steady state is reachted. But faster in the
% beginning, because time step is large (little ice, so limited flow --> can have a large timestep)

%%
% Same, but with some figures and/or animations being generated:
glacier(1450,'centraleurope',1,'display_during_flag',1) % normally not used, but these figures may be useful for debugging
%%
glacier(1450,'centraleurope',1,'display_end_flag',3) % Time lapse movie with only geometry
%%
glacier(1450,'centraleurope',1,'display_end_flag',5) % Full time lapse movie

%%
glacier(1946,'centraleurope',1,'display_end_flag',3) % For another glacier: Gorner

%%
glacier(1946,'centraleurope',1,'display_end_flag',3,'mb_bias_flag',-100) % Same, but with the ELA being 100 m lower
% --> faster to reach steady state, and will have a longer steady state
% glacier because of the lowering of the ELA

%%
glacier(1946,'centraleurope',1,'display_end_flag',3,'smb_sinus_flag',50,'nyears',200) % SMB sinusoidal forcing with a frequency of 50 years (amplitude is 0.75 m i.e. a^-1 --> can be modified in massbal.m)
% --> faster to reach steady state, and will have a longer steady state
% glacier because of the lowering of the ELA



