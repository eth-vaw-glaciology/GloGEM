; *************************************************************

compile_opt idl2

gcmmodel = GCM_model[gcms]
rcpmodel =  GCM_rcp[rcps]

; Normal runs                                                                                                                                                                                                                                      
if GMIP4 eq 'y' then begin
    if rcpmodel eq 'ssp126' or rcpmodel eq 'ssp585' then begin
        if gcmmodel eq 'ACCESS-ESM1-5' or gcmmodel eq 'IPSL-CM6A-LR' or gcmmodel eq 'MRI-ESM2-0' then tran[1]=2300
        if gcmmodel eq 'CESM2-WACCM' then tran[1]=2299
    endif else begin
        tran[1]=2100
    endelse
endif

; Overshoot                                                                                                                                                                                                                                        
if GMIP4 eq 'y' then begin  
    if rcpmodel eq 'ssp534-over'then begin                                                                                                                                                                                                                 
        if gcmmodel eq 'CESM2-WACCM' then tran[1]=2299                                                                                                                                                                                                                 
        if gcmmodel eq 'IPSL-CM6A-LR' or gcmmodel eq 'MRI-ESM2-0' then tran[1]=2300                                                                                                                                                                                                  
        if gcmmodel eq 'MIROC6' then tran[1]=2100                                                                                                                                                                                                        
    endif 
endif