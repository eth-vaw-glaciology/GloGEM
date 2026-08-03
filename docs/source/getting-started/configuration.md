# Configuration

GloGEM separates shared model settings from personal, machine-specific settings.

## Shared settings: `settings.pro`

The file `procedures/initialise/settings.pro` contains all model settings committed to the repository. This file defines defaults for every parameter — time resolution, region selection, GCM choice, calibration options, output variables, and physical constants.

Do not add personal paths or experiment-specific values here. Changes to this file affect everyone working from the same repository.

## Personal overrides: `config.pro`

Each user maintains a personal `config.pro` in the root of the repository. This file is listed in `.gitignore` and will never be accidentally committed. Any setting from `settings.pro` can be overridden here.

### One-time setup per machine

```bash
cp config.pro.example config.pro
```

Then open `config.pro` and set at minimum your output directory:

```idl
dirres = '/path/to/your/output/directory'
```

The model will stop with a clear error message if `dirres` is not set.

### Typical personal overrides

```idl
; Output directory (required)
dirres = '/scratch/username/glogem_output/'

; Run a single glacier instead of a full region
single_glacier = '01450'   ; Aletschgletscher

; Select region
region_id_loop = [11, 11]  ; Central Europe

; Time resolution
time_resolution = 'daily'
```

For a full list of available settings, see the [Settings Reference](../running-glogem/settings-reference.md).
