# Replace the firn-insulation decision tree with a mass-based relation

## Decision

Drop the 4-leaf CART tree that sets `dT_firn_band` and compute the firn-insulation offset
per band from the physics instead. Everything below was established by experiment on
2026-08-20 using Gornergletscher (RGI7 `01225`) and Great Aletsch (`02596`), coupled
GloGEM-GloGEMflow, ERA5 forcing, thermal spin-up + strain heating on.

## What the offset currently is

`dT_applied[band] = firnice_dT_scale_b[band] * dT_firn_band[band]`

**`dT_firn_band`** — `procedures/initialise/initialise_firnicetemp_spinup.pro:39-68`, a
depth-2 CART on (seasonal temperature amplitude, elevation), four hardcoded constants:

| branch | condition | offset |
|---|---|---|
| maritime (t_amp <= 20.0 C) | elev <= 4300 m | +4.40 K |
| maritime | elev > 4300 m | **+0.54 K** |
| continental (t_amp > 20.0 C) | elev > 1500 m | **+7.26 K** |
| continental | elev <= 1500 m | +10.34 K |

**`firnice_dT_scale_b`** — scalar `firnice_dT_scale` (settings.pro:169, default 1.0), or the
linear transfer model in (tt, t_amp, elev) at `initialise_firnicetemp_spinup.pro:157-175`
when `firnice_temp_calib='y'`, plus the KO Bayesian residual from
`apply_firnicetemp_calibration_bayes.pro`.

So three stacked layers — a CART, a linear scale on it, and a Bayesian residual on that —
all predicting one quantity whose base value is physically wrong.

## Why it has to go

**1. It is a permanent surface boundary condition, not an initialisation.**
`procedures/processing/firnice_temperature_model.pro:165` runs every month, every band:

```idl
tl_fit[band,0] = min(0, T_air + firnice_dT_scale_b[band] * dT_firn_band[band])
```

(line 167 is the ice-band variant, scaled by `ICE_FRAC = 0.4`). A thermal spin-up therefore
**cannot** wash it out — it converges to the equilibrium of a boundary condition that already
contains it. Measured on Gorner, spin-up converged over 200 cycles:

| `firnice_dT_scale` | mean T > 3800 m | 4495 m @ 1 m | @ 9 m | @ 24 m |
|---|---|---|---|---|
| 0.0 (offset removed) | **-6.05** | **-11.22** | -5.53 | -3.36 |
| 1.0 (default) | -1.94 | -5.00 | -0.89 | -0.33 |
| 3.0 | -0.01 | -0.00 | -0.01 | -0.02 |

Max difference 11.9 C, mean 3.77 C after full convergence.
**With the offset removed, Colle Gnifetti comes out at -11.2 C against a measured ~-12 C.**

**2. The continental branch has no high-altitude leaf.** It splits at 1500 m, so 2000 m and
4600 m receive the same +7.26 K. Only the maritime branch knows about cold high firn
(+0.54 K above 4300 m). Measured amplitudes: Aletsch 19.075 -> maritime; **Gorner 20.486 ->
continental**; Morteratsch 21.112. Gorner misses the maritime branch by **0.49 C** and is
therefore denied the only leaf that describes a Colle Gnifetti-type site, which sits at
4450 m on that very glacier. A 0.5 C shift in one predictor changes the offset 13-fold.

**3. It double-counts the refreezing.** The thermal module already applies latent heat
layer by layer from `fit_water = mel + plg` (`firnice_temperature_model.pro:101-150`).
Adding a surface offset derived from the same refreezing warms the firn twice from one
meltwater budget. Any replacement has to resolve which of the two carries the effect.

**4. The relation the tree was fitted against was wrong.** `write_firnicetemp_validation.pro`
computed `dT = (Lf/ci) * f_rf` with `f_rf = refreeze/melt` -- a fraction where a mass ratio
belongs. Since f_rf -> 1 exactly where melt -> 0, it predicted the largest warming where
there is least meltwater: **+46.8 K at Gorner 4400-4600 m**. Already fixed (see below), but
the tree constants were derived under the old form, so they inherit the error.

## The replacement relation (already implemented in the diagnostic)

