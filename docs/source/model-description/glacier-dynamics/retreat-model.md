# Glacier Retreat Model

The retreat model updates glacier geometry — ice thickness, area, and surface elevation per elevation band — once per year based on the computed net mass balance. It is implemented in `procedures/processing/glacier_retreat.pro` and activated with `glacier_retreat = 'y'`.

---

## Overview

After each mass balance year, the volume change $\Delta V$ (m³) is distributed across all ice-covered elevation bands using the $\Delta h$-parameterisation of Huss et al. (2010). The resulting thickness change per band drives a proportional update of band area via a power-law area–thickness scaling.

---

## Normalized elevation ($\Delta h$-parameterisation)

Each ice-covered elevation band $i$ is assigned a normalized elevation $hr_i$:

$$
hr_i = \frac{z_{\text{top}} - z_i}{z_{\text{top}} - z_{\text{bot}}}
$$

where $z_i$ is the band's surface elevation, $z_{\text{bot}}$ is the terminus elevation, and $z_{\text{top}}$ is the headwall elevation. By convention $hr = 1$ at the terminus and $hr = 0$ at the headwall, so the largest thickness changes are concentrated at the tongue.

The shape of the $\Delta h$ function depends on glacier size (total area $A$):

| Size class | Condition | $\Delta h$ polynomial |
|------------|-----------|----------------------|
| Small | $A \leq 5\ \text{km}^2$ | $(hr - 0.30)^2 + 0.60\,(hr - 0.30) + 0.09$ |
| Medium | $5 < A \leq 20\ \text{km}^2$ | $(hr - 0.05)^4 + 0.19\,(hr - 0.05) + 0.01$ |
| Large | $A > 20\ \text{km}^2$ | $(hr - 0.02)^6 + 0.12\,(hr - 0.02)$ |

All values are clipped to $[0, 1]$. Larger glaciers have a more sharply peaked function that concentrates thinning near the terminus, while smaller glaciers have a more uniform distribution.

---

## Thickness and area update

A scaling factor $f$ converts the normalized $\Delta h$ profile into actual thickness changes:

$$
f = \frac{\Delta V}{\sum_i \Delta h_i \cdot A_i}
$$

where $A_i$ is the current band area (km²). The per-band thickness change is:

$$
\Delta z_i = \Delta h_i \cdot f
$$

Updated band areas follow a power-law area–thickness scaling:

$$
A_i = A_{i,0} \left(\frac{h_i}{h_{i,0}}\right)^{1/\gamma}
$$

where $A_{i,0}$ and $h_{i,0}$ are the reference (initial) area and thickness, $h_i$ is the updated thickness, and $\gamma$ is the valley shape exponent (`expon`, default 2.0). After updating area, mean band thickness is recalculated to enforce volume conservation:

$$
h_i = \frac{A_{i,0} \cdot h_{i,0}^{1/\gamma}}{A_i}
$$

Bands where thickness drops to zero are removed from the active glacier domain (area set to zero, surface elevation reset to bed elevation).

---

## Redistribution of extreme thinning at the terminus

When `redistribute_vplus = 'y'`, the model checks whether the computed thinning rate in the lowest one-sixth of the glacier (by band count) would exceed the local mass balance rate. If so, the excess volume is removed from those bands and redistributed uniformly over the rest of the glacier. This prevents unphysical thickness losses in bands with thin ice and ensures thermodynamically consistent retreat.

---

## Glacier advance

When `advance = 'y'` and the glacier gains volume (i.e. the volume change $\Delta V > 0$), the model can extend the glacier into previously ice-free bands below the terminus.

**Active advance** (volume exceeds initial volume): Per-band elevation gains that would exceed `adv_fcrit` (m a⁻¹) are capped at that threshold. The excess volume is distributed into elevation bands immediately below the current terminus, with hypothetical initial areas and thicknesses derived from the mean of the current terminus region.

**Lookup-table advance** (volume recovering from retreat, `adv_lookup = 'y'`): During retreat, GloGEM records glacier geometry at each volume level. If the glacier subsequently regains volume, these stored geometries are used to reconstruct the correct hypsometry rather than extrapolating from the current shape.

Both advance modes are disabled (`advance = 'n'`) when running without the retreat module, e.g. in calibration-only mode.

---

## Very small glaciers

Glaciers with fewer than five ice-covered elevation bands bypass the $\Delta h$-parameterisation. Thickness and surface elevation are updated directly by the local mass balance rate (m w.e. divided by 0.9 for ice density conversion), and band area is updated via the same area–thickness scaling as above.

---

## Marine terminus clean-up

After the geometry update, any elevation bands whose surface elevation falls below sea level are removed. Their ice volume is added to the calving flux output. This step runs inside `glacier_retreat.pro` independently of the calving model in `calving_model.pro`.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `glacier_retreat` | `'y'` | Activate annual geometry update |
| `expon` | 2.0 | Valley shape exponent $\gamma$ controlling area change per unit thickness change |
| `dh_size` | `[5, 20]` | Area thresholds (km²) between small/medium/large $\Delta h$ parameterisations |
| `redistribute_vplus` | `'y'` | Redistribute extreme thinning at the terminus over the rest of the glacier |
| `advance` | `'y'` | Allow glacier advance into ice-free bands |
| `adv_fcrit` | 2.0 | Maximum elevation gain per band (m a⁻¹) before excess volume is redistributed into advance |
| `adv_lookup` | `'n'` | Use stored geometry lookup table during volume recovery |

## Outputs

| Variable | Description |
|----------|-------------|
| `Area` | Glacier total area (km²) per year |
| `Volume` | Glacier total volume (km³) per year |
| `Hmin` | Minimum surface elevation of the active glacier (m a.s.l.) |
