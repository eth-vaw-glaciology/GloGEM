# Accumulation

Accumulation is computed each time step (month or day) for every elevation band. The procedure is implemented in `procedures/processing/accumulation.pro`.

## Method

### 1. Precipitation scaling

Raw precipitation from the climate input is scaled by a correction factor `c_prec` and converted to metres water equivalent:

$$
P_c = P_{\text{clim}} \cdot c_{\text{prec}} / 1000
$$

`c_prec` accounts for systematic undercatch and regional biases. It is a primary calibration parameter; see [Calibration](../../calibration/index.md).

### 2. Elevation extrapolation

Precipitation is extrapolated from the climate grid-point elevation $h_{\text{clim}}$ to each elevation band $z$ using a linear gradient:

$$
P(z) = P_c \left(1 + \frac{z - h_{\text{clim}}}{10000} \cdot \text{dPdz} \right)
$$

where `dPdz` is the precipitation gradient in % per 100 m. Default value is 1.5 % per 100 m; regional values are read from the regional parameter file.

### 3. High-elevation constraint

Precipitation is reduced at high elevations to prevent unrealistic accumulation. This reduction is only applied if the glacier's total elevation range exceeds `no_incprec[1]` (default 1000 m). 

For elevation bands above a critical height $z_{\text{crit}}$—defined as the fraction `no_incprec[1]` of the glacier's elevation range—precipitation is reduced using a function of the form $a \cdot x^b$. Here, $x$ represents the normalized height above $z_{\text{crit}}$, while $a$ and $b$ correspond to the parameters `no_incprec[3]` and `no_incprec[4]`.


### 4. Snow–rain partitioning

Precipitation is partitioned into snowfall $P_s$ and rainfall $P_l$ based on air temperature, with a linear transition zone of ±1.5 °C around the threshold `T_thres`:

$$
P_c = \begin{cases}
P(s) & \text{if } T < T_{\text{thres}} - 1 \\
P(l) & \text{if } T > T_{\text{thres}} + 1
\end{cases}
$$

### 5. Snow multiplier

Snowfall is increased by a constant factor to account for additional wind-blown snow deposition and measurement undercatch specific to snowfall:

$$
P_s^{\text{final}} = P_s \cdot \text{snow\_multiplier}
$$

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `c_prec` | 1.5 | Precipitation correction factor (calibrated) |
| `dPdz` | 1.5 | Precipitation gradient (% per 100 m) |
| `T_thres` | 1.5 | Snow–rain temperature threshold (°C) |
| `snow_multiplier` | 1.2 | Additional scaling factor applied to snowfall |
| `no_incprec` | (0.75, 1000, 2, 2) | High-elevation precipitation reduction: [elevation fraction, minimum elevation range (m), parameter a, parameter b] |
| `psg` || Snowfall per elevation band (m w.e.) |
| `plg` || Rainfall per elevation band (m w.e.) |

## Outputs

GloGEM provides specific rain in (mm/d, or mm/myr) for the initially glacierized area, glacier area-averaged annual and daily accumulation in (m.w.e.), and annual Accumulation Area (km^2).

| Variable | Description |
|----------|-------------|
| `Rain_day` | Daily specific rain on initially glacierized area (mm/d)  |
| `Rain_sfc` | Annual specific rain on initially glacierized area (mm/yr) |
| `Accumulation_day` | Daily glacier-specific accumulation (m.w.e.) |
| `Accumulation_sfc` | Annual glacier-specific accumulation (m.w.e) |
| `AAR` | Annual glacier-specific accumulation area (km^2)|



