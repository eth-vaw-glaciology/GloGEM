# Running GloGEM

GloGEM is launched by running `glogem.pro` from the IDL command line within the repository root directory. The model reads all shared defaults from `procedures/initialise/settings.pro` and then applies user-specific overrides from `config.pro` in the repository root.

```
idl glogem
```

A timestamped log file is written to `logs/` in the repository root for every run.

## Execution flow

At startup, GloGEM:

1. Loads shared defaults from `settings.pro`
2. Applies user overrides from `config.pro`
3. Reads the region batch file and optional firn-ice temperature batch
4. Loops over GCMs → SSPs → experiments → regions → glaciers
5. For each glacier: reads hypsometry and climate data, runs the mass balance model year-by-year, and writes output

## Sub-pages

- [Run modes](run-modes.md) — time resolution, calibration vs. forward run, hindcast options
- [Region selection](region-selection.md) — selecting regions, single glaciers, and catchments
- [GCM configuration](gcm-configuration.md) — selecting models, SSPs, and batch setup
- [Settings reference](settings-reference.md) — complete list of configurable settings
- [Output options](output-options.md) — output options, directory structure and variables
