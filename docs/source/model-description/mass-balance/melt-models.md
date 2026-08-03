# Melt Models

GloGEM offers two surface melt models selected via the `meltmodel` setting in `settings.pro`. Both are implemented in `procedures/processing/meltmodel.pro`.

## Surface type

Melt rates depend on surface type, tracked per elevation band:

| Code | Surface | Used for |
|------|---------|---------|
| `0` | Bare ice | `DDFice` or ice albedo |
| `1` | Snow | `DDFsnow` or snow albedo |
| `2` | Firn | `DDFfirn` or firn albedo |

---

## Model 1 — Temperature-index (degree-day) model

Selected with `meltmodel = '1'`. This is the default and computationally lightest option.

Melt for each elevation band is proportional to positive air temperature:

$$
M = \text{DDF}_{\text{surface}} \cdot T^+
$$

where $T^+$ is the daily/monthly mean air temperature (°C).

Degree-day factors by surface type:

| Surface | DDF (relative to `DDFsnow`) |
|---------|-----------------------------|
| Snow | `DDFsnow` |
| Firn | `DDFice / 1.5` |
| Ice | `2.0 × DDFsnow` |

`DDFsnow` is a primary calibration parameter. `DDFice` and `DDFfirn` are derived from `DDFsnow` using fixed ratios: `DDFice / DDFsnow = 2.0` and `DDFice / DDFfirn = 1.5`.

### Sub-monthly variability

For the monthly model, observed sub-monthly temperature variability can be superimposed onto the monthly mean temperature (setting `submonth_variability = 'y'`). This generates a synthetic daily temperature distribution for each month, from which positive degree days are accumulated. The mean of the distribution is preserved so no bias is introduced into the monthly mean.

---

## Model 3 — Simplified energy-balance model

Selected with `meltmodel = '3'`. Based on Oerlemans (2001). Requires potential solar radiation (see Solar Radiation described below).

Melt is driven by net shortwave radiation and a linear temperature term:

$$
M = \frac{\left[(1 - \alpha) \cdot SW + C_0 + C_1 \cdot T\right] \cdot 3600 \cdot 24 \cdot \Delta t}{1000 \cdot L_f}
$$

where:
- $\alpha$ is the surface albedo (snow, firn, or ice)
- $SW$ is the potential shortwave radiation (W m⁻²)
- $C_0$ is a constant offset term (W m⁻²)
- $C_1$ is the temperature sensitivity coefficient (W m⁻² °C⁻¹)
- $L_f$ is the latent heat of fusion (J kg⁻¹)
- $\Delta t$ is the number of days in the time step

Negative melt values are set to zero.

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `C0` | −45 | Constant energy-balance offset [W m⁻²] (calibrated) |
| `C1` | 10 | Temperature sensitivity [W m⁻² °C⁻¹] (calibrated) |
| `alb_snow` | 0.7 | Albedo of snow |
| `alb_firn` | 0.5 | Albedo of firn |
| `alb_ice` | 0.3 | Albedo of bare ice |

### Potential Solar Radiation


Potential solar radiation is required for melt model 3 (simplified energy balance). It is computed in `procedures/processing/potential_solarradiation.pro` when `meltmodel = '3'` is set. This procedure can be considered as a preprossessing step.


#### Description

The procedure computes clear-sky potential shortwave radiation for each elevation band as a function of:

- Geographic location (latitude, longitude)
- Elevation
- Slope and aspect of the glacier surface
- Solar declination (computed for the mid-point of each month)

The result is a monthly radiation field `sw_rad[nb, 12]` (W m⁻²) used in the energy-balance melt calculation.

#### Settings

| Setting | Description |
|---------|-------------|
| `meltmodel = '3'` | Activates the solar radiation calculation |
| `decl_sun` | Solar declination for each month (mid-month) — defined in `settings.pro` |
| `asp_class` | Aspect classes [0, 45, 90, 135, 180°] |

#### Inputs and outputs


sw_rad, which is a monthly radiation field. This field is a double-precision array with dimensions nb (number of elevation bands) by 12 (for each month of the year), and its values are in Watts per square meter (W m⁻²). It represents the clear-sky potential shortwave radiation for each elevation band.
| Variable | Description |
|---------|-------------|
| `sw_rad` | Represent the clear-sky potential shortwave radiation for each elevation band =>Monthly radiation field (W m⁻²); Array dimensions: number of elevation bands by 12 (for each month)|


---

## Debris-covered ice

When `debris_supraglacial = 'y'`, melt of debris-covered ice is modified in `procedures/processing/calculatedebrismelt.pro`. A reduction factor is applied based on debris thickness and fraction, and melt over pond/ice-cliff areas is enhanced by `debris_pond_enhancementfactor`. See [Debris Model](../debris-model.md) for details.

---

## Parameters (Model 1)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `meltmodel` | `'1'` | Melt model selection: `'1'` = DDF, `'3'` = energy balance |
| `DDFsnow` | 3 | Degree-day factor for snow (mm d⁻¹ °C⁻¹) (calibrated) |
| `DDFice` | 6 | Degree-day factor for ice (mm d⁻¹ °C⁻¹) (calibrated) |
| `t_melt` | 0 | Temperature threshold for melt (°C) |
| `submonth_variability` | `'y'` | Include sub-monthly temperature variability (monthly model only) |
| `mel` || Melt per elevation band per time step [m w.e.] |

## Outputs

| Variable | Description |
|----------|-------------|
| `Snowmelt_sfc` | Specific annual snowmelt (mm/yr); for the initially glacierized area |
| `Icemelt_sfc` | Specific annual ice/firn melt (mm/yr); for the glacier area|
| `Snowmelt_day` | Specific daily snowmelt (mm/d); for the initially glacierized area |
| `Icemelt_day` | Specific daily icemelt (mm/d); for the glacier area|
