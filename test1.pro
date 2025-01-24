; This is a test procedure to check if the GloGEM model runs correctly
;
;
; This testcase is for a single glacier run
;
;
; Setting input settings
; # Select Aletsch glacier - RGI-ID = '01450'
; # Calibrate the model - calibrate = "y"
;
; # afterwards turn off calibrating mode and run for one GCM
;
; --------------------------------------------------
; two calibration output files are created - change this!

RGIversion='6'

time_resolution='daily'
;
;single_glacier = '01450'
;calibrate = 'y'
;meltmodel = '1' ; Select melt model to be used
; 1: Classic degree-day model
; 3: Simple energy-balance model (Oerlemans,2001)

;find_startyear = 'y'

;.r glogem.pro
;
; check output values
;
; Reference dataset
ID = [1450]
Ba = [-1.154]
Bw = [0.790]
Area = [82.165]
ELA = [3101]
AAR = [53.9]
dBdz = [0.960]
Bt = [-14.340]
DDFsnow = [3.952]
DDFice = [7.904]
Cprec = [0.800]
T_off = [0.00]

; read in simulated values:

; define output folder location
output_f = '/scratch_net/vierzack05/mvantiel/GloGEM_output/r' + RGIversion + '_' + time_resolution + '/CentralEurope/calibration/'

; Define the file name
file_name = output_f + 'calibrate_m1_cID9_centraleurope_final_ERA5-land_daily.dat'

; Open the file for reading
openr, unit, file_name, /get_lun

; Skip the header line (if present)
readf, unit, header

; Read the actual data (assuming one row of data)
sim_data = fltarr(11) ; 11 columns of data
readf, unit, sim_data

; Close the file
free_lun, unit

; Map the data to uniquely named variables
sim_ID = fix(sim_data[0]) ; Convert ID to integer
sim_Ba = sim_data[1]
sim_Bw = sim_data[2]
sim_Area = sim_data[3]
sim_ELA = sim_data[4]
sim_AAR = sim_data[5]
sim_dBdz = sim_data[6]
sim_Bt = sim_data[7]
sim_DDFsnow = sim_data[8]
sim_DDFice = sim_data[9]
sim_Cprec = sim_data[10]
sim_T_off = sim_data[11]

; Create an array of variable names for comparison
variable_names = ['Ba', 'Bw', 'Area', 'ELA', 'AAR', 'dBdz', 'Bt', 'DDFsnow', 'DDFice', 'Cprec', 'T_off']

; Loop over the variable names and compare values
for i = 0, n_elements(variable_names) - 1 do begin
  var_name = variable_names[i]

  ; Get the reference and simulated values dynamically using the variable names
  ref_value = var_name
  sim_value = 'sim_' + var_name

  ; Use the VALUE function to retrieve the variable values dynamically
  ref_val = VALUE(ref_value)
  sim_val = VALUE(sim_value)

  ; Compare the values
  if ref_val eq sim_val then begin
    print, var_name + ' matches: ', ref_val
  endif else begin
    print, var_name + ' is different.'
    print, 'Reference value: ', ref_val
    print, 'Simulated value: ', sim_val
  endelse
endfor

end
