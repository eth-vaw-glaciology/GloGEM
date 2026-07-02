# Calibration

GloGEM provides two options for model calibration:

1. **Calibration on geodetic mass balance**: To match the long-term glacier evolution. Operational on the monthly and daily version of GloGEM.
- For RGIv6: this utilizes the global geodetic mass balance dataset from [Hugonnet et al. (2021)](https://www.nature.com/articles/s41586-021-03436-z).
- For RGIv7: - not available so far

2. **Calibration on geodetic mass balance and snowlines**: Matches both long-term glacier evolution and seasonal glacier dynamics (melt and accumulation) forced by the transient snowline altitude (TSLA). This calibration can only run on the daily version of GloGEM.
- For RGIv6: this utilizes the global geodetic mass balance dataset from [Hugonnet et al. (2021)](https://www.nature.com/articles/s41586-021-03436-z) & snowline data from [Loibl et al. (2025)](https://www.nature.com/articles/s41597-024-04309-6). 
```{note}
The snowline from Loibl et al. (2025) is currently only available for RGIv6 region 13-15, and glaciers larger than 0.5km^2. 
```
- For RGIv7: snowline data from [Sommer et al. (2026)](https://doi.org/10.5194/essd-2026-35).
```{note}
The snowline from Sommer et al. (2026) is currently only available for RGIv7 region 11, and has not been tested in GloGEM yet!

A dataset for geodetic mass balance referenced to RGIv7 is not available at the moment.
```

![Pros and cons of calibration schemes](../images/calibration_schemes_glogem_doc.png)
Pros and cons of calibration schemes. Computationally the calibration on the geodetic mass balance is faster than the one snowlines and geodetic mass balance.


## Sub-pages

- [Geodetic Mass Balance](geodetic.md) — Calibration on Geodetic Mass Balance
- [Snowline](snowline.md) — Calibration on Snowlines and Geodetic Mass Balance
