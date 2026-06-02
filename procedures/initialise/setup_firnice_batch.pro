; ***************************************
; Setup firnice batch loop parameters 
; ***************************************

compile_opt idl2

; make sure that other settings are fine
; DEACTIVE write_file='n' in potential FULL runs
write_file='n' & calibrate='n'
single_glacier=firnice_batch_data2[0,ffbl] ; define indivudal glacier to be run
firnice_profile_ID=firnice_batch_data2[1,ffbl]   ; define temperature profile ID
ii=where(firnice_batch_data1[1,ffbl] eq region_loop_data[1,*],ci)         ; RGI region
region_id_loop=[double(region_loop_data[0,ii[0]]),double(region_loop_data[0,ii[ci-1]])]   ; define RGI region
firnice_profile=[firnice_batch_data1[0,ffbl]]                                             ; define elevation
firnice_maxdepth=[firnice_batch_data1[2,ffbl]]