Energy balance for a firn layer of thickness `z_perm` and density `rho_firn` absorbing a mass
`m_r` of refrozen water per year:

```
rho_firn * z_perm * ci * dT = m_r * Lf
=>  dT = (Lf/ci) * (rho_w * refr_annual) / (rho_firn * z_perm)
```

`z_perm = firnice_perm_depth[i] * firnice_perm_frac_b[i]` -- the same Herron-Langway depth
the thermal module percolates to, so diagnostic and model refer to one body of firn.
`Lf = 334000 J/kg`, `ci = 2009 J/(kg K)`, `rho_firn = mean(fit_dens)`.

Now live in `procedures/write/write_firnicetemp_validation.pro`, with new output columns
`refr_ann` and `z_perm`. On Gorner it gives **+0.03 to +0.06 K across every firn band**, flat
with elevation instead of diverging:

| elevation | f_rf | old dT | new dT | z_perm |
|---|---|---|---|---|
| 3400-3599 | 0.010 | +1.6 K | **+0.03 K** | 99 m |
| 4200-4399 | 0.132 | +22.0 K | **+0.05 K** | 120 m |
| 4400-4599 | 0.282 | +46.8 K | **+0.06 K** | 120 m |

Two independent lines therefore agree that the offset up there should be ~0.05 K, not 7.26 K:
this relation, and the `dT_scale = 0` run that lands within 1 C of the observed value.

## What to build

Replace the tree with the relation evaluated per band. The obstacle is timing: `refr_annual`
comes from the mass-balance run, but `dT_firn_band` is currently needed at initialisation.
Three options, in increasing order of how much they fix:

1. **Reference-climatology estimate at init.** `initialise_firnicetemp_spinup.pro:105-140`
   already computes per-band accumulation from `tclim_ref` for the Herron-Langway depth;
   extend it to a reference-period melt and refreeze estimate and evaluate the relation there.
   Smallest change, keeps the current architecture.
2. **Iterate.** Run once, take `refr_rf_sum`, recompute, run again. Cheap for a test
   (~3 min/glacier on Gorner) but awkward operationally.
3. **Compute the surface offset in-run** from the model's own refreezing at each step, so the
   boundary condition is derived rather than looked up. Cleanest, and it is where the
   double-counting question (point 3) has to be settled anyway.

## Consequences for the calibration scheme

- **`dT_scale` changes meaning.** It currently multiplies a fitted constant. Against a physical
  base it becomes a correction on refreezing efficiency -- a parameter with a defensible prior,
  and one that should sit near 1.
- **`perm_frac` becomes doubly important**: it sets `z_perm`, which is now the denominator of
  the offset as well as the percolation depth. Note the Tier-3 grid search pinned 12 of 24
  glaciers on its lowest sampled value (0.2). Independently measured: percolation depth
  accounts for ~2.2 C of the Gorner high-firn bias, against ~7 C from the tree offset.
- **The transfer-model coefficients must be refitted.** `c0_ds/c1_ds/c2_ds/c3_ds` and
  `c0_z0..c3_z0` at `initialise_firnicetemp_spinup.pro:163-165` were fitted against the old
  `(Lf/ci)*f_rf` target.
- **Possible bearing on the leave-one-out result.** If the transfer model was fitted against a
  target that diverges at altitude, that is a structural reason the KO calibration could lose
  to a three-predictor linear regression on point-temperature RMSE while still winning on
  thermal-regime classification.

## Reproducing any of this

Configs and runner: `scripts/config_icetemp_advfield_variants.pro`, driven by
`GLOGEM_TAG / GLOGEM_CATCH / GLOGEM_ADV / GLOGEM_SPINUP / GLOGEM_STRAIN / GLOGEM_PERMFRAC /
GLOGEM_PERM / GLOGEM_DTSCALE`. Catchments `RGI11_Gorner.dat` and `RGI11_Aletsch_Gorner.dat`
in `/itet-stor/jabeer/glogem/data/catchments/`. Output under
`/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/icetemp_advfield_aletsch_morteratsch/`.
A Gorner-only run is ~3 min. Figures: `GloGEM/flow_analysis/advection_cross_section.ipynb`.
