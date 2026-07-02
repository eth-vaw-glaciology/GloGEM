# Calibration Data
```{note}
This section might be updated when new calibration data becomes available.
```
## Data paths
```
/itet-stor/<username>/glogem/data/geodetic/<RGIversion>/aggregated<time period>/
```
```
/itet-stor/<username>/glogem/data/snowline/<RGIversion>/aggregated<time period>/
```
---

The calibration procedure is explained in section [Calibration](../calibration/index.md)
## Geodetic Mass Balance data

To calibrate GloGEM Geodetic Mass Balance data is available. 

### Available Geodetic Mass Balance data

| Product | Spatial resolution | Periods| RGI version|
|---------|--------------------|--------|------------|
| Hugonnet et al., 2021 | glacier-specific | 2000-2010; 2010-2020; 2000-2020 | RGIv6|
| Hugonnet et al., 202X | glacier-specific | 2000-2010; 2010-2020; 2000-2020 | RGIv7|


The RGI version and calibration period are selected in the `config.pro` file.
Below an example of how the files look like (there is a file for each RGI region):

```
Glacier-specific geodetic mass balance (m w.e. a-1) 2000_2010/ according to Hugonnet et al. (2021)
ID=1: measured, ID=2: regional mean
RGI-ID  Area  lat  lon  B  errB  ID
RGI60-01.13696  3360.07904   60.176572 -140.428030   -0.727    0.155  1
RGI60-01.13635  3023.12115   60.460680 -142.071557   -0.805    0.162  1
RGI60-01.14443  2832.72624   60.427091 -139.500509    0.126    0.130  1

```
#### Variables

| Variable | Description |
|----------|-------------|
| `RGI-ID` | RGI ID |
| `Area` | Glacier area (km²) referenced to the RGI year|
| `lat` | Glacier centroid latitude |
| `lon` | Glacier centroid longitude |
| `B` | Geodetic mass balance (m w.e. a-1) |
| `errB` | uncertainty on Geodetic mass balance (m w.e. a-1) |
| `ID` | Flag: 1 = measured (based on Hugonnetet al.), 2 = regional mean (when uncertainty to high, regional mean is applied)|


## Snowline data

To calibrate GloGEM we can additionally next to the Geodetic Mass Balance also calibrate using transient snowline data. 

### Available Geodetic Mass Balance data

| Product | Spatial resolution | Period| RGI version| Regions|
|---------------|---------|----------------|--------|--------|
| Loibl et al., 2025 | glacier-specific (for glaciers > 0.5km^2) | 1985-2021 | RGIv6|RGI regions 13-15|
| Sommer et al., 2026 | glacier-specific | 2000-2025 | RGIv7| RGI region 11|


```{note}
The snowline calibration is still a work in progress
```



