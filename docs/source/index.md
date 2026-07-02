# The Global Glacier Evolution Model (GloGEM)

The Global Glacier Evolution Model is an IDL package which allows modelling the evolution of all 200,000 glaciers on Earth outside the ice sheets.
The model is forced by monthly or daily temperature and precipitation from reanalysis products for the past and global climate models (GCMs) for future projections. In contrast to previous global-scale glacier models, GloGEM includes mass loss due to frontal ablation of marine-terminating glaciers.

## Cite GloGEM

Please cite this repository using its Zenodo DOI, which always resolves to the version you used:

> Huss, M., van Tricht, L., Beer, J., von der Esch, A. (2026). GloGEM: The Global Glacier Evolution Model (version 0.1.1). DOI: 10.5281/zenodo.21133140 URL: https://github.com/eth-vaw-glaciology/GloGEM

For background on the original model, see the model description paper: Huss, M. and Hock, R.: A new model for global glacier change and sea-level rise. Frontiers in Earth Science, 3, 5, [doi:10.3389/feart.2015.00054](https://www.doi.org/10.3389/feart.2015.00054), 2015. Please cite the software itself via the Zenodo DOI rather than the paper, since it reflects the current, actively developed version.

You can easily cite this repository using the "Cite this repository" button in the sidebar of the [GitHub repository](https://github.com/eth-vaw-glaciology/GloGEM), which will generate up-to-date APA/BibTeX entries automatically.

```{note}
This documentation is under active development.
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Getting Started

getting-started/installation
getting-started/configuration
getting-started/quickstart
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Model Description

model-description/index
model-description/mass-balance/index
model-description/mass-balance/accumulation
model-description/mass-balance/melt-models
model-description/mass-balance/refreezing
model-description/mass-balance/firn-ice-temperature
model-description/glacier-dynamics/retreat-model
model-description/glacier-dynamics/calving-model
model-description/debris-model
model-description/discharge
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Input Data

input-data/index
input-data/climate-data
input-data/geometric-data
input-data/ancillary-data
input-data/calibration-data
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Running GloGEM

running-glogem/index
running-glogem/run-modes
running-glogem/region-selection
running-glogem/gcm-configuration
running-glogem/settings-reference
running-glogem/output-options
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Calibration

calibration/index
calibration/geodetic
calibration/snowline
```

```{toctree}
:maxdepth: 2
:titlesonly:
:caption: Contributing

contributing/index
contributing/git-workflow
```
