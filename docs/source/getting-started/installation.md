# Installation

```{note}
This section is under development.
```

## Requirements

- IDL (Interactive Data Language) — version IDL 9.0.0  or later
- Access to the GloGEM data shares (ETH VAW members only at present)

## Getting the code

Clone the GloGEM repository:

```bash
git clone https://github.com/eth-vaw-glaciology/GloGEM.git
```

## Directory layout

After cloning, the repository contains:

| Path | Contents |
|------|----------|
| `glogem.pro` | Main entry point |
| `procedures/initialise/settings.pro` | All model settings |
| `procedures/processing/` | Core model computations |
| `procedures/read/` | Input data readers |
| `procedures/write/` | Output writers |
| `procedures/calibration/` | Calibration routines |
| `functions/` | Small utility functions |
