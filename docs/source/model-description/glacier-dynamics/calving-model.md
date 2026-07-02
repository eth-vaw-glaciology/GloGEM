# Calving Model

The calving model computes annual frontal ablation for marine-terminating glaciers. It is implemented in `procedures/processing/calving_model.pro` and activated with `frontal_ablation = 'y'`. The approach follows Oerlemans and Nick (2005), with modifications for slope-dependent calving and effective frontal width.

---

## Applicability

The calving model activates only when both of the following conditions are met:

1. `frontal_ablation = 'y'` in the settings.
2. The bed elevation of the two lowest ice-covered elevation bands is below sea level.

Glaciers that terminate on land are not affected, regardless of the `frontal_ablation` setting.

---

## Calving front height

The height of the calving front $H_f$ (m) is the larger of two estimates:

$$
H_f = \max\!\left(\alpha_f \sqrt{L \cdot f_L},\ \frac{\rho_w}{\rho_i}\, d_t \right)
$$

where:
- $\alpha_f = 0.7$ (m$^{1/2}$) — empirical calving height coefficient
- $L$ — glacier length at the terminus (m)
- $f_L = 1.4$ — length correction factor (`length_corrfact`)
- $\rho_w / \rho_i \approx 1.127$ — ratio of water to ice density
- $d_t$ — mean water depth at the terminus (m), taken as the absolute value of the mean bed elevation of the two lowest ice-covered bands

The first term scales with glacier length (a proxy for driving stress); the second is the flotation height, i.e. the ice thickness required to be at the point of flotation for the given water depth.

---

## Frontal ablation flux

Annual frontal ablation $q_{\text{front}}$ (m³ a⁻¹) is:

$$
q_{\text{front}} = c \cdot d_t \cdot H_f \cdot \bar{\beta}_t \cdot w_{\text{eff}}
$$

where:
- $c$ — regional calving parameter (`c_calving`, default 2.4)
- $d_t$ — mean water depth at the terminus (m)
- $H_f$ — calving front height (m)
- $\bar{\beta}_t$ — mean surface slope over the lowest ~10 ice-covered bands
- $w_{\text{eff}}$ — effective frontal width (m, see below)

The slope term $\bar{\beta}_t$ modulates calving flux: steeper terminus slopes produce higher calving rates, consistent with the velocity dependence in the original Oerlemans and Nick (2005) formulation.

### Effective frontal width

For narrow fronts the effective width equals the actual mean width of the two lowest bands. For glaciers with very wide fronts (e.g. outlet glaciers in Greenland or Antarctica), a non-linear correction limits the scaling:

$$
w_{\text{eff}} = \begin{cases}
w & w < w_{\text{crit}} \\[4pt]
w^{1/\gamma_w} \cdot \dfrac{w_{\text{crit}}}{w_{\text{crit}}^{1/\gamma_w}} & w \geq w_{\text{crit}}
\end{cases}
$$

with $w_{\text{crit}} = 3000$ m (`crit_ccorrdist`) and $\gamma_w = 2.5$ (`ccorr_expon`).

---

## Maximum flux constraint

To prevent climatologically unrealistic calving rates, $q_{\text{front}}$ is capped at the total glacier-wide accumulation volume:

$$
q_{\text{front}} \leq A_{\text{gl}} \cdot \max(\dot{c})
$$

where $A_{\text{gl}}$ is total glacier area (m²) and $\max(\dot{c})$ is the maximum annual accumulation rate over the glacier (m a⁻¹). A floor of $0.2 \cdot A_{\text{gl}}$ m³ a⁻¹ ensures that even low-accumulation glaciers can still lose a small amount of mass through calving.

---

## Partitioning between geometry change and direct mass loss

Not all frontal ablation translates directly into ice break-off. Below a specific threshold `calv_sep` (m w.e. a⁻¹), calving primarily drives glacier retreat (geometry change handled by the retreat model), rather than producing icebergs. The partitioning is:

$$
F_{\text{geom}} = \min\!\left(1,\ \frac{q_{\text{front,spec}}}{\max(q_{\text{front,spec}},\ q_{\text{front,spec}})}\right)
$$

Concretely:
- If the specific frontal ablation $q_{\text{front,spec}} < $ `calv_sep`: the entire flux drives volume change and is passed to the retreat model ($q_{\text{calv}} = 0$, no direct mass loss).
- If $q_{\text{front,spec}} \geq $ `calv_sep`: the fraction corresponding to `calv_sep` drives geometry change, and the remainder is recorded as direct calving mass loss ($q_{\text{calv}} > 0$).

This split prevents double-counting: mass removed as direct calving is not also removed by the retreat model.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `frontal_ablation` | `'y'` | Activate calving for marine-terminating glaciers |
| `alpha_f` | 0.7 | Empirical calving front height coefficient (m$^{1/2}$) |
| `c_calving` | 2.4 | Regional calving parameter; read from regional parameter file when `regparams_readfromfile = 'y'` |
| `length_corrfact` | 1.4 | Correction factor for effective glacier length in $H_f$ |
| `calv_sep` | 1.25 | Threshold (m w.e. a⁻¹) separating calving-driven retreat from direct ice break-off |
| `crit_ccorrdist` | 3000 | Width threshold (m) above which non-linear effective width correction applies |
| `ccorr_expon` | 2.5 | Exponent for effective width correction |

## Outputs

| Variable | Description |
|----------|-------------|
| `Frontal_ablation` | Glacier-wide specific frontal ablation (m w.e. a⁻¹) |
