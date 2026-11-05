; *************************************************************
; flow_mb_surface
;
; Elevation at which the flow model reads GloGEM's band balance for each
; flowline cell (flow_mb_elev_cap):
;   'all'  the actual surface, at most the inventory-date surface (as MATLAB
;          massbal.m); in front of the inventory glacier that is the bed
;   'ice'  capped only where the inventory had ice
;   'none' the actual surface (as IGM reads its forcing)
; *************************************************************

function flow_mb_surface, sur, obs_sur, obs_ice, mode
  compile_opt idl2
  case mode of
    'all': return, sur < obs_sur
    'ice': begin
      z = sur
      ii = where(obs_ice ne 0, ci)
      if ci gt 0 then z[ii] = sur[ii] < obs_sur[ii]
      return, z
    end
    'none': return, sur
  endcase
end
