# Mass Balance

The mass balance is the core of GloGEM. It is computed per elevation band for each time step (month or day) of the simulation. The net specific mass balance of each band is:

$$
b = \text{accumulation} - \text{melt} + \text{refreezing}
$$

During the calculation of the mass balance GloGEM tracks three surface types per elevation band:

| Code | Surface |
|------|---------|
| `0` | Bare ice |
| `1` | Snow |
| `2` | Firn |

Surface type controls which melt factor or albedo is applied. The transition between snow and firn depends on whether the snow cover persists from one year to the next.

## Outputs

GloGEM provides glacier-wide aggregated and for each elevation band surface mass balance values as outputs:

| Variable | Description | 
|----------|-------------|
| Annual balance | Glacier-specific annual surface mass balance (m w.e.) |
| Winter balance | Glacier-specific winter surface mass balance (m w.e.) |

## Sub-pages

- [Accumulation](accumulation.md) — precipitation partitioning and elevation extrapolation
- [Melt models](melt-models.md) — degree-day (Model 1) and simplified energy balance (Model 3)
- [Refreezing](refreezing.md) — parametrised and full physics-based options
- [Firn and ice temperature](firn-ice-temperature.md) — englacial temperature model
