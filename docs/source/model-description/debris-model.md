# Debris Model

The debris model simulates the evolution of supraglacial debris cover and its effect on glacier melt. It consists of two coupled procedures:

- `procedures/processing/debris_model.pro` — updates debris extent, thickness, and pond density annually
- `procedures/processing/calculatedebrismelt.pro` — applies the debris effect to melt within the mass balance loop

Activated with `debris_supraglacial = 'y'` in `settings.pro`. Input debris data is read by `procedures/read/read_supraglacialdebris.pro`.

---

## Debris evolution: `DEBRIS_MODEL.pro`

### Description

`DEBRIS_MODEL` simulates the annual evolution of debris-covered glacier surfaces, accounting for:

- **Debris expansion** — debris spreads to adjacent elevation bands based on ELA position and mass balance trends
- **Debris thickening** — debris thickness increases linearly from the ELA towards the terminus
- **Pond formation** — supraglacial ponds and ice cliffs expand over time

The melt calculation itself is handled separately in `CALCULATEDEBRISMELT` within the mass balance loop.

### Process overview

1. **ELA calculation** — ELA is computed as a decadal mean from glacier area fractions. Used to determine which bands are in the ablation zone.
2. **Debris expansion** — New debris regions are seeded from adjacent bands using `debris_exp_gradient`. Initial thickness of newly debris-covered bands is set to `debris_initialband`.
3. **Pond formation and expansion** — Pond density spreads to adjacent bands and is capped at `debris_ponddens_max`.
4. **Debris thickening** — Thickness increases at a rate `debris_thick_gradient` [cm a⁻¹ km⁻¹] from the ELA towards the terminus.
5. **Output storage** — Debris fraction, thickness, pond coverage, and reduction factors are saved per year and elevation band.

### Inputs

| Name | Type | Description |
|------|------|-------------|
| `ye` | Integer | Current simulation year |
| `nb` | Integer | Number of elevation bands |
| `step` | Float | Elevation step between bands [m] |
| `gl` | Array | Glacier outline mask |
| `area` | Array | Glacier area per elevation band |
| `ela` | Array | Equilibrium line altitude over time |
| `bal` | Array | Mass balance per elevation band |
| `elev` | Array | Elevation values of bands |
| `debris_expansion` | String | Enable debris expansion (`'y'`/`'n'`) |
| `debris_thickening` | String | Enable debris thickening (`'y'`/`'n'`) |
| `debris_frac` | Array | Fraction of area covered by debris per band |
| `debris_thick` | Array | Debris thickness per band |
| `debris_ponddens` | Array | Pond density per band |

### Outputs

| Variable | Description |
|----------|-------------|
| `elev_debthick(ye, i)` | Debris thickness per elevation band per year |
| `elev_debfrac(ye, i)` | Debris fraction per elevation band per year |
| `elev_debfactor(ye, i)` | Debris melt reduction factor per elevation band per year |
| `elev_pondarea(ye, i)` | Pond-covered area per elevation band per year |

---

## Debris melt: `CALCULATEDEBRISMELT.pro`

### Description

Applied within the melt model loop (Loop 14, `meltmodel = '1'`). For each elevation band with debris-covered ice, the melt rate is modified based on:

- **Debris-covered ice** — melt reduced by a factor from the lookup table `debris_type_red` (indexed by `debris_thick`)
- **Bare ice** — melt unchanged
- **Ponds / ice cliffs** — melt enhanced by `debris_pond_enhancementfactor`

The weighted melt for a band is:

$$
M_{\text{band}} = (f_d - f_p) \cdot r_d \cdot M_{\text{clean}} + (1 - f_d) \cdot M_{\text{clean}} + f_p \cdot e_p \cdot M_{\text{clean}}
$$

where $f_d$ is debris fraction, $f_p$ is pond/cliff fraction, $r_d$ is the debris reduction factor, and $e_p$ is `debris_pond_enhancementfactor`.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `debris_supraglacial` | `'n'` | Activate the debris model |
| `debris_expansion` | `'y'` | Allow spatial expansion of debris over time |
| `debris_thickening` | `'y'` | Allow thickening of debris over time |
| `debris_exp_gradient` | 2.0 | Rate of debris expansion [% a⁻¹ fraction⁻¹] |
| `debris_seed_bands` | 10 | Scaling factor for new debris-seeded bands per year |
| `debris_initialband` | 0.01 | Initial debris thickness in newly seeded bands [m] |
| `debris_thick_gradient` | 1.0 | Rate of debris thickening [cm a⁻¹ km⁻¹] |
| `debris_pond_enhancementfactor` | 2 | Melt enhancement factor over ponds/ice cliffs |
| `debris_ponddens_max` | 0.1 | Maximum pond density [-] |
