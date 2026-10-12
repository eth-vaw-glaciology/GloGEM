# Flowline Model (GloGEMflow)

GloGEMflow replaces the [Δh parameterisation](retreat-model.md) with an ice-flow model along one flowline per glacier, for every glacier it can represent. It is an IDL port of the MATLAB GloGEMflow model of Zekollari et al. (2019), coupled to GloGEM's own mass balance. It is switched on with `use_flow_model = 'y'`; the code is in `procedures/flow/`, driven by `glogemflow_coupled.pro`.

The Δh parameterisation stays in the model: glaciers the flow model cannot use run on it, in the same run (see {ref}`flow-fallback`).

---

## Coupling to GloGEM

GloGEM still computes the surface mass balance of every glacier on its elevation bands, with the calibrated parameters. The flow model only changes how the geometry evolves:

```
every year, for a glacier on the flow model
  GloGEM mass balance on the elevation bands (calibrated)
        |  interpolated to each flowline cell at its current surface elevation
        v
  flowline balance (m ice/yr)
        |  shallow-ice flow, adaptive sub-steps over the year
        v
  new ice thickness along the flowline
        |  elevation bands rebuilt from the flowline (update_elevation_bands.pro)
        v
  band elevations of next year's mass balance; volume, area, balance and flux
  components reported from the flowline (report_flowline_budget.pro)
```

- **Flowline grid.** `vertical_to_horizontal_grid.pro` converts the glacier's elevation bands (surface, thickness, width and length per band) into about 100 equidistant cells along the glacier length, smooths them, and adds an ice-free area in front of the glacier of 25 % of its length. Cross-sections are trapezoids with 45° side walls. The widths are scaled so that the flowline area equals the band area after the [RGI 7.0 area correction](../../input-data/geometric-data.md).
- **Mass balance on the flowline.** The band balance is interpolated to each cell at its current surface elevation. Cells beyond the lowest or highest band take that band's value, and the elevation used is capped at the inventory surface, as in the MATLAB model. The balance is converted to ice with a density of 900 kg m⁻³.
- **Ice flow.** Shallow-ice approximation with a deformation-sliding factor `A_flow` (fitted per glacier in the spin-up), solved in flux form with a three-stage explicit step and an adaptive time step. The flux form conserves ice: what leaves one cell enters its neighbour, and no cell gives more ice than it holds.
- **Feedback.** The bands are rebuilt from the flowline every year, so the next year's mass balance sees the new surface elevations. Before the survey year (the year of the glacier's inventory outline) the geometry is held, as on the Δh path.
- **Velocities.** The depth-averaged and a kinematic vertical velocity are mapped onto the elevation bands for the [firn and ice temperature model](../mass-balance/firn-ice-temperature.md).

---

## Spin-up

The flow model needs the glacier in its survey year: its thickness along the flowline, and a flow factor that keeps it there. `spinup_flowmodel.pro` builds both, after Zekollari et al. (2019):

1. **Phase A.** The flowline runs to a steady state under the mean 1961–1990 balance, shifted by an ELA bias. (If the run starts after 1961, the years from the start to the survey year are used instead, and the log says so.)
2. **Phase B.** From that steady state, the flowline runs year by year with the modelled balances from about 1990 to the survey year.
3. Both phases are repeated while `A_flow` is fitted to the observed volume and the ELA bias to the observed length.

Limits and rules:

- A spin-up stops after `spinup_max_substeps` flow time steps over all its attempts (2.5 million). This is a fixed amount of work, so the result does not depend on how busy the host is. A wall-clock cap (`spinup_max_wallclock_sec`, 900 s) is only a safety net.
- When ice reaches the end of the grid, the ice-free area in front is lengthened by a quarter of the glacier length (up to 1.5 lengths) and the attempt is repeated, as in the MATLAB model.
- If a late length attempt fails, the attempt closest to the observed length is kept. The ELA bias is clamped at ±500 m.
- The survey-year state is scaled to the observed volume before the run starts.

The spin-up takes most of a flow glacier's run time, so its result is cached per glacier in `<dirres>/spinup_cache/<id>_y<year>_spinup.sav`. Failed spin-ups are cached as `<id>_y<year>_spinup_failed.txt`. The year is part of the name because an ERA5 hindcast spins up to the survey year and a projection to the year after. Each run writes a table of its spin-ups to `<dirres>/<time_resolution>/<Region>/calibration/flow_spinup_stats_<catchment>.dat`.

```{important}
Any change to the climate data, the calibration or the flow code makes the cache invalid. Delete the whole `spinup_cache/` folder (both file kinds) before the next run.
```

---

## Spin-up quality gate

After the spin-up (or a cache hit), the flow model is used only if its survey-year state, before the volume scaling, reproduces the observed glacier:

- volume error at most `spinup_gate_vol_tol` (default 0.5, i.e. 50 %), and
- modelled length at least `spinup_gate_len_min` (default 0.5) of the observed length.

Otherwise the glacier runs on the Δh parameterisation from the start. Without this gate, a glacier with a far too small spin-up state was scaled up to its observed volume on a much too short flowline and blew up in its first year.

---

(flow-fallback)=
## Fallback to the Δh parameterisation

A glacier runs on the Δh parameterisation instead of the flow model when

- it is shorter than 1 km in the inventory;
- its spin-up fails, or fails the quality gate;
- during the run its flowline blows up (a thickness above 5000 m, a non-finite value, or a whole-glacier volume change of more than 30 % in one year), its balance is not finite, or its ice reaches the end of the longest grid on land.

At a fallback during the run, `handover_to_dh.pro` passes the flowline volume to the elevation bands and the Δh parameterisation takes over in the same year. The run log ends with a `GLOGEMFLOW USAGE` block that counts how many glaciers ran on the flow model and why the others did not.

