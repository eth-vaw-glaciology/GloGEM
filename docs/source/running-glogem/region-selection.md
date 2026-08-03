# Region Selection

GloGEM organizes glaciers by RGI region. The region to process and the glacier subset within it are controlled by several settings in `config.pro`.

---

## Region batch file

All available regions and their metadata are listed in:

```
/itet-stor/<username>/glogem/data/region_batch.dat
```

Each row contains five fields: region index, RGI region number, directory name (`dir_region`), climate sub-region identifier, and the region folder name used for file paths. This file is read at the start of every run by `procedures/read/read_regionbatch.pro`.

---

## Selecting regions

### Range of regions

```
region_id_loop = [14, 14]   ; run region 14 only
region_id_loop = [1, 19]    ; run all 19 RGI regions sequentially
```

`region_id_loop` specifies the start and end indices (1-based row numbers in `region_batch.dat`) of the regions to process. Both values can be the same to run a single region.

### Climate sub-regions

Some large RGI regions (e.g. Antarctic, Greenland) are split into sub-regions for climate data handling. The `clim_subregion` field in `region_batch.dat` is set automatically from the batch file; it can be overridden in `config.pro` for targeted runs.

---

## Glacier subset options

### Single glacier

```
single_glacier = '01450'   ; Grosser Aletschgletscher
```

Overrides the region loop and runs the model for one glacier identified by its RGI ID. The grid loop is bypassed. Output goes to the `SINGLE/` subdirectory of the region output folder. Set to `''` to disable.

### Catchment selection

```
catchment_selection = 'Rhone'
```

Restricts the glacier loop to all glaciers within a named catchment. The catchment list is read from a separate file in `dir`. Set to `''` to process the full region.

### Size filter

```
size_range = [0.002, 100000]   ; (km²) minimum and maximum glacier area
```

Glaciers outside this area range are skipped. The default includes essentially all glaciers in the RGI (≥ 0.002 km²). Set `size_range = [-99, -99]` to disable area filtering entirely.

---

## Settings summary

| Setting | Default | Description |
|---------|---------|-------------|
| `region_id_loop` | `[14, 14]` | Start and end region indices in `region_batch.dat` |
| `single_glacier` | `'01450'` | RGI ID of a single glacier to run; `''` to disable |
| `catchment_selection` | `''` | Named catchment to restrict the glacier loop |
| `size_range` | `[0.002, 100000]` | Glacier area filter (km²) |
| `clim_subregion` | `''` | Climate sub-region label (set automatically from batch file) |
