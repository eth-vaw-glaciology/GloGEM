# Refreezing

Refreezing of meltwater and rain within the snowpack and firn is an important component of the glacier mass balance, particularly in cold and polythermal glaciers. GloGEM provides two options: a fast parametrised scheme and a full physics-based heat conduction model.

Only one option can be active at a time, selected in `settings.pro`.

---

## Parametrised refreezing

Selected with `refreezing_parametrised = 'y'` (default). Implemented in `procedures/processing/refreezing_parametrised.pro`.

This scheme approximates the cold content of the firn based on the cumulative air temperature over the preceding winter. Refreezing only occurs in firn-covered elevation bands.

The refreezing amount is limited by:
1. A minimum melt threshold — refreezing only triggers if melt exceeds `rf_melcrit / 4`
2. A cold-content threshold — the cumulative temperature must be sufficiently negative (below −50 °C·timestep)
3. A maximum capacity — proportional to the annual mean temperature magnitude and the presence of firn:

$$
\text{refr} = \min\left(M,\ r_{f,\text{crit}} \cdot \frac{|\overline{T}_{\text{winter}}|}{30} \cdot \text{firn}\right)
$$

where $r_{f,\text{crit}}$ is `rf_melcrit` and $\text{firn}$ is 1 in firn-covered bands and 0 elsewhere.

**Advantage:** Fast, negligible computational overhead.  
**Limitation:** Does not resolve vertical temperature profiles or the distinction between firn and ice permeability.

---

## Full refreezing model

Selected with `refreezing_full = 'y'`. Implemented in `procedures/processing/refreezing_full.pro`.

This scheme solves the 1-D heat conduction equation through a multi-layer snowpack/firn column. It explicitly tracks temperature profiles and the cold content available for refreezing.

### Vertical grid

The column is discretised into `rf_layers` layers (default: 8) of uniform thickness `rf_dz` = 1 m, with a density profile `dens_rf` that increases from 300 kg m⁻³ at the surface to 650 kg m⁻³ at the base.

### Heat conduction

For each sub-timestep (the time step is subdivided by `rf_dsc` for numerical stability), temperature in layer $j$ is updated by:

$$
T_j^{t+1} = T_j^t + \frac{\kappa_j}{c_j} \cdot \frac{\Delta t}{(\Delta z)^2} \cdot \left(T_{j-1}^t - 2T_j^t + T_{j+1}^t\right)
$$

where $\kappa_j$ and $c_j$ are the thermal conductivity and heat capacity of layer $j$, computed from a mixture of ice and air weighted by density.

The upper boundary condition is set to the monthly mean air temperature. No heat flux is applied at the lower boundary.

### Cold content and refreezing

Cold content $Q_c$ is accumulated when melt is below the threshold `rf_melcrit`. When melt is sufficient, the cold content is evaluated and refreezing occurs up to the available cold content or the available meltwater, whichever is smaller:

$$
\text{refr} = \min\left(M + P_l,\ Q_c\right)
$$

The calculation distinguishes between firn surfaces (where the full column is available) and ice surfaces (where only a shallow layer above the snow depth is considered).

**Advantage:** Physically based, captures seasonal cold-wave propagation.  
**Limitation:** Significantly slower than the parametrised scheme.

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `refreezing_parametrised` | `'y'` | Activate parametrised refreezing |
| `refreezing_full` | `'n'` | Activate full heat-conduction refreezing (overrides parametrised) |
| `rf_melcrit` | 0.02 | Minimum melt to trigger refreezing (m w.e.) |
| `rf_layers` | 8 | Number of vertical layers in full model |
| `rf_dz` | 1.0 | Layer thickness (m) |
| `rf_dsc` | 3 | Sub-timestep factor for numerical stability |
| `dens_rf` | [300, 300, 400, 450, 500, 550, 600, 650] | Density profile (kg m⁻³) |
| `refr` | |Refreezing per elevation band per time step (m w.e.) |
| `refre[ye]`| | Area-averaged annual refreezing (m w.e.) |

## Outputs

| Variable | Description |
|----------|-------------|
| `Refreezing_sfc` | Specific annual refreezing (mm/yr); for the glacier area |
| `Refreezing_day` | Specific daily refreezing (mm/d); for the glacier area|