---

## Glaciers ending in the sea

The flow model has its own calving at sea:

- A glacier has a **sea front** when the bed under the first ice cell of its inventory profile is below 0 m.
- **Front calving.** Once a year, flowline ice in front of the lowest cell whose surface is at or above sea level is removed and booked as frontal ablation, by the same rule the Δh parameterisation uses for its bands below sea level.
- **Grid end.** For a sea front whose grid end lies below sea level, ice that reaches the grid end leaves as frontal ablation instead of lengthening the grid. Every other front gets the longer grid. This outflow is also written to `*_flow_gridend_outflow.dat`; `flow_gridend_outflow` decides how it is booked.
- The spin-up has no calving. The survey-year state loses its front ice below sea level once, before the run starts.

The GMIP4 flow runs used `frontal_ablation = 'n'` with a mass-balance calibration made without calving. Running the flow model together with the [frontal ablation model](calving-model.md) (`frontal_ablation = 'y'`) has not been tested.

---

## Growth limit

`limit_glacier_growth.pro` bounds every glacier once a year, on both the flow and the Δh path. A glacier whose mean thickness exceeds `growth_max_thick` (2000 m), or whose volume exceeds both `growth_max_vol` (50 km³) and `growth_max_rel` (20) times its inventory volume, is thinned back onto the limit. Its area is kept, and the removed ice is booked as ice melt. The run log reports the number of glacier-years clamped (`GROWTH LIMIT`).

---

## Main settings

| Setting | Default | Description |
|---------|---------|-------------|
| `use_flow_model` | `'n'` | `'y'` runs GloGEMflow; also sets `advance = 'y'` |
| `spinup_gate_vol_tol` | `0.5d0` | Quality gate: largest volume error of the spin-up (fraction of the observed volume) |
| `spinup_gate_len_min` | `0.5d0` | Quality gate: smallest spin-up length (fraction of the observed length) |
| `spinup_max_substeps` | `2500000l` | Work limit of one glacier's spin-up (flow time steps, all attempts) |
| `spinup_max_wallclock_sec` | `900d0` | Wall-clock safety cap of one glacier's spin-up (s) |
| `flow_gridend_outflow` | `'frontal'` | Ice leaving the grid end: `'frontal'` (frontal ablation) or `'melt_if_land'` (ice melt where the bed there is above 0 m) |
| `growth_max_thick` | `2000.0d0` | Growth limit: largest mean thickness (m); both paths |
| `growth_max_vol`, `growth_max_rel` | `50.0d0`, `20.0d0` | Growth limit: volume (km³) that is too large when it is also this many times the inventory volume |
| `write_geometry_output` | `'n'` | `'y'` saves each glacier's band and flowline geometry history (`geometry_<id>_flow.sav`, `flowgrid_<id>_flow.sav`; about 0.5–1 MB per glacier and scenario) |

The parameters of the flow solver itself (initial `A_flow`, time-step factor, cross-section shape, 5000-year limit of a steady-state run) are set in `procedures/flow/set_flow_model_parameters.pro`. See the [Settings Reference](../../running-glogem/settings-reference.md) for all settings.

When the flow model runs:

- It changes the geometry only from each glacier's survey year on.
- It needs a run that ends after 2025, or `hindcast_dynamic = 'y'` (the default for GMIP4 ERA5 hindcasts). In other runs ending before 2026, `settings.pro` switches the geometry change off and the flow model is never called.

---

## Output

The output files are those of a normal run. The netCDF files are named `GloGEMflow_*` instead of `GloGEM_*`. Additional files:

| File | Content |
|------|---------|
| `spinup_cache/` | cached spin-ups and failure markers (see above) |
| `calibration/flow_spinup_stats_<catchment>.dat` | one row per spin-up: fitted `A_flow` and ELA bias, volume and length against the observations, run time |
| `*_flow_gridend_outflow.dat` | ice that left the flowline grid end, per glacier and year |
| `geometry_<id>_flow.sav`, `flowgrid_<id>_flow.sav` | band and flowline geometry per year, with `write_geometry_output = 'y'` |

---

## Try it

`test/configs/config_aletsch_flow_monthly_projection.pro` runs Aletsch and Morteratsch with the flow model on the bundled test data, after `config_aletsch_monthly_calib.pro` (see the [Quickstart](../../getting-started/quickstart.md)).

---

## Known limitations

The changes made to the model in 2026, and the open issues, are recorded in [Model Changes 2026](../../development/model-changes-2026.md). The main open points for the flow model:

- The rebuilt elevation bands overstate the glacier area (up to about 60 %); reported numbers come from the flowline, so this affects band diagnostics only.
- Some deviations from the MATLAB model remain (front boundary, form of the ELA bias, steady-state test).
- Spin-ups that keep their closest attempt tend to be shorter than the observed glacier.
- Glaciers whose spin-up fails run on the Δh parameterisation; in regions with large ice caps (for example the Russian Arctic) that is most of the ice.

---

## References

- Zekollari, H., Huss, M., and Farinotti, D.: Modelling the future evolution of glaciers in the European Alps under the EURO-CORDEX RCM ensemble, The Cryosphere, 13, 1125–1146, [doi:10.5194/tc-13-1125-2019](https://doi.org/10.5194/tc-13-1125-2019), 2019.
- Huss, M., Jouvet, G., Farinotti, D., and Bauder, A.: Future high-mountain hydrology: a new parameterization of glacier retreat, Hydrology and Earth System Sciences, 14, 815–829, [doi:10.5194/hess-14-815-2010](https://doi.org/10.5194/hess-14-815-2010), 2010.
