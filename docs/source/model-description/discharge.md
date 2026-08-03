# Glacier Discharge

GloGEM calculates glacier discharge. Here we can distinguish between two types: `Discharge` (representing the initially glacierized area) and `Discharge_gl` (representing the current (evolving) glacier area).

Implemented in `procedures/processing/calculate_catchment_discharge.pro`.

The discharge $Q$ is computed as the sum of all liquid water components exiting the glacier system minus refreezing:

$$
Q = M_{\text{snow}} + M_{\text{firn}} + M_{\text{ice}} + P_{\text{rain}} - R
$$

where:
- $M_{\text{snow}}, M_{\text{firn}}, M_{\text{ice}}$ are the melt from snow, firn, and ice, respectively (See [Meltmodel](mass-balance/melt-models.md)).
- $P_{\text{rain}}$ is the rainfall (See [Accumulation](mass-balance/accumulation.md)).
- $R$ is the refreezing within the snowpack and firn (See [Refreezing](mass-balance/refreezing.md)).

In this simplified runoff representation, we do not include other hydrological processes such as evapotranspiration, groundwater recharge, or land-cover changes.

## Outputs

| Variable | Description |
|----------|-------------|
| `Discharge` | Specific daily/monthly discharge (mm); for the initially glacierized area |
| `Discharge_gl` | Specific daily/monthly discharge (mm); for the glacier area |


