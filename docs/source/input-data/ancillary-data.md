# Ancillary Data

GloGEM requires two additional model inputs that do not fit into the climate or geometric data categories: region-specific parameter tables and a global geothermal heat flux grid. Both are stored under:

```
/itet-stor/<username>/glogem/data/
```

---

## Regional parameter file

Region-specific model parameters (calving coefficient, precipitation correction factor, lapse rate, temperature offset, and calibration tolerance bounds) are stored in a single table per reanalysis product. These values are applied at the start of each regional run and override the global defaults in `settings.pro`.

### Storage path

```
/itet-stor/<username>/glogem/data/regional_parameters_<reanalysis>.dat
```

One row per RGI region (and sub-region where applicable). Read by `procedures/read/read_regionalparams.pro`.

---

## Geothermal heat flux

Required only when the englacial temperature model is active (`firnice_temperature = 'y'`). Provides the basal heat flux boundary condition for the firn and ice temperature calculation.

### Storage path

```
/itet-stor/<username>/glogem/data/geothermal_flux.grid
```

Global gridded geothermal heat flux in standard ESRI ASCII raster format. Values are stored in mW m⁻² and converted to W m⁻² on read. Read by `procedures/read/read_geothermal.pro`.
