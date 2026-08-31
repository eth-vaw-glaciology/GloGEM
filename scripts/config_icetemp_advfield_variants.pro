; GloGEM config — Aletsch/Morteratsch englacial-temperature variant matrix.
;
; One config for the whole experiment; the variant is chosen by environment variables so
; there is no family of near-identical files to keep in sync:
;
;   GLOGEM_ADV     'y' | 'n'   enable_advection        (default 'y')
;   GLOGEM_SPINUP  'y' | 'n'   firnice_thermal_spinup  (default 'n')
;   GLOGEM_STRAIN  'y' | 'n'   enable_strain_heating   (default 'n')
;   GLOGEM_TAG     subdirectory under the run root     (default 'adv')
;   GLOGEM_CATCH   catchment name                      (default 'Aletsch_Morteratsch')
;                  'Aletsch_Gorner' pairs Great Aletsch (02596) with Gornergletscher
;                  (01225, 2174-4536 m, 21 glenglat boreholes at 3810-4480 m) so the
;                  cold high-altitude firn area has observations to be checked against.
;
; Purpose: test whether the cold bias seen in the baseline run is the analytical initial
; condition rather than the physics. Baseline diagnosis: outside the firn area the modelled
; column never leaves its start value (mean annual air temperature) in the 15 years the run
; has, because meltwater refreezing is capped at the firn/ice transition and strain heating
; is off. See scripts/run_icetemp_advfield_variants.sh.
;
; Launched via GLOGEM_CONFIG, so config.pro is never touched.

dirres     = '/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/' + $
             'icetemp_advfield_aletsch_morteratsch/' + $
             (getenv('GLOGEM_TAG') ne '' ? getenv('GLOGEM_TAG') : 'adv') + '/'
RGIversion = '7'

time_resolution     = 'monthly'
region_id_loop      = [14, 14]
catchment_selection = (getenv('GLOGEM_CATCH') ne '' ? getenv('GLOGEM_CATCH') : 'Aletsch_Morteratsch')

tran            = [1940, 2100]
calibrate       = 'n'
read_parameters = 'y'

MIP           = 'CMIP6'
GCM_model_idx = [1]   ; BCC-CSM2-MR
GCM_rcp_idx   = [1]   ; ssp126

refreezing_parametrised = 'y'
frontal_ablation        = 'n'

use_flow_model        = 'y'
write_geometry_output = 'y'

firnice_temperature     = 'y'
firnice_write           = ['y', 'y', 'y']
firnice_batch           = 'n'
firnice_temp_calib      = 'n'
firnice_glenglat_lookup = '/home/jabeer/projects/glogemflow_development/GloGEM/test/data/glenglat_borehole_elevations_CentralEurope.dat'

enable_advection       = (getenv('GLOGEM_ADV')    ne '' ? getenv('GLOGEM_ADV')    : 'y')
advection_write        = enable_advection
firnice_thermal_spinup = (getenv('GLOGEM_SPINUP') ne '' ? getenv('GLOGEM_SPINUP') : 'n')
enable_strain_heating  = (getenv('GLOGEM_STRAIN') ne '' ? getenv('GLOGEM_STRAIN') : 'n')

; Percolation knobs, for testing why the high-altitude firn comes out temperate.
;   GLOGEM_PERMFRAC  scales the Herron-Langway firn/ice transition depth that meltwater
;                    is allowed to reach. settings.pro defaults to 1.0 (full depth); the
;                    Tier-3 grid search pinned 12 of 24 glaciers on its lowest sampled
;                    value, 0.2, i.e. it wanted far less percolation than 1.0 allows.
;   GLOGEM_PERM      'n' switches infiltration off entirely (fit_water = 0), the cold end
;                    member.
firnice_perm_frac = (getenv('GLOGEM_PERMFRAC') ne '' ? double(getenv('GLOGEM_PERMFRAC')) : 1.0d)
firn_permeability = (getenv('GLOGEM_PERM') ne '' ? getenv('GLOGEM_PERM') : 'y')

; GLOGEM_DTSCALE multiplies the decision-tree firn-insulation offset that builds the
; analytical starting profile. 0 removes it entirely, 3 triples it. With the thermal
; spin-up on, a converged run should be insensitive to it -- that is the test of whether
; the spin-up really does forget its initial condition.
firnice_dT_scale = (getenv('GLOGEM_DTSCALE') ne '' ? double(getenv('GLOGEM_DTSCALE')) : 1.0d)
