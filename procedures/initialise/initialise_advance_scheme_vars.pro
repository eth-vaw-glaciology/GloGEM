; *****************************************
; *  Initialise advance scheme variables  *
; *****************************************
; This procedure defines the variables needed for the advance scheme, which are used to determine the initial areas 
; in front of the glacier and the amplification of these areas. It also defines some more variables related to the 
; initial conditions of the glacier.

compile_opt idl2

jj=where(area_ini ne 0,cj)
tt=max([0,fix(cj*adv_terminusfraction)-1]) ; determine indices for terminus region
; define amplification of 'hypothetical' initial areas in front of glacier
adv_iniamplification=dblarr(nb)+1
for i=jj[0]-1,0,-1 do adv_iniamplification[i]=1+((jj[0]-i)/(adv_addband/2.))^3.
; define some more variables
adv_iniar=mean(area_ini[jj[0:tt]]) & adv_inithi=mean(thick_ini[jj[0:tt]])
if cj ne nb then width[where(width eq 0)]=mean(width[jj[0:tt]])
dl=(length[jj[0]]-length[jj[tt]])/(tt+1)
for i=jj[0]-1,0,-1 do length[i]=length[i+1]+dl
