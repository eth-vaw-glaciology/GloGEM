<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/eth-vaw-glaciology/GloGEM/blob/main/docs/source/images/GloGEM_logo_v3_dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/eth-vaw-glaciology/GloGEM/blob/main/docs/source/images/GloGEM_logo_v2.png">
    <img alt="GloGEM Logo" src="https://github.com/eth-vaw-glaciology/GloGEM/blob/main/docs/source/images/GloGEM_logo_v2.png" width="66.6%">
  </picture>
</p>

# The Global Glacier Evolution Model (GloGEM)

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/v/release/eth-vaw-glaciology/GloGEM?include_prereleases&label=version)](https://github.com/eth-vaw-glaciology/GloGEM/releases)
[![DOI](https://zenodo.org/badge/919352632.svg)](https://doi.org/10.5281/zenodo.21133140)
[![Publication](https://img.shields.io/badge/Huss_%26_Hock_2015-Front._Earth_Sci.-green)](https://doi.org/10.3389/feart.2015.00054)

The Global Glacier Evolution Model is an IDL package which can model the evolution of all of Earth's 200,000 glaciers outside the ice sheets. 
The model is forced by monthly/daily near surface air temperature and precipitation from 14 Global Circulation Models and three emission scenarios. 
In contrast to previous global-scale glacier models, GloGEM includes mass loss due to frontal ablation of marine-terminating glaciers. To get started, please have a look at our
[Documentation - page](https://glogem-doc-temp.readthedocs.io/en/latest/index.html#).

## Cite GloGEM

Please cite this repository using its Zenodo DOI, which always resolves to the version you used:

> Huss, M., van Tricht, L., Beer, J., von der Esch, A. (2026). GloGEM: The Global Glacier Evolution Model (version 0.1.1). DOI: 10.5281/zenodo.21133140 URL: https://github.com/eth-vaw-glaciology/GloGEM

For background on the original model, see the model description paper (Huss and Hock, 2015 — badge above). Please cite the software itself via the Zenodo DOI rather than the paper, since it reflects the current, actively developed version.

You can easily cite this repository using the "Cite this repository" button in the sidebar, which uses [`CITATION.cff`](CITATION.cff) to generate up-to-date APA/BibTeX entries automatically.

## Glacier model type

GloGEM is a “glacier centric model”, which means that it runs for each glacier independently of the others. In the case of glacier complexes, 
it relies on the glacier inventory to properly separate the individual glacier entities by the ice divides, ensuring that all ice in a glacier 
basin flows towards a single glacier terminus.

## Setup (personal configuration)

GloGEM separates shared model settings from personal/machine-specific settings:

- **`settings.pro`** — shared model configuration committed to the repository. Do not add personal paths or experiment-specific values here.
- **`config.pro`** — your personal overrides (output directory, region selection, run mode, etc.). Git-ignored, never committed.

**One-time setup per machine:**

```bash
cp config.pro.example config.pro
```

Then open `config.pro` and set at minimum your output directory:

```idl
dirres = '/path/to/your/output/directory'
```

Any setting from `settings.pro` can be overridden in your personal config. `config.pro.example` lists the most commonly adjusted settings, but it is not exhaustive. If you need to change a setting that is not listed there, look it up in `settings.pro`, copy the line to your `config.pro`, and change the value — everything in `settings.pro` can be overridden this way.

The model will stop with a clear error if `dirres` is not set.

## Input settings reference

If you want to look up available region IDs, climate subregions, or CMIP6 GCM codes for configuring your run, see the [Input Settings Reference](INPUT_SETTINGS.md).
