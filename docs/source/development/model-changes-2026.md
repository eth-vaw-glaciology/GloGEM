# Model Changes 2026 (GloGEMflow and GMIP4)

This page keeps track of every major problem found in GloGEM and GloGEMflow during the 2026 GloGEMflow integration and the GlacierMIP4 (GMIP4) campaign, and of what was changed. Many of the items are in **core GloGEM code that is also on `main`**, not only in the flow model. The page is written for the GloGEM developers who will review the merge of these branches into `main` (Matthias Huss, Lander Van Tricht, Alexandra von der Esch) and for the MATLAB GloGEMflow side (Harry Zekollari's code, from which the IDL flow model was ported).

```{note}
Status: 2026-09-29, about 18:00 (round 5 merged on `glogemflow-v3r5`). "Main" means `origin/main` at `4e5d5a1` (2026-09-24). The local `main` ref in our clone is out of date (`51bae41`, 2026-07-01); all "in main" statements below were checked against `origin/main`. Commit hashes are short hashes.

What is on GitHub: `main`, `GloGEMflow` at `dac9fa4` (2026-09-23) and an old `IDL_GloGEMflow` branch (2025-07). `origin/GloGEMflow` lacks the last 9 commits of the `gmip4-v1` tag (among them `f129fc5`, `a6037e2` and `bb4744e`) and the 13 commits after the tag, and the tag itself is not pushed. The branches `glogemflow-stability`, `glogemflow-fixes`, `glogemflow-fixes-b`, `glogemflow-newpath`, `glogemflow-v3` and `glogemflow-v3r5` exist only in the local clone. Until Janosch pushes, nobody outside can see the v1 code as submitted, or any later code.
```

```{admonition} If you read nothing else: bugs that are still in main
:class: important

- {ref}`G1 <mc-g1>`: GMIP4 projections read the climate 2 (NH) or 8 (SH) months late.
- {ref}`G2 <mc-g2>`: the same shift in the CMIP6 projection branch (not fixed on any branch).
- {ref}`G3 <mc-g3>`: the ERA5 and GCM series can come from neighbouring grid points, so the temperature jumps at 2025/2026 (single glaciers by up to 12.6 °C).
- {ref}`G5 <mc-g5>`: new climate path (NorthAsia, LowLatitudes, Antarctic): the lapse rate is one month late, and the sub-monthly variability comes from the wrong cell and month.
- {ref}`G6 <mc-g6>`: since 2026-09-15, monthly runs on the old climate path with a MIP other than GMIP4 or AMOC (the CMIP6 default and every calibration config) give glaciers west of 0° the climate of the region's westernmost ERA5 column.
- {ref}`G8 <mc-g8>`: some glaciers are never simulated (grid-box edges; the South Orkney gap in Antarctic).
- {ref}`G9 <mc-g9>`: Δh advance scheme: a division by zero turns glaciers into NaN.
- {ref}`G10 <mc-g10>`: Δh parameterisation: melting glaciers turn NaN instead of melting out.
- {ref}`G15 <mc-g15>`: the calving-flux file is never written.
- {ref}`K12 <mc-k12>`: in every `.dat` output the `Icemelt_sfc` file holds snow melt and the `Snowmelt_sfc` file holds ice melt.
- {ref}`K16 <mc-k16>`: a missing GCM directory makes the job hang instead of stopping.

The overview table in section 2 marks every other item that main still has; section 1 explains the terms.
```

---

## 1. Purpose and how to use this page

### What counts as a major item

An item is listed if it changes model results or output files, changes how a campaign must be run or post-processed, or is a bug that is still in `main`. Refactoring, notebooks and the day-to-day development of the englacial temperature module are not listed one by one.

### How to read an entry

Every item has an ID:

| Prefix | Part |
|---|---|
| G | Core GloGEM (mass balance, climate, Δh parameterisation, input and output). Most of these files are also on `main`. |
| F | GloGEMflow: the flowline model, its spin-up and its coupling to GloGEM. Not on `main`. |
| S | Scripts, post-processing and run infrastructure (`scripts/`). |
| K | Known issues that are accepted or still open. |

Each detailed entry says what was wrong, how it was found, its effect (with numbers), the fix and its commit, how the fix was tested, and which GMIP4 submissions carry the problem. "Bit-identical" or "byte-identical" means the output files were compared before and after the change and did not differ.

### Terms used on this page

- **Survey year.** The year of a glacier's inventory outline and thickness (RGI7). The flow model's spin-up has to reproduce the glacier as observed in this year, and the model changes a glacier's geometry only from about this year on (K4, K5).
- **Spin-up, Phase A and Phase B.** The flow model's spin-up (`spinup_flowmodel.pro`, after Zekollari et al. 2019) builds the survey-year glacier in two phases. Phase A runs the flowline to a steady state under the 1961–1990 mean balance, shifted by an ELA bias. Phase B then runs year by year with the modelled balances from 1990 to the survey year. Both phases are repeated while the flow factor A_flow is fitted to the observed volume and the ELA bias to the observed length.
- **Spin-up quality gate.** The test after the spin-up that decides whether a glacier runs on the flow model: its survey-year volume must be within 50 % of the observed volume and its length at least half the observed length (F3). A glacier that fails the gate, or whose spin-up fails, runs on the Δh parameterisation.
- **Output gate.** The script `scripts/check_gmip4_output.py`, run on the finished output of a region before it is submitted. It flags runaway glaciers, missing batches and non-finite values (S5). "Gate findings" are its flags.
- **Old and new climate path.** The two ways GloGEM reads monthly ERA5 and GCM data. The old path (`read_climatepast_monthly.pro`, `downscale_gcmdata_monthly.pro`) reads regional grid files and is used for most regions. The new path (`new='y'`, set automatically for NorthAsia, LowLatitudes and Antarctic; the files ending in `_new.pro`) reads one file per ERA5 grid point, per subregion (Lander's `b5aa086`, `8eeef31`, `eb035d5`).

### How to maintain this page

- Add an entry when a fix is committed or a decision is taken, in the same commit or right after it.
- Give every claim its number and its commit hash, and say which branch has it.
- Keep an item "in progress" until it is committed on the production branch (`glogemflow-v3`).
- When a fix reaches `main`, change "In main?" in the overview table to "no" and add the merge commit.
- Record every decision in {ref}`section 7 <mc-decisions>` with its date.

A new entry can start from this template:

```text
### Gxx. <title>
- What was wrong: ...
- How it was found: <date>, <how>
- Effect: <numbers>
- Fix: <commit> (<branches>), <what changed>
- Test: <what was compared, result>
- Submissions: ours <regions>; Lander's Δh submission <yes/no/not checked>
- Main: <file:line on origin/main, or "not affected">
```

### Branches and campaigns

| Name used here | Branch or tag | What it is |
|---|---|---|
| main | `origin/main` at `4e5d5a1` | The shared GloGEM branch. Lander's GMIP4 Δh submissions (file prefix `GloGEM_`) were made with `main` code. All our branches split from it at `eb035d5` (2026-09-15). |
| v1 | tag `gmip4-v1` (`bb4744e`, 2026-09-24), branch `GloGEMflow` | Code of the first GloGEMflow GMIP4 campaign. The v1 runs were made from the live tree while commits were landing, so the tag is not the exact code of every v1 region. `GloGEMflow` has 13 more commits, all englacial temperature work. |
| v2 | `glogemflow-stability` (post-processing `cc70ff7`) | The tag plus 10 commits: the climate fixes G1 and G3, the speed fixes G7 and F12, main's `mass_bsl` fix (G18), the spin-up cache key (F5), the feeder (two commits) and the post-processing fixes S2 and S3. The v2 projections ran with model code `560ec9e`, fed by `b57eb3c` (a script). The 84 v2 hindcasts were launched earlier, at `8d9d040`, which has neither the `mass_bsl` fix nor the year-keyed cache; their `mass_bsl` was repaired in the combine step (`8993a0d`, S2). |
| fix rounds | `glogemflow-fixes` (rounds 1 to 5), `glogemflow-fixes-b` (second half of round 5) | Five rounds of flow-model and Δh fixes, each checked by independent reviewers (round 5: a physics and an integration review, 2026-09-29, both ready to launch). |
| newpath | `glogemflow-newpath` | Climate fixes for the regions that use the per-point climate path ("new path": NorthAsia, LowLatitudes, Antarctic). |
| v3 | `glogemflow-v3` (production) | Merge `4007872` of `glogemflow-fixes` at `bdecf06` (rounds 1 to 4) and `glogemflow-newpath` at `04a3c33`, plus script commits. NorthAsia and LowLatitudes ran with model code `4007872`. |
| v3r5 | `glogemflow-v3r5` | `glogemflow-v3` at `7a9a617` plus round 5: merges `7a41170` (`glogemflow-fixes` at `43f3584`) and `b2ed084` (`glogemflow-fixes-b` at `66e181f`), and this page. Model tree `fffbae9`, the tree both round-5 reviewers tested. Production takes it by fast-forward before Alaska, SouthernAndes, RussianArctic, Greenland and Antarctic are launched. |

### Where each region stands

| RGI | Region | Code | Status on 2026-09-29 | Known issues carried |
|---|---|---|---|---|
| 01 | Alaska | v3r5 | Not submitted. Rerun prepared with Lander's no-calving calibration; to run on v3r5 (not launched yet). | v3r5 set |
| 02 | WesternCanada | v2 | Submitted 2026-09-28. Glacier 08538 recalibrated without calving before submission. | v2 set; G12 (1 clamped glacier) |
| 03 | ArcticCanadaN | v1 | Submitted 2026-09-17 (renamed to `GloGEMflow_` 2026-09-19). Climate point from the old batch-dependent method (G4). | v1 set; G4, G11, G18 |
| 04 | ArcticCanadaS | v1 | Submitted 2026-09-23 (no marker, see below). Partly rerun after the climate-point fix (28 of 48 jobs), spin-up cache not cleared. | v1 set; G4 (partly), G18 |
| 05 | Greenland | v3r5 | Not submitted. Prepared with Lander's no-calving calibration of 23 September (frozen copy); to run on v3r5 (not launched yet). | v3r5 set |
| 06 | Iceland | v1 | Submitted 2026-09-19, corrected climate point, cleared spin-up cache. | v1 set; G18 |
| 07 | Svalbard | v1 | Submitted 2026-09-17, old climate point. At 2100 (MRI-ESM2-0 ssp585) its glaciers that run on Δh in both models hold 25.4 % less ice than in Lander's run (G4); unexplained. | v1 set; G4, G18 |
| 08 | Scandinavia | v1 | Submitted 2026-09-17, old climate point. | v1 set; G4, G18 |
| 09 | RussianArctic | v1 | Submitted 2026-09-23 (no marker, see below) with a per-batch calibration made with calving on (G16). Resubmission on v3r5 with a no-calving calibration prepared (not launched yet). | v1 set; G16, G18; G4 not recorded |
| 10 | NorthAsia | v3 | Complete and combined, output gate 0 findings. Not yet submitted. | v3 set; G3 (1 glacier), F9 (0.03 Gt of frontal ablation on land) |
| 11 | CentralEurope | v1 | Submitted 2026-09-19, corrected climate point, cleared spin-up cache. | v1 set |
| 12 | Caucasus | v1 | Submitted 2026-09-17, old climate point. | v1 set; G4 |
| 13 | CentralAsia | v2 | Submitted 2026-09-28. | v2 set; G3 (3 glaciers) |
| 14 | SouthAsiaWest | v1 | Submitted 2026-09-21, resubmitted 2026-09-23 after the combine fix S1. Corrected climate point, but partly rerun (51 of 80 jobs) with the cache not cleared; per-batch calibration. | v1 set; G4 (partly; calibration tuned to the old point) |
| 15 | SouthAsiaEast | v2 | Submitted 2026-09-28, with Lander's region-wide calibration. | v2 set |
| 16 | LowLatitudes | v3 | Complete and combined; to be submitted as is (Janosch, 2026-09-29). | v3 set; G12 (about 0.9 Gt of ice created after 2230) |
| 17 | SouthernAndes | v3r5 | Not submitted. Prepared with our own no-calving calibration merged into Matthias's file; to run on v3r5 (not launched yet). | v3r5 set |
| 18 | NewZealand | v1 | Submitted 2026-09-19, corrected climate point. 18 gate findings accepted (4 glaciers, 0.5 % of the 2300 volume, Δh regrowth, K1). | v1 set; G4 (calibration tuned to the old point) |
| 19 | Antarctic | v3r5 | Not submitted. Prepared with a full no-calving recalibration; to run on v3r5 (not launched yet). | v3r5 set |

The sets in the last column, taken from the tables at the start of sections 3 and 4:

- **v1 set:** G1, G3, G10 (negligible), G20 (time labels 1 month off), F2 (lost survey year), F5, F6, F7, F10.
- **v2 set:** G10 (negligible), G11 (undone sea-level calving, where cuts occur), F2 (lost survey year), F6, F7, F10.
- **v3 set:** F10, F11, K19.
- **v3r5 set** (the five sea-ending regions): K19. F9 (front calving), F10, F11, the ice created by G12 and G19 are fixed there.
- K1 (Δh regrowth) is in every region, ours and Lander's.

The result folders of 04 and 09 have no `SUBMITTED_GMIP4.txt` marker, although the notes say both were submitted on 2026-09-23. Janosch decided on 2026-09-25 not to rerun the submitted v1 regions, and on 2026-09-28 not to send a disclosure note about them to GlacierMIP4.

---

## 2. Overview

"In main?" says whether `origin/main` (`4e5d5a1`) still has the problem. "—" means the item is not a bug (a feature, tooling or a data choice).

| ID | Title | Part | Status | Changes results? | In main? | Commit(s) |
|---|---|---|---|---|---|---|
| {ref}`G1 <mc-g1>` | GMIP4 projections read the climate 2 (NH) or 8 (SH) months late | core | fixed | yes, large | yes | `723a862`, `dac2343` |
| {ref}`G2 <mc-g2>` | The same month shift in the CMIP6 projection branch | core | open | yes (CMIP6 runs) | yes | none |
| {ref}`G3 <mc-g3>` | ERA5 and GCM series from neighbouring grid points: step at 2025/2026 | core | fixed | yes | yes | `8d9d040`, `4b4e9e8` |
| {ref}`G4 <mc-g4>` | Climate grid point depends on how the region is split into batches | core | fixed | yes (batched runs) | yes | `78ffb9d` |
| {ref}`G5 <mc-g5>` | New climate path: lapse rate one month off; sub-monthly variability from the wrong cell and month | core | fixed | yes, large (RGI 10, 16, 19) | yes | `ba586cf`, `04a3c33`, `9f7314a` |
| {ref}`G6 <mc-g6>` | Longitudes lost after the per-cell variability re-read | core | fixed | yes (monthly non-GMIP4 runs); GMIP4 bit-identical | yes | `f129fc5`, replaced by `2c5357b` |
| {ref}`G7 <mc-g7>` | Regional ERA5 files re-read for every 0.1° cell (speed) | core | fixed | bit-identical | yes | `2c5357b`, `b139cda` |
| {ref}`G8 <mc-g8>` | Glaciers never simulated: grid-box edges and the South Orkney gap | core | fixed | yes (adds glaciers) | yes | `5dfd530` (part), `b8aa837` |
| {ref}`G9 <mc-g9>` | Δh advance scheme: division by zero turns glaciers into NaN | core | fixed | yes (affected glaciers) | yes | `d2b86d9` |
| {ref}`G10 <mc-g10>` | Δh: melting glaciers turn NaN instead of melting out | core | fixed | yes (negligible volume) | yes | `d62db11` |
| {ref}`G11 <mc-g11>` | Δh mass-conservation check; sea-level calving it undid; negative frontal ablation | core | fixed | yes (affected glaciers) | check not in main; related flaw in main | `44b688a`, `9394bb6`, `c5d5f5d` |
| {ref}`G12 <mc-g12>` | Runtime growth limiter; its first version created ice | core | fixed (ice-creation fix in round 5, v3r5) | yes (runaway glaciers) | main has no limiter | `97658ea`; `5c03128` |
| {ref}`G13 <mc-g13>` | ERA5 dynamic hindcast for GMIP4 could not run (four blockers) | core | fixed | yes (new product) | yes | `8cb4ad7`, `b71eeca` |
| {ref}`G14 <mc-g14>` | GMIP4 crashes with several GCMs per run or with subregions | core | fixed | no | yes | `00c5599`, `de63c36` (parts) |
| {ref}`G15 <mc-g15>` | Calving-flux file never written | core | fixed | no (output file only) | yes | `3465fdd` |
| {ref}`G16 <mc-g16>` | Calibrations made with calving on, used in runs without calving | calibration data | fixed for future runs | yes | — | no code; recalibrations |
| {ref}`G17 <mc-g17>` | Calibration: silent nearest-ID fallback; region-wide fallback; SSP loop | core | fixed / warning added | no (log only) | yes (silent fallback) | `cc5a13f`, `9b11fff`, `f73a7c2` |
| {ref}`G18 <mc-g18>` | `mass_bsl` written as a running total | core | fixed | yes (one output variable) | no (fixed in `86e4f4c`) | `86e4f4c` = `811cd41` |
| {ref}`G19 <mc-g19>` | netCDF drops real negative values below −98 kg as missing | core | fixed (round 5, v3r5) | yes (per-glacier values) | yes | `cc23e6e` |
| {ref}`G20 <mc-g20>` | Monthly netCDF time labels 3 (NH) or 9 (SH) months late | core | open in IDL; corrected in post-processing | no (labels only) | yes | `8993a0d`, `cc70ff7` (scripts) |
| {ref}`G21 <mc-g21>` | Buffered per-glacier netCDF writes | core | done | bit-identical | — | `748dc8d` |
| {ref}`G22 <mc-g22>` | Start year of the Δh geometry change | core | fixed | no for standard configs | edge case differs | `780520a`, `ae75e1e` |
| {ref}`G23 <mc-g23>` | "dhdt" renamed "Δh parameterisation" | core | done | no | — | `1661cac` |
| {ref}`G24 <mc-g24>` | Englacial temperature module (off in GMIP4) | core | many fixes; in progress | only with `firnice_temperature='y'` | yes (at least three of the bugs) | see entry |
| {ref}`F1 <mc-f1>` | Port of MATLAB GloGEMflow to IDL and coupling to GloGEM | flow | done | — | not in main | `baa5c7b`, `020e81e`, ... |
| {ref}`F2 <mc-f2>` | Flow → Δh handover: frozen, NaN or resurrected glaciers, lost year | flow | fixed | yes | not in main | `a473e25`, `61ac7d4`, `11ca640`, `5dfd530`, `df8bdd4` |
| {ref}`F3 <mc-f3>` | Spin-up quality gate | flow | fixed | yes | not in main | `5dfd530` |
| {ref}`F4 <mc-f4>` | Early spin-up and numerical fixes | flow | fixed | yes | not in main | `0301626`, `0ad3e88`, `aed44ba`, ... |
| {ref}`F5 <mc-f5>` | Spin-up cache: per glacier, failure markers, year key, fresh = cached, per-batch table | flow | fixed (per-batch table in round 5, v3r5) | bit-identical or yes | not in main | `196fa8c`, `5dfd530`, `560ec9e`, `830a795`, `66e181f` |
| {ref}`F6 <mc-f6>` | Flowline thickness update destroyed and created ice | flow | fixed | yes | not in main | `78e71b2`, `abaa01b`, `3e2b9d8` |
| {ref}`F7 <mc-f7>` | Flowline mass budget did not close; unreported outflow | flow | fixed | yes | not in main | `3d3c9cc`, `cbb3c5a`, `eaac031`, `41f39e4` |
| {ref}`F8 <mc-f8>` | Deviations from the MATLAB model fixed in rounds 2 to 4 | flow | fixed | yes | not in main | `89f7b71`, `eff52b8`, `65dfc68`, `1a83285`, `b6816be`, `23c8397`, `b0287ce` |
| {ref}`F9 <mc-f9>` | Glaciers ending in the sea: calving at the grid end and at the front | flow | fixed (grid end in v3; front calving and sea test in round 5, v3r5) | yes | not in main | `bdecf06`; `fee563e`, `b7ac6c5` |
| {ref}`F10 <mc-f10>` | Spin-up verdict depends on host load (180 s wall-clock limit) | flow | fixed (round 5, v3r5) | yes | not in main | `43f3584` |
| {ref}`F11 <mc-f11>` | Kept spin-up state and A_flow disagree when the volume search does not converge | flow | fixed (round 5, v3r5) | yes (small) | not in main | `9a4b047` |
| {ref}`F12 <mc-f12>` | Speed: skip ice-free flowlines; vectorised SIA | flow | done | bit-identical | not in main | `0d44bad`, `07d306a` |
| {ref}`F13 <mc-f13>` | Flowline velocity for the temperature model | flow | done | temperature only | not in main | `a9cb358`, `5b1aa21`, `4b80a07` |
| {ref}`F14 <mc-f14>` | Log says "falling back to Δh" when the glacier stays on flow | flow | fixed (round 5, v3r5) | no (log only) | not in main | `b4589c2` |
| {ref}`S1 <mc-s1>` | Combine counted batches twice (`GloGEM_` and `GloGEMflow_` files) | scripts | fixed | submission files | — | `a6037e2` |
| {ref}`S2 <mc-s2>` | Combine and gate for v2: completeness, `mass_bsl` repair, month restamp | scripts | fixed | submission files | — | `8993a0d` |
| {ref}`S3 <mc-s3>` | GMIP4 format: time bounds, whole calendar years, NaN-aware gate | scripts | fixed | submission files | — | `cc70ff7` |
| {ref}`S4 <mc-s4>` | Regional temperature: NaN when ice-free; weighted by current instead of initial area | scripts | fixed | submission files | — | `126d571`, `ae936f2` |
| {ref}`S5 <mc-s5>` | Output gate `check_gmip4_output.py` | scripts | done | — | — | `5dfd530`, `bb4744e`, `8993a0d`, `cc70ff7` |
| {ref}`S6 <mc-s6>` | Combine scripts, hindcast combiner, config generator, v3 regions | scripts | done | — | — | `de63c36`, `3bae19c`, `5bf98de`, `ca74f02` |
| {ref}`S7 <mc-s7>` | Launchers and watchers: lost, killed and overwritten jobs | scripts | fixed | — | — | `24d6a06`, `de63c36`, `f44e013`, `ae1a1e6` |
| {ref}`S8 <mc-s8>` | Campaign feeders: order, stagger, pre-flight, `.done` check | scripts | done | — | — | `61209b3`, `b57eb3c`, `e5629c2`, `44b6099`, `309ce36` |
| {ref}`S9 <mc-s9>` | Run logs off the home quota (`GLOGEM_LOGDIR`) | scripts, `glogem.pro` | done | no | — | `2196916` |
| {ref}`K1 <mc-k1>` | Δh advance scheme can regrow glaciers without bound | core | known, accepted | — | yes | none |
| {ref}`K2 <mc-k2>` | GMIP4 GCM files are bias-corrected on the annual mean only | input data | open | — | yes | none |
| {ref}`K3 <mc-k3>` | The 1939 months: zeros in the hindcast, GCM values in projections | core | known, accepted | — | yes | none |
| {ref}`K4 <mc-k4>` | Hindcast starts geometry change in the survey year, projections a year later | core | known, accepted | — | yes | none |
| {ref}`K5 <mc-k5>` | Geometry held fixed before the survey year while the balance is reported | core | by design | — | yes | none |
| {ref}`K6 <mc-k6>` | Remaining deviations from the MATLAB model | flow | open | — | — | none |
| {ref}`K7 <mc-k7>` | ELA bias clamped at ±500 m instead of rejected | flow | known, accepted | — | — | none |
| {ref}`K8 <mc-k8>` | Positive-balance glaciers at the calibration bounds | calibration | known, accepted | — | — | none |
| {ref}`K9 <mc-k9>` | Low flow share: a quarter of glaciers fall back after spin-up failure | flow | open | — | — | none |
| {ref}`K10 <mc-k10>` | 30 % year-to-year blow-up check mostly hits small melting glaciers | flow | open, low | — | — | none |
| {ref}`K11 <mc-k11>` | Rebuilt elevation bands overstate glacier area; head-cell leak | flow | open | — | — | none |
| {ref}`K12 <mc-k12>` | Ice-melt and snow-melt labels swapped in the `.dat` output | core | open | — | yes | none |
| {ref}`K13 <mc-k13>` | The flow model silently does not run in runs ending before 2026 | core, flow | open | — | yes (the settings rule) | none |
| {ref}`K14 <mc-k14>` | An `@` include after `if ... then` guards nothing | core | open | — | no (only in our temperature code) | none |
| {ref}`K15 <mc-k15>` | NorthAsia: 57 glaciers outside every subregion box | core | known, accepted | — | yes | none |
| {ref}`K16 <mc-k16>` | GCM ring search: missing directory hangs the job | core | open | — | yes | none |
| {ref}`K17 <mc-k17>` | Smaller output issues (model attribute, stale band elevations) | output | open | — | partly | none |
| {ref}`K18 <mc-k18>` | Debug `stop` and editor backup files on main | main only | open | — | yes | `70c5af5` |
| {ref}`K19 <mc-k19>` | Kept spin-ups lean towards too-short glaciers; A_flow floor; no upper length limit in the gate | flow | open, to be disclosed | — | — | none |

---

## 3. Core GloGEM items

These items are in code that is also on `main`, except where noted. For each one the entry says whether our submissions and Lander's Δh submission carry the problem. In short:

| ID | v1 submissions (03 04 06 07 08 09 11 12 14 18) | v2 submissions (02 13 15) | v3 (10 16) | Lander's Δh submission |
|---|---|---|---|---|
| G1 month shift | carry it | fixed | fixed | carries it (confirmed) |
| G3 seam grid point | carry it | fixed (3 CentralAsia glaciers remain) | fixed (1 NorthAsia glacier remains) | carries it (confirmed on one glacier) |
| G4 batch-dependent point | 03 07 08 12 carry it; 04 and 14 partly rerun; 06 11 18 fixed; 09 not recorded; 14 and 18 use per-batch calibrations tuned to it | fixed | fixed | not affected (whole-region runs) |
| G5 new-path climate | not applicable | not applicable | fixed | not checked |
| G9 advance-scheme NaN | none triggered | none triggered | fixed | not checked |
| G10 melt-out NaN | carry it (negligible) | carry it (negligible) | fixed | not checked |
| G11 undone sea-level calving | 03 carries it | carry it where cuts occur | fixed | not affected |
| G16 calving calibration | 09 carries it | 02 fixed before submission | fixed | not checked |
| G18 `mass_bsl` running total | 03 04 06 07 08 09 carry it | fixed | fixed | likely, not checked |
| G20 monthly time labels | 1 month off as combined then | fixed in post-processing | fixed in post-processing | not checked |

v3r5, with which the five sea-ending regions run, has every fix of v3 and in addition G19 and the fix of the ice G12's limiter created.

(mc-g1)=
### G1. GMIP4 projections read the climate 2 (NH) or 8 (SH) months late

- **What was wrong.** `glogem.pro` looks up the first model month at `ye-1+tran[0]`: October (April in the southern hemisphere) of the year before `tran[0]` (`glogem.pro:423` on main). The reanalysis branch of `downscale_gcmdata_monthly.pro` labels its series from `tran[0]-1`, as expected. The GMIP4 projection branch labelled it from `tran[0]` (`:221` on main), so the lookup returned −1 and every month read `temp[ccmon-1]`; the very first month read `temp[-1]`, the last element of the series. In the northern hemisphere every month got the climate of two months later. Where the hydrological year starts in April, every month got the climate of eight months later, which moves the seasonal cycle by −4 months. In addition, 1940 was taken from the GCM instead of ERA5 (`gt min_ryear`, `:234`).
- **Origin.** Lander's `32da34c` and `ca81a6f` (2026-06-04), on main. The day before, `cb01fa3` (Lander, 2026-06-03) still had it right.
- **How it was found.** 2026-09-24, while mapping the code for the thermal spin-up; checked by an adversarial review and by running Lander's working copy. With geometry frozen, glacier runoff peaked in May–June instead of July–August in CentralEurope, and in April–July instead of January–March in NewZealand.
- **Effect.** Projections did not reproduce the calibrated mass balance. 1990–2020 mean balance with the same ERA5 forcing, hindcast against projection, in m w.e./yr:

  | RGI | Region | Hindcast (aligned) | Projection (shifted) | Volume change 2000–2025, hindcast vs projection |
  |---|---|---|---|---|
  | 11 | CentralEurope | −0.574 | −0.533 | −37.8 % vs −36.1 % |
  | 06 | Iceland | −0.094 | −0.105 | −4.8 % vs −4.3 % |
  | 18 | NewZealand | −0.457 | −0.238 | −24.0 % vs −20.0 % |
  | 15 | SouthAsiaEast | −0.626 | −0.140 | −19.6 % vs −10.5 % |

  The effect is small where the shift largely cancels over the year and large in monsoon regions. In a RussianArctic batch, the aligned climate gave 67 % more melt and 50 % less refreezing. Every spin-up cached in a projection job was built on the shifted climate, so those caches are invalid too (the spin-up uses the run's own 1961–1990 balances).
- **Fix.** `723a862` (v2, v3; old climate path): the series starts at `tran[0]-1`, and ERA5 is used from its first year on (`ge min_ryear`). `dac2343` (v3; new climate path, `downscale_gcmdata_monthly_new.pro`): the same fix. Changing only the start year would not have worked on the new path: without the lower bound, 1939 found no ERA5 row and the series still began in January 1940.
- **Test.** Old path: the runoff seasonal cycles of projection and hindcast now agree (offset 0.00 percentage points, against 20.6 and 30.9 before), and an independent review found an offset of 0 months in both hemispheres over 1940–2300. New path, flow off, projection against hindcast 1942–1995: NorthAsia Altay (74 glaciers) seasonal cycle identical (old code 34.66 percentage points off), balance −0.1311 (old −0.1672) m w.e./yr; LowLatitudes Andes (64 glaciers) −0.4138 (old −0.2954); 6 Andes glaciers differ only in 1946, by at most 0.040 m w.e., from snow carried over from the 1939 months (K3).
- **Submissions.** All v1 regions carry it. v2 and v3 are fixed. Lander's Δh projections carry it (the same shift is visible in his submitted files). Hindcasts and calibrations are not affected. Janosch informed Lander on 2026-09-24; on 2026-09-25 he decided that the Δh submissions and our v1 submissions are not rerun.
- **Main.** Still wrong: `downscale_gcmdata_monthly.pro:221/226/234` (GMIP4, old path) and `downscale_gcmdata_monthly_new.pro:224/229/237` (new path).

(mc-g2)=
### G2. The same month shift in the CMIP6 projection branch (open)

- **What is wrong.** The CMIP6 branch of both downscaling files labels the series from `tran[0]` and takes 1940 from the GCM (`gt min_ryear`): `downscale_gcmdata_monthly.pro:126/138` and `downscale_gcmdata_monthly_new.pro:130/142` in v3 (`:125/130/137` and `:130/135/142` on main). It came with Lander's `fafda41` (2026-06-25, "Similar implementation as for GMIP4 now for CMIP6").
- **Status.** Deliberately left unchanged by `723a862` because GMIP4 does not use it and it was not tested. It is wrong on every branch and on main, and affects every CMIP6 projection run, including the CMIP6 runs of the englacial temperature work.
- **What is needed.** A fix of the same kind as `723a862` in both files, tested by comparing projection and hindcast over the ERA5 period.

(mc-g3)=
### G3. ERA5 and GCM series from neighbouring grid points: a step at 2025/2026

- **What was wrong.** A GMIP4 projection splices ERA5 (to 2025) and the GCM series (from 2026) into one monthly series. ERA5 came from the grid point nearest the centroid of the cell's glaciers (`downscale_gcmdata_monthly.pro:21-24`), the GCM file from a ring search around the 0.1° cell centre (`read_gcmdata_monthly.pro:57,72`). When the two fell on opposite sides of a 0.25° midline, they came from neighbouring grid points, and both were lapse-rated from the ERA5 point's elevation. The GMIP4 GCM files are bias-corrected per grid point, so the series jumps at the seam by the difference between the two points' climates.
- **Origin.** `ca81a6f` (Lander, 2026-06-04), on main.
- **How it was found.** 2026-09-25, while testing SouthernAndes runaway glaciers after the month fix. SouthernAndes 11787 (Δh, MRI-ESM2-0): input temperature 3.9 °C in 2025, −0.5 °C in 2026 (the GCM point is 573 m higher); balance −0.7 → +6.8 m w.e./yr; volume 1.1 → 15 km³ by 2100 under ssp585, identical in Lander's submission.
- **Effect.** Replay of the grid-point choice over all 16 GMIP4 regions (MRI-ESM2-0, 1995–2014 means): 8–14 % of cells were mismatched. The fix moves the seam temperature by more than 1 °C for 0.3–7 % of a region's ice volume (SouthernAndes 7.0 %, Greenland 6.1 %, NewZealand 4.6 %, CentralAsia 4.5 %, Alaska 3.3 %), single glaciers by up to 12.6 °C (SouthAsiaEast). The regional mean shift is near zero.
- **Fix.** `8d9d040` (v2, v3; old path): the GCM search starts at the ERA5 point (`gcm_start`). `4b4e9e8` (v3; new path): the ERA5 reader records the grid point it read (`era5_pt`) and the GCM search starts there.
- **Test.** SouthernAndes 11787 ssp585 2100: 15.04 → 0.14 km³ (melts out in 2150); 14544: 29.88 → 1.58 km³. CentralEurope batch05 (MRI-ESM2-0 ssp126, flow on): exactly the 8 glaciers in mismatched cells change, the other 162 are byte-identical. New path: the replay predicted 16 Antarctic glaciers (8.7 % of the region's 3,991 km³; MarieByrd step up to 3.2 °C), 16 LowLatitudes glaciers (0.3 %) and 7 NorthAsia glaciers (0.1 %) for 4 of the 8 GCMs; in the tests exactly the predicted glaciers changed, and only in 1940 and 2026–2300.
- **Left over.** 3 CentralAsia cells have no GCM file at the ERA5 point (+1.2 °C at the seam for 3 glaciers, in submitted RGI 13). One NorthAsia glacier on the date line has no GCM file at longitude 180.00 and still takes a neighbouring point. See also K16.
- **Submissions.** All v1 regions carry it; v2 and v3 are fixed. Lander's projections carry it.
- **Main.** Still wrong. For merging, `8d9d040` needs G4 (`78ffb9d`) and G7 (`2c5357b`) first.

(mc-g4)=
### G4. The climate grid point depended on how the region was split into batches

- **What was wrong.** `read_climate_series.pro` took the ERA5 point from the centroid of those glaciers of the 0.1° cell that are in the current run. Splitting a region into batches (with `catchment_selection`) therefore changed the climate series, its reference elevation `hclim` and the lapse rates of the same glacier.
- **How it was found.** 2026-09-15, tracing CentralEurope 02195: a centroid shift of 0.0056° flipped the nearest ERA5 row. With the cell fragment of our batch the glacier had 10.297 km³ in 2300, with the whole cell 0.447 km³ (Lander's whole-region run: 0.476 km³). Batching split 99.1 % of CentralEurope's multi-glacier cells (318 of 321).
- **Effect.** Summed 2100 volume (MRI-ESM2-0 ssp585) against Lander's whole-region Δh run, for glaciers on Δh in both: CentralEurope +91.7 %, Scandinavia +3.0 %, Caucasus −1.3 %, ArcticCanadaN −0.7 %, Svalbard −25.4 %. The Svalbard gap is not explained: an earlier check that Lander's Svalbard run had calving off relied on its calving-flux file, which is never written (G15), so calving is not ruled out as the cause. Our per-batch calibrations of 27 August were tuned to this climate. After the fix, submitted SouthAsiaWest has 35.5 % and NewZealand 19.8 % of their ice with a temperature offset more than 1 °C away from a batch-independent calibration. In SouthAsiaEast it was the trigger of runaway glaciers (temperature offset 0–0.5 °C in our calibration against 5.4–6.5 °C in Lander's).
- **Fix.** `78ffb9d` (all branches; in production since 2026-09-15): `glogem.pro` keeps a snapshot of the whole-region inventory (`xy_clim`) before `catchment_selection` narrows it, and the grid cell's glaciers are taken from that snapshot.
- **Test.** CentralEurope batch15 against Lander's reference: +1270.8 % before, −0.2 % after. The three test catchments around 02195 all give 0.4465 km³ regardless of membership.
- **Submissions.** See the table at the top of this section. A climate change invalidates cached spin-ups; 04 and 14 were only partly rerun with the cache not cleared. For SouthAsiaEast (v2) we switched to Lander's region-wide calibration.
- **Main.** Main has the same code (`read_climate_series.pro:64`); it matters whenever a region is run in batches.

(mc-g5)=
### G5. New climate path: lapse rate one month off; variability from the wrong cell and month

The per-point climate path (`new='y'`, used for NorthAsia, LowLatitudes and Antarctic; Lander's `b5aa086`, `8eeef31`, `eb035d5` on main) had four more bugs besides G1 and G3. They were found on 2026-09-27 while preparing these regions.

- **Lapse rate one month late.** `gradient_variability_monthly.pro` took `dtdz[1:12]` from the point file's dT/dz column, which starts in January 1940, so element 1 is February: every month used the next month's lapse rate. The error was up to 2.81 K/km (median 0.66) in NorthAsia, 0.55 (0.12) in LowLatitudes and 1.28 (0.44) in Antarctic. `ba586cf` fixed the month. `04a3c33` then replaced the point-file lapse rate with the gridded `tgrad` file at the cell nearest the ERA5 point, read by calendar month with the same code as the old path (Janosch's decision, 2026-09-28). The point file and the grid differ by 1–2 %, which shifted balances by up to 0.036 m w.e./yr in Altay, and every existing calibration used the grid.
- **Variability from the wrong cell and month.** The variability cell was chosen with `where(rlat eq rmid[0])` and `where(rlon eq rmid[1])`, but on this path `rmid` is `[lon, lat]`, it is not a grid value, and the re-read grid kept 0..360 longitudes, so nothing ever matched. The month list `mtt` was only set on the old path. All three indices were −1, which IDL reads as the last element: every month of every glacier got December's variability from the last row and column of the subregion grid (Andes: 295.5E/13.25N in Venezuela; Altay: 120E/59.5N). `9f7314a` sets `mtt` and takes the cell nearest the ERA5 point, comparing longitudes modulo 360.
- **Effect.** Hindcast mean balance 1942–1995, flow off, same calibration: Altay −0.1311 → −0.1033 (lapse rate) → −0.0692 m w.e./yr (variability); Andes −0.4138 → −0.4094 → +0.9614. Andes 2000–2019: −1.264 → −0.427 m w.e./yr against a geodetic target of −0.210.
- **Test.** `04a3c33`: new path against the old gridded path forced on the same catchment, 2000–2019 mean balance per glacier: largest difference 0.0050 (Altay, 74 glaciers) and 0.0067 m w.e./yr (Andes, 62 of 64; the other 2 sit in the one cell where the two paths choose a different ERA5 point). Old path unchanged: Greenland test catchment, all 19 text outputs byte-identical.
- **Calibrations.** On a 64-glacier Andes sample, recalibrating on the fixed path reproduced Matthias's parameters closely (temperature offset median difference −0.06 °C, max 0.88 °C). For the whole regions, however, the reviewers found that Matthias's LowLatitudes file gives about −0.55 against a target of −0.21 m w.e./yr in the Andes with the fixed code, partly because those July calibrations used a whole-region cell grid that is offset from the subregion boxes (739 Andes glaciers, 20 % of the volume, read a different point). Lander's Antarctic Atlantic calibration was made on the buggy path (−1.01 against a target of −0.67). Janosch decided on 2026-09-28 to recalibrate LowLatitudes and Antarctic completely, without calving. Lander's own LowLatitudes and Antarctic ERA5 hindcast files do not match his projections; he should be told.
- **Submissions.** Only v3 runs these regions (10 and 16 so far). Whether Lander's submissions for these regions carry the bugs has not been checked.
- **Main.** Still wrong: `gradient_variability_monthly.pro:29` (`dtdz=dtdz[1:12]`) and `:90-100` (the lookup).

(mc-g6)=
### G6. Longitudes lost after the per-cell variability re-read (a bug from main's `eb035d5`)

- **What was wrong.** Since `eb035d5` (Lander, 2026-09-15; merged into our branch in `e45574a`), `gradient_variability_monthly.pro` re-reads `rlon`/`rvlon` from the climate file in every grid cell, without the conversion of longitudes ≥ 180 to negative values that `read_climatepast_monthly.pro` applies. From the second cell on, glaciers west of 0° were then matched against 0..360 longitudes and always got the region's westernmost ERA5 column: temperature, precipitation, `hclim`, lapse rates and variability from the wrong place (Alaska: 181.5E for every glacier).
- **Which runs.** Monthly runs with `submonth_variability='y'` (the default) and a MIP other than GMIP4 or AMOC, i.e. the default CMIP6 setup and every `config_cali_*.pro`. GMIP4 re-read the file with the conversion per cell and was not affected.
- **How it was found.** 2026-09-24, while removing the re-reads (G7). A 2-year Iceland run (92 cells): cell 1 used −23.25 E, cells 2–92 all 333.75 E (= −26.25 E) for glaciers at −21 to −14 E.
- **Fix.** `f129fc5` (all branches) converts the re-read longitudes. `2c5357b` then removed the old-path re-read altogether, so the fix lines are gone and the behaviour equals the fix. GMIP4 output bit-identical (20 files).
- **Submissions.** None of our runs was affected.
- **Main.** Still has the bug (`gradient_variability_monthly.pro:47,79`). Any monthly run or calibration made with main code after 2026-09-15 on the old climate path with MIP not GMIP4/AMOC is suspect.

(mc-g7)=
### G7. The regional ERA5 files were re-read for every 0.1° cell (speed)

- **What was wrong.** For every 0.1° cell of every GCM run, `read_climate_series.pro` re-ran `read_climatepast_monthly.pro` and `gradient_variability_monthly.pro` re-read the climate and variability files, although `glogem.pro` already reads the same arrays once per region and nothing modifies them: 170 GB to 1.5 TB of ASCII per GCM run, 70–95 % of the job runtime (cost model fitted to about 200 jobs, within ±15 %).
- **Fix.** `2c5357b` (v2, v3): no re-read on the old path (AMOC still reads per cell because it skips the region-level read). `b139cda` (v3): the same for the new path, whose re-read restored nothing that path uses.
- **Test.** Byte-identical output. CentralEurope 6.2× faster; together with F12, WesternCanada 29× faster. New path: 19 files byte-identical, hindcast 73 → 35 s per 5 cells.
- **Not done.** 1940–2025 is still computed again in each of the 28 GCM/SSP runs (a 2025 checkpoint would save about 25–50 % of the remaining time).
- **Main.** Still re-reads (`read_climate_series.pro:59`, `gradient_variability_monthly.pro:36-88`). For merging it is simplest to take v3's `gradient_variability_monthly.pro` as a whole (44 lines) instead of the six separate commits.

(mc-g8)=
### G8. Glaciers that were never simulated

- **Grid-box edges.** `setup_grid_loops.pro` built the lower box bound with `fix()`, which truncates towards zero, so for negative coordinates the box could start up to 0.1° east or north of the westernmost or southernmost glacier. `glogem.pro` selected glaciers with strict `gt`/`lt` against cell edges computed by two slightly different float expressions, so a glacier exactly on an edge fell through both cells. Found 2026-09-08: batch outputs missed glaciers of their catchment files (ArcticCanadaN 4 of 5,216, ArcticCanadaS 7 of 11,009, SouthAsiaWest 2 of 37,562, SouthAsiaEast 1 of 18,587), among them ArcticCanadaN 02574 (76 km², 4.6 km³). Fix (in production 2026-09-08, committed in `5dfd530`, all branches): `floor()` for the lower bounds, half-open cells `[lo, hi)` built from one expression, and `ge`/`le` in the netCDF glacier count. The climate cell of every other glacier is unchanged. The `fix()` truncation loses at most the westernmost or southernmost glacier of a whole-region run, and batching multiplies that. The strict-edge test can drop any glacier that sits exactly on a cell edge, depending on float rounding (SouthAsiaEast 05759 at longitude 85.450001), in whole-region runs too. All v1 regions were rerun after this fix.
- **South Orkney gap.** Each Antarctic subregion runs the glaciers inside the box of its ERA5 grid. The Atlantic box was cut at 60.5 S (`glogem.pro:132` on main) while the Peninsula box ends at 60.8 S, so the 130 South Orkney glaciers (115 with ice, 548 km², 37 km³) were in no subregion and missing from every Antarctic result. `b8aa837` (v3) starts the Atlantic box at 60.8 S. A replay of the box selection puts all 2,742 Antarctic glaciers in exactly one box; the Atlantic hindcast now has 115 output rows instead of 0. Found 2026-09-27.
- **Left over.** 57 NorthAsia glaciers are still outside every box (K15).
- **Main.** Both are still in main (`setup_grid_loops.pro:15-16,22-23`; `glogem.pro:253-260,277-283`; `glogem.pro:132`).

(mc-g9)=
### G9. Δh advance scheme: a division by zero turned glaciers into NaN

- **What was wrong.** When a glacier's inventory minimum elevation is below −90 m, `read_hypsometryfile.pro:53-55` adds no advance bands (`adv_addband = 0`). `initialise_advance_scheme_vars.pro:16` then divides by `adv_addband/2` and gives every empty band in front of the glacier an infinite "hypothetical" area. The first time the advance scheme fires (`glacier_retreat.pro:92`), area = Inf × 0 = NaN: the glacier is NaN for the rest of the run, drops out of every regional sum, and its infinite initial area makes the batch netCDF temperature NaN (Inf/Inf).
- **How it was found.** 2026-09-26/27, verifying the v2 output. SouthernAndes 08479 (224 Gt) was NaN from 2004 in all 28 projections; Alaska 15293 (about 22 Gt) and 26023 also; every Alaska and SouthernAndes monthly file had NaN temperature. Armed but not triggered: 10 Greenland glaciers (88 km³), 5 Antarctic, 2 more in Alaska.
- **Fix.** `d2b86d9` (v3): without added bands the front-area amplification stays 1; the mass check (G11) also reverts non-finite geometry; the netCDF writer replaces a non-finite initial area by the sum of the finite bands.
- **Test.** 08479 finite (252.5 km³ at its peak, 204.1 km³ in 2100); Alaska 15293 and 26023 finite; batch monthly temperature NaN in 4,332 of 4,332 months → 0. Runs that never reach the advance branch are bit-identical (40 SouthernAndes batch08 glaciers and others).
- **Submissions.** None of the submitted regions triggered it. Lander's files not checked.
- **Main.** Legacy code, still in main (`initialise_advance_scheme_vars.pro:16`). The one-line root fix applies to main on its own.

(mc-g10)=
### G10. Δh: glaciers turned NaN instead of melting out

- **What was wrong.** When a glacier with five or more ice bands loses everything in one year except its top band, the mass-conservation step of `glacier_retreat.pro:152-153` divides by `total(dh*area)`, and the top band has dh = 0 for small (< 5 km²) and large (> 20 km²) glaciers. Volume became NaN for the rest of the run while a leftover band area stayed frozen. In the same year, `meltmodel.pro` and `calculatedebrismelt.pro` divided by a glacier area of 0 (0/0).
- **Effect.** About 10,000 glacier-runs in v2 (all regions), at most 0.06 km³ each: negligible for regional sums.
- **Fix.** `d62db11` (v3): the division only runs when `total(dh*area) ne 0` (`ne`, not `gt`, because in an advance year the sum is negative and must keep its behaviour); otherwise the correction is spread over the remaining top band(s) and the glacier melts out. The melt normalisations are guarded with `ar_gl ne 0`.
- **Test.** SouthernAndes 01045, 26615, 22634 and Alaska 26469 now melt out to 0 volume and area within 1–4 years. Of 43 SouthernAndes batch08 glaciers, only the three with this bug change, two more change only in their one NaN melt year, and 38 are bit-identical.
- **Main.** Still in main (`glacier_retreat.pro:152-153`; `meltmodel.pro:53,60,76,85,94,107`; `calculatedebrismelt.pro:57`). Applies cleanly.

(mc-g11)=
### G11. Δh mass-conservation check, the sea-level calving it undid, and negative frontal ablation

- **The check.** `44b688a` (all branches, 2026-09-15). The correction that makes the Δh redistribution match the volume change divides by `total(dh*area)`, which tends to zero on a remnant and then amplifies instead of correcting. Scandinavia 00447 (CESM2-WACCM ssp585) jumped from 0.014 to 0.093 km³ in 2078 and became a 569 m thick stub at 2985 m, above its own ELA, ending 2099 at 0.684 km³ against 0.016 km³ in the pure-Δh reference. Our output gate caught it. The new check compares the realised volume change with the balance (tolerance 5 % of the volume plus 0.05 million m³); on failure it restores the geometry of the start of the year and applies the balance as uniform thinning with the area fixed. 00447: 0.684 → 0.065 km³ in 2099; 00012 bit-identical. This is a partial fix: 00447 still ends about 4× the reference and its band elevations still reach about 3000 m (K1).
- **Sea-level calving undone.** `glacier_retreat.pro` cuts off bands whose surface is below sea level and books their ice as frontal ablation (`flux_calv`). The new check compared the volume change with the surface balance only, so in every year with a sizeable cut it reverted the geometry: the ice stayed, while the calving was still reported. ArcticCanadaN 01236 reported about 29 m w.e./yr (2.8 Gt/a) of calving every year from 2011 while its volume followed the surface balance; this one glacier contributed +1.26 Gt/a to the region's 2000–2019 hindcast budget residual of +0.90 Gt/a. `9394bb6` (v3) measures the calving as the ice actually removed, lets the check expect the balance minus that calving, and sets the calving to 0 if the check still reverts. Test: 01236 residual +1.2435 → 0.0000 Gt/a, 2025 volume 8.95 → 6.16 km³; 43 SouthernAndes glaciers: volume and area bit-identical.
- **Negative frontal ablation.** For the partly cut band, the area came from the area–thickness scaling, which can exceed the area before the cut, so the band gained ice; since `9394bb6` that showed up as negative frontal ablation (14578: −1.776 m w.e. in 2193; 14571: 5 negative years, −0.30 Gt). GMIP4 requires frontal ablation ≥ 0. `c5d5f5d` (v3) sets the band thickness so that exactly the planned amount `q_calv` is removed. Test: 39 of 43 SouthernAndes glaciers bit-identical, no negative values left, total frontal ablation 2.191 → 2.476 Gt.
- **Submissions.** Submitted ArcticCanadaN (03) carries the undone calving, and so does v2 where sea-level cuts occur. The negative frontal ablation only appeared with `9394bb6`, which is on the fixes branch and was fixed by `c5d5f5d` before v3, so no submission carries it. Lander's runs are not affected (no mass check on main).
- **Main.** Main has no mass check, so the undone calving never happened there. It has a related flaw: `glacier_retreat.pro:174` reports the planned `q_calv`, while the area rescale at `:188-190` can leave a different amount of ice. The chain `44b688a` → `d2b86d9` → `d62db11` → `9394bb6` → `c5d5f5d` applies cleanly on main, but porting `44b688a` changes main's behaviour (it reverts and thins in years that fail the check), so it needs a decision.

(mc-g12)=
### G12. Runtime growth limiter, and the ice its first version created

- **Why.** Nothing bounded a glacier's size during a run; runaways were only caught afterwards by the output gate. SouthAsiaEast came back with 24 glaciers holding 35.7 % of the 2300 ice, one at 261 km³ and 4.7 km mean thickness.
- **Limiter.** `97658ea` (all branches, 2026-09-22), new `limit_glacier_growth.pro`: every year, on both the flow and the Δh path, a glacier whose mean thickness exceeds 2000 m, or whose volume exceeds 50 km³ and 20× its inventory volume, is scaled back onto the limit (`growth_max_thick`, `growth_max_vol`, `growth_max_rel` in `settings.pro`; the same thresholds as the output gate). ArcticCanadaN 07801: 259.3 → 58.7 km³.
- **Bug in the limiter.** Found 2026-09-29 while checking LowLatitudes v3. The first clamp rebuilt band areas from `area_ini*(thick/thick_ini)^(1/expon)`, which on thin-footprint ice pillars multiplied area and volume in one year: five one-year jumps after 2230, about 0.9 Gt of created ice (00042: 0.056 → 0.430 km³). It also overwrote the start-of-year volume and area, clamped only the band copy in flow years, and booked the removed ice nowhere.
- **Fix.** `5c03128` (round 5, v3r5): the limit only thins and keeps the area; in flow years it thins the flowline before the bands are rebuilt; the removed ice is booked as ice melt (annual, monthly and runoff); start-of-year values are no longer overwritten. Test: without the change the production output is reproduced exactly (1,080 rows); untouched glaciers byte-identical; the five jumps are gone; residual at most 0.035 Mt per clamp year.
- **Submissions.** Most v1 runs predate the limiter. v2 and v3 have the first version; the gate tolerated 1 clamped glacier in WesternCanada (02) and 9 in SouthernAndes v2 (not submitted), not checked for created ice. LowLatitudes (16), with its five jumps, is to be submitted as is (Janosch, 2026-09-29).
- **Main.** Main has no runtime bound (`glogem.pro:549-551` calls only `glacier_retreat`). The first version (`97658ea`, the one in v3) uses only variables that main has. The fixed version of `5c03128` does not: its `limit_glacier_growth.pro:29` reads `lg_flow = use_flow_model_gl eq 'y' and n_elements(flow_initialised) gt 0`, and main defines neither variable, so that version needs a guard (for example `lg_flow = 0` when `use_flow_model_gl` is undefined) before it can go to main. The thresholds in our `settings.pro` sit inside the spin-up gate comment and should be moved.

(mc-g13)=
### G13. The ERA5 dynamic hindcast for GMIP4 could not run

GMIP4 asks for an ERA5 hindcast (2000–2025) next to the projections. The dynamic hindcast path had never been run and had four blockers (found 2026-09-18):

- `settings.pro` kept `hindcast_dynamic='n'`, and the dynamics guard switched it off for `tran[1] > 2020` although ERA5 now runs to 2025;
- `check_tran.pro` applied the GCM end year to every run and rewrote a 2000–2025 hindcast to 2300, producing a valid-looking 301-year netCDF of made-up years;
- the folder `PAST_original/dyn` was never created;
- the hindcast file name used `nc_gcm_tag`, which only projection runs define.

`8cb4ad7` (all branches, 2026-09-22) sets `hindcast_dynamic='y'` for GMIP4, keeps a reanalysis run's own `tran`, moves the guard to `tran[1] > 2025` and creates the folder. `b71eeca` drops the GCM tag from hindcast file names and names flow runs `GloGEMflow_*` (derived from `use_flow_model`). The hindcast runs from 1940, because firn starts at zero and needs the first years to build up. All our submitted regions now include the hindcast. On main all four blockers are still there (`check_tran.pro:9-25`, `settings.pro:417`, `setup_output_folders.pro:32`, `init_netcdf_hindcast.pro:102-105`); the file-name switch of `b71eeca` reads `use_flow_model`, which main does not have.

(mc-g14)=
### G14. GMIP4 crashes with several GCMs per run or with subregions

- `00c5599` (part, all branches): for GMIP4, `rcp_batch` was a scalar (`rcp_batch = 3`, a regression from a merge of main) and is now `intarr(8)+3`. The scalar crashes as soon as the GCM loop advances past the first model. Main still has the scalar (`settings.pro:333`).
- `de63c36` (part, all branches): the region-setup read of the GCM file in `glogem.pro` now runs only for CMIP6. With subregions and GMIP4 it crashed with "Variable is undefined" in LowLatitudes and Antarctic forward runs. Main still reads it for every MIP (`glogem.pro:130`, inside the block for monthly runs with a climate subregion).

Runs that worked before are unchanged.

(mc-g15)=
### G15. The calving-flux file was never written

`calving_model.pro:65` wrote a glacier's frontal ablation to `*_calving_flux.dat` only `if ye eq tran[0]`, comparing the year index (0, 1, ...) with the calendar start year (1940). That is never true, so the file only ever held its header. This is how our v1 and v2 configs came to "confirm 0 calving-flux rows" for calibrations that were in fact made with calving on (G16). `3465fdd` (v3) writes it in the first model year (`ye eq 0`), for forward runs only (the file unit is only opened there). Period-mean calving flux unchanged (1.4035 Gt/a); only the file content changes. Still in main.

(mc-g16)=
### G16. Calibrations made with calving on, used in runs without calving

- **What was wrong.** The flow model has no calving term, so our flow runs use `frontal_ablation='n'` (rule of 2026-08-28). The calibration files we used for Alaska, SouthernAndes and WesternCanada (Matthias's global calibration), and the per-batch calibration of the submitted RussianArctic run, were made with `frontal_ablation='y'`, so their surface balance equals the geodetic target plus the calving flux (capped at 2 m w.e./yr). Used without calving, that share of the loss is missing.
- **Effect.** Share of the target mass loss that the calibration treated as calving:

  | RGI | Region | Treated as calving |
  |---|---|---|
  | 01 | Alaska | 28.4 of 66.0 Gt/a (43 %) |
  | 17 | SouthernAndes | 17.8 of 19.5 Gt/a (91 %) |
  | 09 | RussianArctic (submitted) | 7.0 of 10.2 Gt/a (69 %) |
  | 02 | WesternCanada | about 0.3 of 7.3 Gt/a (one glacier, 08538) |

- **How it was found.** 2026-09-26/27, root-cause analysis of the v2 results; hidden until then by G15.
- **Fix (data, no code).** Decision of 2026-09-27: always use a no-calving calibration, Lander's where it exists (Alaska; Greenland file of 23 September), otherwise our own targeted recalibration of the calving glaciers and their cells, merged into Matthias's file (SouthernAndes 129 glaciers, 96 % of the regional target; RussianArctic 353 glaciers, 82 %, accepted as within the standard tolerance of about 0.1 m w.e. per glacier; WesternCanada 08538; NorthAsia 04016). LowLatitudes and Antarctic were recalibrated completely (G5; Antarctic 79 % of target, accepted).
- **Submissions.** Submitted RussianArctic (09) carries it and will be resubmitted. WesternCanada 08538 was recalibrated before 02 was submitted (its MRI ssp126 2100 volume went from 60 to 19 km³).
- **The default is calving on.** `settings.pro` sets `frontal_ablation='y'` (main `settings.pro:175`). On 2026-09-02 we found that about 89 of our forward-run configs did not set it and so silently ran with calving on. Svalbard and the ArcticCanadaN run with its recalibration were stopped and relaunched, and every config now sets `frontal_ablation` explicitly. Users of main should know that the default is 'y'.

(mc-g17)=
### G17. Calibration file handling

- **Silent nearest-ID fallback.** `apply_calibration_params.pro:15` takes the row with the nearest glacier ID, so a glacier missing from the calibration file silently gets a neighbour's parameters. Known cases: Alaska 21096 gets 21097 (0.30 km²) and 09689 is listed twice; SouthernAndes 17280 and 06058 (tiny); Greenland 00001; 4 Antarctic rows with flag 0 get the subregion mean. `cc5a13f` (v3) prints a warning per glacier and a count per run; the parameters used are unchanged. The same pattern at `:29` (temperature-offset grid) is not covered.
- **Region-wide fallback.** `9b11fff` (all branches): if no catchment-specific calibration file exists, the region-wide file is used. Because a catchment-specific file next to the staged one would silently win, the v3 feeder refuses to start in that case (`44b6099`); the submitted RussianArctic run used such per-batch files.
- **Calibration mode.** `f73a7c2` (all branches): the SSP loop stops after the first pass in calibration mode (the extra passes overwrote each other).

(mc-g18)=
### G18. `mass_bsl` was written as a running total

The netCDF variable for the glacier mass below sea level was a running total over the glaciers of a batch or region. Alexandra fixed it on main in `86e4f4c` (2026-09-24); our branches carry the identical patch as `811cd41` (v2 onward), and the two merge without conflict. Output written before the fix keeps the error: submitted ArcticCanadaN about 225×, Iceland 42.9×, Svalbard 24.7×, Scandinavia (ERA5) 70×, RussianArctic 55× too large (not repaired; regions 03, 04, 06, 07, 08, 09). The v2 hindcasts ran before the fix; an independent check found their per-batch values 416–1,529× too large (the commit message of `8993a0d` quotes 772–1,420×), and the combine script repairs them exactly (at most 9.3e-6 km³ off; S2). Lander's files made before the fix are probably affected but were not checked.

(mc-g19)=
### G19. netCDF dropped real negative values below −98 kg as missing

`write_netcdf_glacier.pro` replaced every value below −98 with NaN after converting it to kg; −98 is meant as the model's fill value (−99) plus one, so the test only makes sense in model units. Real negative values of more than 98 kg were dropped, e.g. Alaska 03014 runoff in August 2209 (−158,904 kg, from the flowline runoff adjustment). `cc23e6e` (round 5, v3r5) marks a value missing only where the model value is also below −98. Test: 20 `.dat` files identical; in the netCDF exactly that one value changes. Main has the old rule (`write_netcdf_glacier.pro:130-143`).

Two things remain after `cc23e6e`:

- The regional netCDF sums add only positive, finite values (main `write_netcdf_glacier.pro:169-180`, runoff at `:179`; the same on our branches). Negative runoff and NaN glaciers therefore still drop silently out of the regional totals.
- Real negative monthly runoff does not only come from the flowline. Core GloGEM produces it too, when refreezing exceeds melt plus rain in a month: 107 glacier-months in the NorthAsia v3 output, for example 10.03490 under CESM2-WACCM ssp126 in July 2078 (tens of tonnes each).

(mc-g20)=
### G20. Monthly netCDF time labels are 3 (NH) or 9 (SH) months late (open in IDL)

The monthly series are stored in hydrological order (index 0 = October, or April in the southern hemisphere, of `tran[0]-1`), but `init_netcdf_projections.pro:102` (also `:342,361`) and `init_netcdf_hindcast.pro:83` stamp index 0 as January of `tran[0]`. **No IDL fix exists on any branch.** It is corrected only in post-processing: `8993a0d` gives every month its true date and `cc70ff7` adds `time_bounds`, `cell_methods`, whole calendar years (NaN for months the model does not simulate, October–December 1939 dropped) and a corrected time note (area and mass are the state at the start of hydrological year Y). The submitted v1 regions keep the labels as combined then (1 month off), so the submission contains two time conventions. Lander's files not checked. Main needs an IDL fix, or users of main need our combine script.

(mc-g21)=
### G21. Buffered per-glacier netCDF writes

`748dc8d` (all branches): per-glacier `ncdf_varput` calls are collected and flushed once per batch (1646.9 s → 7.09 s per batch on the network drive). Buffers are pre-filled with the file's `_FillValue`. File content checked with netCDF4; claimed identical.

(mc-g22)=
### G22. Start year of the Δh geometry change

`780520a` (2026-06-26) wrapped `initialise_firnicetemp_spinup` in `if firnice_temperature eq 'y'`. That file also resets `glacier_retreat='n'` per glacier, so with the temperature model off the Δh parameterisation started changing the geometry in 1940 instead of the survey year, inflating the inventory-date volume. `ae75e1e` (2026-07-08) restored the reset each year when `find_startyear` or `hindcast_dynamic` is 'y' (`glogem.pro:499-506` in v3). Net effect against main for standard configurations: none. Remaining difference, found by reading the code and not tested: a forward run with `find_startyear='n'`, `hindcast_dynamic='n'`, the temperature model off and `tran[1] ≥ 2026` never changes the geometry on main (main's `initialise_firnicetemp_spinup.pro` resets `glacier_retreat` for every glacier), but does on our branches from `tran[0]`. Which of the two is intended should be settled at the merge. Calibration is not affected (`setup_calibration_files.pro` sets `glacier_retreat='n'`).

**Merge trap.** `780520a` also moved the per-glacier reset of the climate month counter, `ccmon=0l`, from main's `initialise_firnicetemp_spinup.pro:17` to `initialise_output_arrays.pro:31` (v3), because the first file now only runs with the temperature model on. A merge that takes main's `initialise_output_arrays.pro` together with our `glogem.pro` never resets `ccmon`, and every glacier after the first would read the wrong climate months (section 8).

(mc-g23)=
### G23. "dhdt" renamed "Δh parameterisation"

`1661cac` (all branches): the Huss et al. (2010) geometry method is called "Δh parameterisation" in comments, printed messages and notebooks. The variable `dhdt_dx` (surface height change rate) and the file tag `scenario_tag='dhdt'` are unchanged.

(mc-g24)=
### G24. Englacial temperature module (off in GMIP4)

The englacial temperature module (`firnice_temperature='y'`, off by default and in all GMIP4 runs) was reworked on our branches between June and September. Main has an older version of the module and has at least three of the bugs below:

- the conduction stencil `fit_dz[0,j]^2` is written for a uniform grid (`firnice_temperature_model.pro:104-105`), but the layer grid is stretched (`settings.pro:455-456`, `fit_dzstep=[1,5,20]`);
- the advection only runs `IF ABS(MAX(vertical_vel)) GT 0.1D` (`firnice_temperature_model.pro:206`); the velocity is counted positive downwards and is 0 at the bed, so upward advection can never run;
- the snow conductivity is linear in density, `cond=(1-dens_rf/1000.)*kair+…` (`settings.pro:466`), like the heat capacity, so density cancels and snow gives no insulation.

The main fixes on our branches:

- vertical advection upwards was unreachable, the Nye velocity shape was wrong, and the basal boundary was not a geothermal-flux condition (found and fixed 2026-08-18; they were active in all earlier runs); strain heating was about 900× too small (fixed in `e9c0cca`, on `GloGEMflow` only, and kept off because it worsens the fit);
- the conduction stencil on the stretched layer grid was about 20× too steep, putting the bed at +14 °C instead of +4.8 °C (`dac9fa4`); an implicit solver is now the default (`daca009`);
- snow and firn had the thermal properties of ice, so snow insulation had no effect (`1aef7f6`, then calibratable `insul_scale` and `refreeze_frac`, `154dc6c`);
- the thermal spin-up ran with default parameters before the calibration was applied (fixed in the live tree on 2026-09-18, committed on 2026-09-22 in `bb981b7`) and on one year of climate; it now uses the real 1961–1990 climate (`672a1fc`) and can use a drift correction (`ab7cab3`), which is the default only on `GloGEMflow` (`108025c`; within 0.002 °C of 3,000 spin-up cycles);
- the column did not reach the borehole depth, which dropped 31 % of the observations (`6d05a87`).

13 commits of this work (`cea254f` to `e9c0cca`) are only on `GloGEMflow` and not in v3. `cea254f` adds bookkeeping lines to the core mass-balance files (`accumulation.pro`, `meltmodel.pro`, `refreezing_*.pro`, `calculatedebrismelt.pro`; claimed bit-identical on Iceland) and conflicts with `d62db11`: a test merge (`git merge-tree`) of `GloGEMflow` into `glogemflow-v3` conflicts in exactly `meltmodel.pro` and `calculatedebrismelt.pro`. The history of this work is kept in the separate `glogemflow_icetemp/development_history/` book.

---

## 4. GloGEMflow items

GloGEMflow is not on `main`, so everything here is new code for main. In short, for our submissions:

| ID | v1 submissions | v2 submissions (02 13 15) | v3 (10 16) | v3r5 (01 05 09 17 19) |
|---|---|---|---|---|
| F2 resurrected inventory hypsometry | fixed (all regions rerun after 2026-09-08) | fixed | fixed | fixed |
| F2 lost survey year, volume jump at handover | carry it | carry it | fixed | fixed |
| F5 hindcast and projection spin-ups mixed in the cache | carry it | fixed | fixed | fixed |
| F6, F7 flowline mass leaks | carry them (table in F7) | carry them | fixed | fixed |
| F8 port fixes of rounds 2 to 4 | not included | not included | included | included |
| F9 calving of sea-ending glaciers | not included | not included | grid end only | grid end and front |
| F10 180 s spin-up limit | carry it | carry it | carry it | fixed |
| F11 kept ice and A_flow from different attempts | carry it | carry it | carry it | fixed |

(mc-f1)=
### F1. Port of MATLAB GloGEMflow to IDL and coupling to GloGEM

- **History.** April to July 2025: translation of Harry Zekollari's MATLAB GloGEMflow to IDL (about 190 commits, including notebooks and grid-conversion experiments). `baa5c7b` (2026-03-20): flowline mass balance, the Zekollari et al. (2019) spin-up and the coupled driver `glogemflow_coupled.pro`; refined in `0f53b2f`. `020e81e` and `009a688` (2026-06-09): integration into main's modular `glogem.pro`, with the settings `use_flow_model` and `write_geometry_output`.
- **Current design.**
  - GloGEM's calibrated band mass balance is mapped onto the flowline each year (`flowline_massbal.pro` is kept but not called).
  - Shallow-ice approximation with a third-order Runge–Kutta step (`ice_thickness.pro`, `diffusivity.pro`) on a trapezoidal channel.
  - The elevation bands are rebuilt from the flowline every year (`update_elevation_bands.pro`), and the band elevation feeds back into the mass balance (`0ce7fa7`). The mass-balance elevation is capped at the inventory surface, as MATLAB's `massbal.m` does (`0ad3e88`).
  - The spin-up (`spinup_flowmodel.pro`) runs the glacier to steady state under the 1961–1990 balance and fits the flow factor A_flow to the observed volume and an ELA bias to the observed length.
  - The flow model runs only from the survey (inventory) year on; before that both paths use the Δh parameterisation (`6655731`; this removed a 24 km³ gap to the Δh runs).
  - Glaciers shorter than 1 km, and glaciers whose spin-up fails or is rejected, use the Δh parameterisation (`2458182`, F3). `use_flow_model='y'` forces `advance='y'`.

(mc-f2)=
### F2. Flow → Δh handover

A glacier leaves the flow model when its spin-up fails, when the flowline blows up, or when its balance is not finite. Five bugs were found in that handover:

- **Glacier vanished** (`a473e25`, 2026-06-25): on a blow-up the thickness was zeroed, so all bands switched off and the glacier reported 0 volume. The geometry is now restored.
- **Geometry frozen** (`61ac7d4`, 2026-07-13): the handler printed "falling back to Δh" but never switched the glacier over, so its geometry froze for the rest of the run: about 1.8 of the 5.1 km³ excess over the Δh parameterisation at 2099 (RGI7, ssp585). The new `sync_bands_thickness.pro` copies the flowline thickness to the bands before the switch.
- **NaN after the handover** (`11ca640`, 2026-08-10): a non-monotonic band elevation gave a non-finite flowline balance, and the sync wrote thickness into bands with no inventory thickness, a division by zero in the Δh area scaling. Iceland 00375 and 00202: NaN in 173 of 361 years → 0.
- **Inventory hypsometry resurrected** (in production 2026-09-08, committed in `5dfd530`): bands outside the flowline's ice kept their inventory thickness while their area was 0, and `glacier_retreat.pro` rebuilds area from `thick > 0`. The first Δh year after a fallback brought the whole inventory glacier back: SouthAsiaEast 01184 0.00006 → 434 km³ in one year, ArcticCanadaN 02567 0.0009 → 4,486 km³. Found from a regional plot (SouthAsiaEast IPSL ssp585 regrowing to 1,736 km³); 19,396 glacier-runs in 7 regions were affected, up to 98.7 % of a region's 2099 volume. `sync_bands_thickness` now zeroes every band the flowline does not cover and runs every flow year. All 12 regions then finished were rerun (old output kept as `*_OLD_runaway_bug`). Lander's runs are not affected.
- **Lost year and volume jump** (`df8bdd4`, v3): when the flow model gave up, that year's surface balance was reported but never applied (about 23 % of flow-eligible glaciers fail their spin-up, so this hits every region at the survey year: +0.94 of ArcticCanadaS's +2.02 Gt/a hindcast residual, +0.91 in Alaska, +0.16 in Svalbard). The Δh step now runs in the same year. At a mid-run handover the bands, whose areas are overstated by up to 60 % (K11), received more ice than the flowline had (forced blow-up on Iceland 00376: 469 → 750 km³); the new `handover_to_dh.pro` scales the band thickness to the flowline volume (now 469.48 → 468.20 km³, the year's balance).

(mc-f3)=
### F3. Spin-up quality gate

The old guard rejected a spin-up only when `|final − target| / target > 100 %`, which an under-estimate can never reach. ArcticCanadaN 01481 calibrated to 0.59 km³ against 26.7 km³ observed and a 1.66 km flowline against 13.5 km, then blew up in its first year. Such glaciers ended a median 1.99× too icy at 2099 compared with pure Δh runs; glaciers with a good spin-up ended at 1.00×. They were 10.3 % of spun-up glaciers but held 68 % of the flow ice in ArcticCanadaS and 60 % in ArcticCanadaN. Since `5dfd530` (approved 2026-09-09) a glacier runs on the flow model only if its unrescaled survey-year state has a volume error of at most 50 % and at least half the observed length (`spinup_gate_vol_tol`, `spinup_gate_len_min`); otherwise it uses the Δh parameterisation from the start.

(mc-f4)=
### F4. Early spin-up and numerical fixes (June to September)

| Commit | Change | Evidence |
|---|---|---|
| `0174bed` | Volume and area stored at the start of the year, as in GloGEM; grid width normalised to the band area; spin-up Phase B starts about 1990, as in Zekollari (2019) | removes a one-year offset and an area jump at the survey year |
| `0301626` | Initial time step from the glacier-scaled value, as MATLAB `update_time_dt.m` (IDL used a fixed 0.25 yr, about 1000× too long) | blow-ups 12.1 % / 2.2 % (RGI7 / RGI6) → 0.9 % / 0.2 % of activations |
| `0ad3e88` | On a blow-up halve the time-step factor first (down to MATLAB's 0.05), cache it; mass-balance elevation capped at the inventory surface | fixed a ~2× volume overestimate in the Alps run |
| `aed44ba` | Volume from the trapezoid mid-width, as MATLAB `diagnostic_write.m` | volume had been inflated up to 3× for thinning glaciers |
| `9cba180` | No minimum terminus thickness, as MATLAB | removes an area zigzag |
| `e7abd2a` | 5-point smoothing of the initial thickness with terminus protection (MATLAB `load_glacier.m`), plus a volume rescale | RGI7 thickness blew up 5.5× more often than RGI6 |
| `7f4065b`, `ff9d40a` | Stall detection, a cap of 20 attempts and a 180 s wall-clock cap per glacier (see F10) | single glaciers had used 2 h of CPU |
| `00c5599` | No caching of a failed calibration as valid (A_flow = 0 had been cached); ELA bias clamped | |
| `de63c36` | Whole-glacier 30 % volume jump check (see K10); rescale to the survey volume made non-linear | Svalbard 00250 was 246 km³ against a 115 km³ target |
| `2458182`, `4971357`, `87e5b7a` | Degenerate and small glaciers no longer crash the spin-up | |

(mc-f5)=
### F5. Spin-up cache

- `196fa8c`: the spin-up (about 99 % of a flow glacier's runtime) is independent of the scenario and is cached per glacier in `spinup_cache/`.
- `5dfd530`: failed spin-ups are cached as `*_spinup_failed.txt` markers (32 % faster on every GCM after the first; byte-identical).
- `560ec9e` (v2, v3): a hindcast spins up for the survey year, a projection one year later (K4), but the cache was keyed by glacier only, so one run type restored the other's spin-ups. WesternCanada batch01: A_flow ratio 0.80–1.47, ELA bias up to 1000 m apart, verdict flipped for 7 of 43 glaciers. The key now includes the spin-up year.
- `830a795` (v3): after a fresh spin-up the coupled run started with a different time-step factor and a different precision than after a cache hit; 22 of 46 test glaciers differed (up to 0.8 %). Now bit-identical.
- `66e181f` (round 5, v3r5): all batches appended to one `flow_spinup_stats.dat` over the network drive, and one row each was overwritten with NUL bytes in NorthAsia and LowLatitudes v3. Each batch now writes its own table, `flow_spinup_stats_<catchment>.dat`. In the round-5 integration test (2026-09-29) every run, the production batch configs included, wrote its own table with as many rows as cached spin-ups and no NUL bytes.
- **Rule.** Any change to the climate, the calibration or the flow code invalidates the cache: clear the whole `spinup_cache/` (spin-ups and failure markers). Judge staleness by the job's launch time, not by file times, because IDL compiles the code when the job starts.

(mc-f6)=
### F6. The flowline thickness update destroyed and created ice

- **Destroyed ice at width jumps.** `ice_thickness.pro` (a port of MATLAB `ice_thickness.m`) wrote the flux divergence of the trapezoidal channel in expanded product-rule form with all factors at the cell centre. That is exact in the continuum, but in discrete form it creates or destroys ice wherever the width changes abruptly. SouthernAndes 12034: 3.05 km³/yr vanished, 3.65 of it at one cell where the width drops from 14,594 m to 3,185 m and back to 6,928 m. `78e71b2` (v3) uses the flux form: what leaves one cell enters its neighbour, in double precision.
- **Created ice.** A cell could give away more ice in one sub-step than it held; the negative thickness was set to 0 and the missing ice appeared from nothing. The main case is an empty cell on a bed step above an ice-covered cell (WesternCanada 12435: about 1.4e7 m³ a year at one cell), which then left the grid end as fake frontal ablation (12435: 3.3 Gt over the run). Also, the update was linear in thickness although the trapezoid's width grows with it. `abaa01b` (v3) scales each outgoing flux so that no cell gives more than it holds, and updates the trapezoid cross-section area. Test: residuals of the reviewers' problem glaciers ~1e-6 Gt/a; fake grid-end outflow 0; Phase A blow-ups in six samples 31 → 0.
- **Size of the created ice before the fix** (round-2 review, 2026–2099): +0.0126 Gt/a of unbooked ice against a net loss of −0.0466 Gt/a in WesternCanada sample B (27 %; Alaska 30: 10 %, SouthAsiaEast 30: 4 %). In the round-2 code, SouthAsiaEast 04723, a glacier of at most 0.43 Gt, sent 302.6 Gt of made-up ice out of its grid end. v1 and v2 have the same mechanism. `abaa01b` also notes that spin-up verdicts still flip on small numerical changes.
- `3e2b9d8` (v3): no 0/0 in that limiter for empty cells (tests bit-identical).
- Every spin-up changes with these commits, so the whole cache must be cleared.

(mc-f7)=
### F7. The flowline mass budget did not close

Hindcast budget residual 2000–2019, change in mass minus (accumulation + refreezing − melt − frontal ablation), in Gt/a, as submitted or run with v1 and v2 code:

| RGI | Region | Residual (Gt/a) |
|---|---|---|
| 01 | Alaska | −3.42 (9 %) |
| 02 | WesternCanada | +0.36 |
| 03 | ArcticCanadaN | +0.90 |
| 04 | ArcticCanadaS | +2.02 |
| 06 | Iceland | −3.83 (44 %) |
| 07 | Svalbard | +1.57 |
| 08 | Scandinavia | −0.04 |
| 09 | RussianArctic | −1.36 (57 %) |
| 11 | CentralEurope | +0.11 |
| 12 | Caucasus | +0.03 |
| 13 | CentralAsia | +0.48 |
| 14 | SouthAsiaWest | +0.69 |
| 15 | SouthAsiaEast | +0.78 |
| 17 | SouthernAndes | −15.79 (105 %) |
| 18 | NewZealand | +0.08 |

Percentages, where given, are the residual as a share of the region's mass change. Negative residuals are unreported loss; positive ones mean the components show more loss than the mass change. Causes and fixes (all v3):

- `3d3c9cc`: `interpol` extrapolated the band balance to flowline cells below the lowest or above the highest band (mostly extra melt at tidewater fronts), and assumed band elevations are sorted, which they are not after a few flow years (54 inversions on 12034 and Iceland 00376), sometimes returning NaN. Now cells beyond the band range take the nearest band's value and the bands are sorted. The balance is converted with GloGEM's density 0.9 instead of 0.917 (with 0.917 a flow glacier's mass changed 1.9 % less than its reported balance).
- `cbb3c5a`: the reported balance was the one intended for the flowline, not the one applied; the components came from the rebuilt bands (K11); ice leaving the grid end was reported nowhere. `report_flowline_budget.pro` now reports the applied balance, maps accumulation and refreezing onto the flowline, lets melt close the budget, and books grid-end outflow as frontal ablation. SouthernAndes 12034: −4.77 → +0.0001 Gt/a; Iceland 00376: −1.02 → 0.
- `df8bdd4`: the lost year at the handover (F2). The sea-level calving undone by the Δh mass check (G11) made most of ArcticCanadaN's positive residual.
- `eaac031`: a remnant flatter than one band step lost all its bands, then never melted (Alaska 04076 stayed at 0.004 km³ from 2047 to 2300) and had NaN runoff. It now keeps its nearest band and melts out.
- `41f39e4`: grid-end outflow is written to `*_flow_gridend_outflow.dat` and summed in the log; setting `flow_gridend_outflow` ('frontal', the default, or 'melt_if_land'). Identical results under the default.

After these fixes the budget closes to better than 3e-5 Gt/a. What remains: before its survey year a glacier's geometry is held while its balance is reported (by design, K5: over 2000–2019 +1.09 Gt/a in ArcticCanadaS, +1.81 in Svalbard); a head-cell term of about 3e-5 Gt/a (K11). Janosch decided on 2026-09-27 to fix the leaks for future runs; all submitted regions, including v2, carry them.

(mc-f8)=
### F8. Deviations from the MATLAB model fixed in rounds 2 to 4

On 2026-09-24 a comparison with Harry's MATLAB code showed why about half of the IDL spin-ups failed: IDL's A_flow sat at its lower bound for 51 % and at its upper bound for 32 % of glaciers, while Harry's 123 saved Alpine calibrations never reach a bound. The MATLAB model had only ever been validated for CentralEurope. Fixed so far (all v3):

| Commit | Change | Evidence |
|---|---|---|
| `89f7b71` | Time step from the width-aware diffusivity of the flux form | the width binds for 2–4 % of glaciers; dt 1.2–1.4× (at most 15×) shorter there |
| `eff52b8` | A blown-up attempt is really retried with a smaller step (the stall check had ended the loop) | |
| `65dfc68` | Density 0.9 in the spin-up, as in the coupled run | balance jumped 1.9 % at the handover |
| `1a83285` | After a retried blow-up, A_flow steps the right way (the empty row made every step wrong) | wrong 6 of 6 → right 4 of 4 (WesternCanada sample) |
| `b6816be` | First ELA guess from the centred balance slope (MATLAB starts from the shift that gives zero balance) | wrong sign in 179 of 191 spin-ups before, none after |
| `23c8397` | When ice reaches the grid end, lengthen the ice-free area in front by a quarter of the glacier length (up to 1.5 lengths) and redo the attempt, as MATLAB `instability_iceleavedomain_steadystate.m` (Janosch, 2026-09-27) | identical to a longer grid from the start; grid-end outflow 0 |
| `b0287ce` | When the 3rd or a later length attempt fails, keep the attempt closest to the observed length, as MATLAB `length_calibration.m` (Janosch, 2026-09-28) | 38 of 48 such glaciers now run flow; flow share of 2025 mass in samples 91–100 % |

Differences to MATLAB that remain on purpose: MATLAB lengthens the grid only in the steady-state run, here both spin-up phases do; MATLAB treats more than 5× the observed volume at the grid end as an explosion, here the existing thickness and finiteness checks do that. Deviations still open are listed in K6.

(mc-f9)=
### F9. Glaciers ending in the sea

- **Grid end** (`bdecf06`, v3; Janosch 2026-09-28, "calve it off at sea"): after F8's grid extension, tidewater tongues advanced over the made-up bed that continues the glacier's lowest slope. The round-3 review found Alaska 08014 advanced by 23.5 km, with its ice surface down to −2,992 m; in `bdecf06`'s own test with the calving-on v2 calibration it reached −3,041 m. Where the bed at the grid end is below 0 m the grid is no longer lengthened; ice reaching the end leaves as frontal ablation. In that test 08014's lowest ice surface is now −532 m, which is the bed at its grid end.
- **Problems found by the review of 2026-09-29.** "Sea" was judged from the extrapolated grid-end bed, so some land glaciers calve (in the v3 NorthAsia output 04452 and 04465, 0.03 Gt in total, accepted; in a test, Victoria 01641, 0.13 Gt). There was no calving at the real front (Victoria −9.7 % in 2100, Alaska top-10 −5.8 % in 2300).
- **Front calving.** `fee563e` (round 5, v3r5; Janosch 2026-09-28, "same rule as Δh"): once a year, flowline ice in front of the lowest cell whose surface is at or above sea level is removed as frontal ablation, like the Δh parameterisation's sea-level cut. In the spin-up the survey-year state loses its front ice below sea level once, before the run. Tests: no flowline ice below sea level at any year end; frontal ablation 2025–2300 Alaska top-10 0 → 80.7 Gt, SouthernAndes 46-glacier sample 0 → 12.0 Gt; mass changes −0.8 % to +0.1 % in 2100 except Victoria (−10.1 %); land-only samples identical.
- **Sea test from the inventory front.** `b7ac6c5` (round 5, v3r5): a glacier has a sea front when the bed under the first ice cell of its inventory profile is below 0 m. Only such a front calves when its ice reaches a grid end below sea level; every other front gets the longer grid, as before `bdecf06`. Tests against `fee563e`: Victoria 01641 and 01603 are land fronts (bed +236 m and +248 m); they now lengthen the grid to 1.5 glacier lengths, reach its end and go to the Δh parameterisation. NorthAsia 04465 lengthens its grid again instead of calving. The spin-up of RussianArctic 00114 now lengthens its grid. The tidewater glaciers 08014, 11628 and 14577 are unchanged and still calve.
- **Integration test of `glogemflow-v3r5`** (2026-09-29; fresh spin-ups; ERA5 hindcast and MRI-ESM2-0 ssp126 to 2300 for six sea samples, and the production config of Antarctic batch 03 with ACCESS-ESM1-5 ssp126): no crash, no NaN, budget residual at most 0.007 Gt per run (the RussianArctic projection +0.12 Gt, from its Δh ice cap 00643 as in v3), and every `.dat` byte and netCDF value equal to the round-5 reviewers' runs of the same code. A copy with added print lines only (identical output) found no flowline ice with its surface below sea level at any of 32,422 flow glacier-year ends, and the frontal ablation booked equals the calved plus grid-end ice in every glacier-year. Frontal ablation over the projection, v3 → v3r5: Alaska top 10 0 → 80.7 Gt (16798), SouthernAndes 46 0 → 12.0 Gt, Greenland 20 3.55 → 3.81 Gt, Victoria 25 8.8 → 9.8 Gt (5.0 calved at fronts, 4.0 out of the grid end of the sea-front glacier 01488, 0.8 cut from Δh glaciers; the 0.14 Gt the land glacier 01641 lost through its grid end in v3 is gone), Antarctic batch 03 10.3 → 8.8 Gt (its positive-balance glacier 00005 now calves at the front instead of leaving the grid end).
- **To disclose** (round-5 physics review): calving removes whole flowline cells, so yearly frontal ablation is spiky (Alaska 16798 loses 0.53–0.65 Gt in single years every 10–12 years), as the Δh parameterisation loses whole bands. The spin-up has no calving and its tongue below sea level is cut before the run; in Victoria that ice (about 0.5 Gt in the sample) calves over the first ten years instead of in year one. 10–40 % of the inventory cells of each Victoria tidewater glacier have their surface below sea level; the quality gate still counts them in the observed length, so after the cut several of these glaciers start at 0.51–0.89 of it and go to the Δh parameterisation (Victoria sample flow share 90.6 → 82.0 % with F9 to F11). A land glacier that re-advances over the made-up bed beyond its front can also calve when its surface drops below sea level (NorthAsia 04452/04465, 0.006 Gt after 2200). Calving adds to the loss of the no-calving calibrated balance, as the Δh cut does.
- **Open point for Janosch** (builder, round 5): the cut acts once before the run and every year after the flow year, not inside the spin-up. Cutting inside every spin-up year leaves tidewater glaciers too short (Alaska 16798 at 0.75 of its length) and shifts regional 2100 mass by −4 to +14 % in the samples.
- **Submissions.** NorthAsia and LowLatitudes (v3) are land regions and ran without round 5; the sea-ending regions 01, 05, 09, 17 and 19 run with it (v3r5).

(mc-f10)=
### F10. The spin-up verdict depends on host load

The 180 s wall-clock cap per glacier (`ff9d40a`) makes the success or failure of a spin-up depend on how busy the host is. Numbers from the round-4 review of the v3 production (NorthAsia and LowLatitudes):

- The cap fired in 594 of 5,554 spin-ups: 289 of these kept their closest attempt and about 300 fell back to the Δh parameterisation.
- It caused 75 of 141 NorthAsia and 79 of 81 LowLatitudes hindcast spin-up failures, about 6 % of the flow-eligible ice. The LowLatitudes numbers cover batches 01–05 only, because the logs of batches 06–07 were lost (S7).
- In a 26-glacier RussianArctic sample it fired in 15 spin-ups, and 14 spin-ups failed. One of them was ice cap 00643, which holds 485 of the sample's 941 Gt, so it went to the Δh parameterisation and the sample's flow share is 0.5 %.

Janosch decided on 2026-09-29 to replace the cap with a fixed amount of work. `43f3584` (round 5, v3r5) stops a spin-up after `spinup_max_substeps` = 2.5 million flow time steps over all its attempts (`settings.pro`); a 900 s wall-clock cap (`spinup_max_wallclock_sec`) stays as a safety net with its own log line and never bound in the tests. 180 s had allowed 2.35–2.70 million steps on a vierzack for a typical grid of about 120 cells, 3.25–4.1 million on an idle iceberg and 1.1–1.6 million on a busy one. Test: Greenland, Victoria, SouthernAndes and RussianArctic samples gave identical output on idle and busy hosts and across vierzack05/06/07, while under the 180 s cap 17 of 21 SouthernAndes files differed on a busy iceberg (12034 cut off in its 5th attempt: 9 Gt in 2100). At normal load no result changes (20 runs, 468 spin-ups, the same 57 limit hits); runtime 2–3 % shorter. Of 197 sample spin-ups the median needs 0.06 million steps and 95 % less than 0.54 million; 27 reach the budget (21 go to the Δh parameterisation, 6 keep their closest attempt). RussianArctic ice caps use up the budget in their first steady-state run, so that region stays mostly on the Δh parameterisation, as it did under the 180 s cap. Integration test (2026-09-29): paired v3 and v3r5 sample runs on half-loaded hosts took 0.66–1.05 of the v3 time (0.92 in total; Victoria is faster because fewer of its glaciers stay on the flow model). With the RussianArctic batch-06 production config the budget and the old cap ended the first 22 spin-ups with the same outcomes, 45 minutes into the job and within 90 s of each other. At full load (19 copies of the budget-limited glacier 00002 next to 5 other CPU-bound jobs on the 24 cores of vierzack05) that spin-up ended 197–200 s after the job start, as on a half-loaded host (197 s), and the 19 outputs were identical, so the budget does not slow the campaign on the vierzacks.

(mc-f11)=
### F11. Kept spin-up state and A_flow disagree

When the volume search does not converge, the kept ice state and the A_flow used afterwards can come from different attempts; MATLAB re-runs the best A_flow so that the two match (`volume_calibration.m` 237–243). In the NorthAsia and LowLatitudes v3 production, 177 of 1,272 kept spin-ups had this mismatch, with A_flow more than 100× off in 27. The round-4 review's test fix changed a 74-glacier NorthAsia sample by −0.2 % in 2100; the two regions keep the mismatch. `9a4b047` (round 5, v3r5) keeps the ice of the attempt closest to the target volume, whose A_flow is the one kept. Test: before, 19 of 44 such spin-ups in the samples ended with a mismatched pair (volume off by up to 29 %); after, all 55 match exactly. In 2100, six of nine test samples change by −0.2 to +0.3 %; the others are Alaska 30 (+1.2 %), NorthAsia Altay (+2.4 %, 0.008 Gt; its flow share of the 2025 mass drops from 79.9 to 72.0 % because 01497 now goes to the Δh parameterisation) and Victoria 25 (−4.6 %). NorthAsia and LowLatitudes were produced without it; on land it is the only round-5 change that alters results in the integration test: in the NorthAsia Altay sample 4 glaciers change in the hindcast (+0.3 % mass in 2025) and 5 in the MRI-ESM2-0 ssp126 projection (−1.1 / +2.4 / +1.3 % in 2025 / 2100 / 2300; 01497 now fails the quality gate); in the LowLatitudes Andes sample none in the hindcast and one in the projection (00184 now keeps its attempt at the A_flow floor of 1e-20 and no longer melts out by 2100; sample +4.7 % in 2100 and 2300). Whether to disclose this or rerun the two regions is open.

(mc-f12)=
### F12. Speed

- `0d44bad` (v2, v3): an ice-free flowline still ran about 5,600 sub-steps a year (0.23 s per glacier-year, 10–25 % of some jobs), although it cannot regain ice. They are skipped. Byte-identical; WesternCanada 1.56× faster.
- `07d306a` (all branches): vectorised diffusivity and thickness loops.

(mc-f13)=
### F13. Flowline velocity for the temperature model

`a9cb358` and `5b1aa21` map the flowline velocity and the kinematic vertical velocity onto the elevation bands for the englacial temperature model. `4b80a07` fixed the temperature model overwriting the flowline `dx` when advection was on. `ae75e1e` added flow-usage counters to the run log.

(mc-f14)=
### F14. Log said "falling back to Δh" when the glacier stayed on flow

Since `b0287ce`, a spin-up that stops in its 3rd or later length attempt keeps its closest attempt and stays on the flow model, but the log still printed "abandoning flow model ..., falling back to Δh parameterisation". `b4589c2` (round 5, v3r5) prints "stopping the calibration" there and one "Spin-up failed --- falling back to Δh parameterisation." line where the glacier really falls back. Log only.

---

## 5. Scripts, post-processing and run infrastructure

These are in `scripts/` and do not change model output, but they change the files submitted to GMIP4 or how campaigns run.

(mc-s1)=
### S1. Combine counted batches twice

After the `GloGEMflow_` rename, a rerun batch could exist on disk as both `GloGEM_*` and `GloGEMflow_*`, and `combine_gmip4_output.py` summed both: RussianArctic came out at exactly 2× its area, ArcticCanadaS at +15.4 %, and submitted SouthAsiaWest had 4 duplicated batches (area up to +52 %, and 4 files with NaN). `a6037e2` (2026-09-23) keeps one file per batch and raises an error on non-finite area or mass. SouthAsiaWest was resubmitted on 2026-09-23.

(mc-s2)=
### S2. Combine and gate for the v2 campaign

`8993a0d` (review of 2026-09-25): the scripts read v1 directories; CentralAsia was never gated; empty directories and missing batches passed; monthly files could be paired with another batch's area. Now: `--v2`; batches paired by number and checked for completeness; `mass_bsl` running totals replaced by the exact per-glacier value (G18); every month stamped with its true date (G20); an empty directory and `mass_bsl > mass` are findings.

(mc-s3)=
### S3. GMIP4 format

`cc70ff7`: `time_bounds` and `cell_methods` on every variable; monthly series over whole calendar years with NaN for months not simulated; October–December 1939 dropped; corrected time note. The gate flags a glacier whose volume turns non-finite with more than 0.1 km³ left (SouthernAndes 08479 had silently lost 224 Gt that way, G9) and checks every combined file for non-finite values.

(mc-s4)=
### S4. Regional temperature

GMIP4 defines the regional temperature over the initial glacier area, and each batch file holds that mean over its own glaciers. The combine weighted the batches by their current ice area instead, so the regional value drifted towards the batches that still had ice, and it became NaN once a region was ice-free (LowLatitudes: 2,112 months). `126d571` (v3) first used first-year areas in months with no ice left. Janosch decided on 2026-09-29 to weight by the initial area in every month; `ae936f2` (v3) does that. Recombined NorthAsia and LowLatitudes (staging folder): the annual files are byte-identical and only `temp` changes in the monthly files, matching an independent recompute to 1.5e-5 K. Change in NorthAsia: annual means up to 0.02 K to 2025, 0.14 K to 2050, 1.5 K in 2051–2100 (2090s up to 0.88 K under ssp585), 2.7 K after 2100, single months up to 8.0 K; LowLatitudes at most 0.02 K to 2100 and 0.23 K after. Submitted regions stay as they are. Left inside the IDL writer: `write_netcdf_glacier.pro` weights each glacier by its initial area at the end of the run, and the Δh advance scheme adds hypothetical bands to that area, so regrown glaciers count with more than their inventory area (0.02–0.17 K against a per-glacier mean over the inventory area).

(mc-s5)=
### S5. Output gate `check_gmip4_output.py`

Created in `5dfd530` after the runaway glaciers of F2: it flags a glacier with an absurd absolute volume or implied thickness (not "grew from zero", which can be real). `bb4744e` (2026-09-24) judges runaways by their excess volume and tolerates less than 1 % of the region's ice, because a correctly clamped glacier (G12) sits just above 2000 m (SouthernAndes clamp cases 0.54 % pass; the pre-limiter runaways, 37.7 %, fail). Extended in `8993a0d` and `cc70ff7`. Open: it does not test regrowth under ssp126 or ssp534-over, so Δh ice pillars (K1) pass.

(mc-s6)=
### S6. Combine scripts, hindcast combiner, config generator, v3 regions

`combine_gmip4_output.py` (`de63c36`); `combine_gmip4_hindcast.py`, which refuses partial regions (`3bae19c`); `make_gmip4_configs.py` (`5bf98de`); `requeue_incomplete.py` (`5dfd530`); NorthAsia, LowLatitudes, Antarctic and Greenland with subregion file prefixes and `--v3` (`ca74f02`).

(mc-s7)=
### S7. Launchers and watchers: lost, killed and overwritten jobs

- `24d6a06`, `de63c36`: a batch is `.done` only when its log has the "FINISHED region" marker for every GCM; `BATCH_LIST` for targeted repairs; filtered logs; `auto_relaunch_watcher.sh` starts queued jobs when licences free up.
- `f44e013` (2026-09-22): `launch_batches.sh` killed any tmux session with the name it was about to use, including live jobs (27 jobs lost on 2026-09-20/21); it now skips sessions with a live IDL. The watcher counted live jobs with `pgrep -u $(whoami)`, which matched nothing when the user lookup failed (24 jobs died around a watcher restart); it now uses the numeric uid.
- `ae1a1e6` (v3): jobs started in the same second wrote the same journal file (4 of 80 LowLatitudes journals were lost); each job now gets its own journal folder.
- Other: per-host job ceilings had exceeded the core counts (jobs ran at about 60 % of a core; fixed 2026-09-19); CMIP6 CanESM5 has no CentralEurope data and hangs (excluded).

(mc-s8)=
### S8. Campaign feeders

`feed_v2_campaign.py` queues each batch's hindcast first (`61209b3`) and the SSP runs staggered behind ssp126 (`b57eb3c`), so the spin-ups are computed once and never written by two jobs at the same time. `feed_v3_campaign.py` adds region locks and a pre-flight check of configs, catchments, staged calibration and empty caches (`e5629c2`, `44b6099`), and after feeding waits and reports every batch without its 5 `.done` markers (`309ce36`; a queue line can be lost when the feeder appends while a watcher rewrites the file).

(mc-s9)=
### S9. Run logs off the home quota

`2196916`: `glogem.pro` writes its journal to `GLOGEM_LOGDIR` if set (default unchanged); `prune_home_logs.sh` compresses leftovers. Campaign journals had filled the 9.8 GB home quota twice.

---

## 6. Known issues, accepted or still open

(mc-k1)=
### K1. The Δh advance scheme can regrow glaciers without bound (accepted)

`glacier_retreat.pro:49` switches the advance scheme on once a glacier's volume exceeds its initial volume, and the area–thickness rescaling then feeds itself without a bound. Code bugs in it (line numbers as in the v1 code): a stale index `ci` (lines 111/144), `dh=-9999` on new bands (155), wrong-sign `redistribute_vplus` for a volume gain (55–63), `areas[ye-1]` (107), and new bands only 100 m below the terminus. Found 2026-09-15: in CentralEurope under MRI ssp534-over, glaciers above 5× their volume at 2300 hold 8.3 % of the ice in Lander's run (50 glaciers) and 37.3 % in ours (134 glaciers; the extra ones tipped over by G4); 03473 runs away identically in both. Later: NorthAsia small Δh glaciers get 3–4× thicker (13 % of MRI 2300 ice), Kilimanjaro reaches 660–1,010 m, LowLatitudes has 3–11 % of its 2300 ice more than 300 m thick; Lander's files show the same or more. Janosch accepted it on 2026-09-15 (no rerun; Lander to be told it is in his runs); on 2026-09-24 he asked for the bugs to be fixed and a physical bound to be added, which is not done. A patch that refreshes the stale index and sets dh = 1 on new bands (`/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development/_stab_tests/_notes/A2_glacier_retreat.patch`; ask Janosch for it) was tested on one SouthernAndes batch but not analysed, and is on no branch.

(mc-k2)=
### K2. GMIP4 GCM files are bias-corrected on the annual mean only (open)

Month by month the GCM files differ from ERA5 (Alaska April −1.24 °C, November +1.40 °C; CentralAsia summer share of precipitation 0.49 → 0.39), a seasonal step at the seam in every region, ours and Lander's. A property of the input data; not changed during the campaign; to decide with Lander.

(mc-k3)=
### K3. The 1939 months (accepted, low)

The first hydrological year starts in October (April) 1939. The hindcast fills those months with zeros, projections take them from the GCM; this gives differences of at most 0.04 m w.e. in 1940–1946 (snow carried over). The combined output drops them.

(mc-k4)=
### K4. Hindcast and projections start the geometry change a year apart (accepted)

The hindcast starts geometry change in the survey year (`ge`), projections one year later (`gt`), so 2000–2025 geometry differs by construction between the two GMIP4 products (in v1 too). Gaps: LowLatitudes 5 % (its 1997/98 El Niño survey year costs 3.9 Gt), NorthAsia 1.7 %, SouthAsiaEast −0.5 %, SouthAsiaWest −2.8 %, CentralEurope −2.5 %. Janosch 2026-09-29: leave as is. Related, flagged without a decision: the hindcast balance is below the calibration target where the flow start geometry differs from the calibration geometry (LowLatitudes 82 %, SouthAsiaEast 81 %). What the years before the survey year hold is described in K5.

(mc-k5)=
### K5. Geometry held before the survey year (by design)

Before its survey year a glacier's geometry is held fixed while its balance is reported, so the hindcast budget does not close for those years (F7). What is held is GloGEM's own starting geometry, not the inventory. In LowLatitudes the output stays at 1,929 km² and 76.9 Gt until the survey year, 83 % of the RGI7 area (inventory: 2,318 km² and 104 km³); Lander's Δh files start at the same 1,929 km². The regional area then steps up by 14 % in 1999, when the flow glaciers switch to the flow model's outline (their area goes from 1,622 to 1,918 km², inventory 1,944 km²); the volume does not change at the switch.

(mc-k6)=
### K6. Deviations from the MATLAB model that remain (open)

Found in the comparison of 2026-09-24 and not addressed: the front boundary is off by one cell (ice deleted at cell 1; hit in 67 % of Iceland's successful spin-ups); the ELA bias is an elevation shift of a concave parabola instead of a constant balance offset, with no linear fallback when the parabola has no root; the spin-up sets negative balance on ice-free cells to zero; the steady-state test is 10× stricter and exits early; the A_flow secant is clamped at 1e-20; projections use a time-step factor of 0.9 against MATLAB's 0.375; the diffusivity is stale after the volume rescale. F10 and F11 were fixed in round 5.

(mc-k7)=
### K7. ELA bias clamped at ±500 m instead of rejected (accepted)

MATLAB rejects a spin-up whose ELA bias would exceed ±500 m; IDL clamps it and reports −500 m even when that value was never simulated, and the last attempt is not the closest in 158 of 293 production cases. Janosch 2026-09-28: leave as is (the quality gate catches bad cases, and it keeps NorthAsia and LowLatitudes consistent).

(mc-k8)=
### K8. Positive-balance glaciers at the calibration bounds (accepted)

SouthernAndes 12034 has +3.3 m w.e./a even with the no-calving calibration. With the fake grid-end outflow removed (F6) it grows from 459 km³ (2000) to 658 km³ by 2100. Janosch 2026-09-28: keep as calibrated.

(mc-k9)=
### K9. Low flow share (open)

In v1, by glacier count, 65.7 % were shorter than 1 km, 23.3 % failed their spin-up, 0.6 % were rejected by the gate and 10.4 % ran the flow model. By volume the 1 km cut matters little (0–5 %); spin-up failure is what matters. Flow share of ice volume: v2 Alaska 46 %, WesternCanada 52 %, CentralAsia 58 %, SouthAsiaEast 57 %, SouthernAndes 55 % (Alaska 1.9 and CentralAsia 1.0 points lower when glaciers without a spin-up table row are counted as unknown, `66e181f`); v3 NorthAsia 79.6 %, LowLatitudes 87.0 %. In the submitted v1 Arctic regions the flow share was low: RGI 03 31.7 %, RGI 04 10.2 %, RGI 09 27.4 % (estimated from the glaciers that differ most from Lander's Δh runs), so these submissions are mostly Δh. The model logs counts only; the volume share comes from a separate script. Since round 5 the quality gate judges the survey-year state after the start-of-run calving (F9), while the spin-up table holds the state before it, so that script must take the gate verdicts from the run logs (`spin-up quality gate: glacier <id>`); otherwise it overstates the flow share of sea-ending regions (Victoria sample: 90.0 % reported against 79.8 % in the model). Janosch 2026-09-21: the Δh fallback is the last resort; classify the fallbacks after submission. Every regional plot states the flow share.

(mc-k10)=
### K10. The 30 % year-to-year blow-up check (open, low)

99.3 % of the 27,363 v3 events are small glaciers melting fast (median 0.0005 km³), which are handed to the Δh parameterisation. A growth-only version was tested but not analysed.

(mc-k11)=
### K11. Rebuilt bands overstate the glacier area; head-cell leak (open)

`update_elevation_bands.pro` rebuilds the bands from the flowline with areas up to about 60 % too large (Iceland 00376: 1,570 against 1,067 km²; SouthernAndes 12034: 2,200 against 1,368 km²). Since `cbb3c5a` the reported numbers come from the flowline, so this affects only band diagnostics. The head cell copies the thickness of the cell below it each sub-step (MATLAB's boundary condition) without booking the change: about 3e-5 Gt/a.

(mc-k12)=
### K12. Ice-melt and snow-melt labels swapped in the `.dat` output (open)

`settings.pro` names output 4 `Icemelt_sfc` and output 5 `Snowmelt_sfc` (main `settings.pro:191-192`, `:372-376`, `:426-427`), but `write_results_files_monthly.pro:30-31` and `write_results_files_daily.pro:30-31` write `smelt` (snow melt) as output 4 and `imelt` (ice and firn melt) as output 5. So in every GloGEM run, on main and on our branches, Lander's included, the `Icemelt_sfc` file holds snow melt and the `Snowmelt_sfc` file holds ice melt. The netCDF files, and so the GMIP4 submissions, use total melt and are not affected. First noted in `41f39e4`.

(mc-k13)=
### K13. The flow model silently does not run in runs ending before 2026 (open)

`settings.pro:487-491` (v3) forces `glacier_retreat='n'` for forward runs with `tran[1] < 2026`, after the user config is read. Unless `hindcast_dynamic='y'` (the GMIP4 default) switches it back on at the survey year, the coupled flow model is never called: the run finishes normally with empty temperature profiles, and the usage counter still reports "ran with GloGEMflow". Consequence: the temperature model's advection factor can only be calibrated with a stand-alone velocity estimate.

(mc-k14)=
### K14. An `@` include after `if ... then` guards nothing (open)

`@` is a compile-time text include, so in `if cond then $` followed by `@file.pro` only the first line of the included file is conditional. Found with `setup_firnice_profile_from_glenglat.pro`, which then opens an empty file name. The only instance is v3 `glogem.pro:410-411`, in our englacial temperature code; `origin/main` has no `if … then $` followed by an `@` include (checked 2026-09-29). (The two other output bugs found with it in 2026-08-20, in `save_geometry_output.pro`, are fixed.)

(mc-k15)=
### K15. NorthAsia: 57 glaciers outside every subregion box (accepted)

57 glaciers (0.18 of 189 km³: Chukotka south of its grid, 8 at 110.5E/75.8N, 5 in Japan) are in no NorthAsia subregion and are not simulated. Janosch 2026-09-28: leave them out.

(mc-k16)=
### K16. GCM ring search: a missing directory hangs the job (open)

The STOP guard of the ring search in `read_gcmdata_monthly.pro` can never be reached, so a missing GCM directory makes the job search forever instead of stopping.

(mc-k17)=
### K17. Smaller output issues (open)

- The netCDF global attribute still says `model: GloGEM` in flow runs, and `gcm` reads "NORESM2-MM".
- Temperature and velocity diagnostic rows carry the band elevation of the inventory date, frozen (Aletsch tongue up to about 100 m off); join on the yearly band elevation from `geometry_*_flow.sav` instead.
- The v1 netCDF files of the subregion regions were overwritten, because every subregion wrote the same file name; the v3 batch names avoid this.

(mc-k18)=
### K18. Debug `stop` and editor backup files on main (open)

`70c5af5` (Lander, 2026-09-16) added `refreezing_parametrised_new.pro`, which contains a `stop` at `m eq 6` (line 22) and would halt any run that includes it (nothing calls it yet), and two editor backup files, `downscale_gcmdata_monthly_new.pro~` and `read_climatepast_monthly_new.pro~`. The backups should be deleted and Lander told about the `stop` before merging.

(mc-k19)=
### K19. Kept spin-ups lean towards too-short glaciers (open, to be disclosed)

From the round-4 physics review of the v3 production (item 4, marked "disclose"). Since `b0287ce` a spin-up whose late length attempt fails keeps its closest attempt (F8), as MATLAB does.

- Failures mostly happen when the search tries to make the glacier longer, so 73 % of the kept attempts are shorter than observed. Median length ratio: 0.83 in NorthAsia Altay, 0.86 in NorthAsia East, 0.96 in LowLatitudes Andes. 380 kept glaciers are below 0.75 of their observed length; they hold 2.7–4.4 % of the volume.
- Compared with their Δh runs, the kept glaciers below 0.75 of their length keep 1.33× as much of their ice in 2100 (n = 11), those between 0.75 and 1 keep 1.01× (n = 18) and longer ones 0.66× (n = 14). Overall this adds about 1 % to the regional volume.
- 116 kept glaciers sit at the A_flow floor of 1e-20 (almost rigid ice), against 4 of the 3,383 glaciers whose search converged.
- The spin-up quality gate has no upper length limit: 16 glaciers longer than 1.5× their observed length pass it.

---

(mc-decisions)=
## 7. Decisions log

All decisions below were taken by Janosch Beer.

| Date | Decision | Applied in |
|---|---|---|
| 2026-08-28 | `frontal_ablation='n'` in every flow config (the flow model has no calving term); calving regions calibrated by Lander. | superseded 2026-09-27 |
| 2026-08-31 | Advection always on in the englacial temperature model (training had it on, the application configs off). | G24 |
| 2026-09-09 | Spin-up quality gate: volume within 50 %, length at least half the observed. | F3, `5dfd530` |
| 2026-09-15 | Δh advance-scheme runaway accepted, not fixed, no rerun; Lander to be told it is in his runs. | K1 |
| 2026-09-19 | Flow submissions are named `GloGEMflow_`; the six regions submitted until then were resubmitted under the new name. | G13, `b71eeca` |
| 2026-09-21 | The Δh fallback is the last resort; classify flow fallbacks after submission. | K9 |
| 2026-09-24 | Month shift reported to Lander the same day. | G1 |
| 2026-09-24 | Use Lander's region-wide calibration where we had calibrated per batch; Δh: fix the bugs and add a physical bound (not done yet); freeze v1 and develop v2; every change must prove it helps. | G4, K1 |
| 2026-09-24 | Output gate tolerates runaway excess below 1 % of the regional ice. | S5, `bb4744e` |
| 2026-09-25 | Δh (GloGEM) submissions and our submitted v1 regions are not rerun; the unsubmitted flow regions are rerun on v2. | section 1 |
| 2026-09-27 | Fix the flow budget leaks and the NaN bugs for future runs (disclosure for submitted regions dropped on 2026-09-28). | F6, F7, G9, G10 |
| 2026-09-27 | Always use a no-calving calibration: Lander's where it exists, otherwise our own targeted one; RussianArctic to be resubmitted. | G16 |
| 2026-09-27 | The calibration tolerance (about 0.1 m w.e. per glacier) is the standard; RussianArctic at 82 % of its target accepted; do not tighten per region. | G16 |
| 2026-09-27 | When ice reaches the flowline grid end: lengthen the grid and redo the spin-up, as MATLAB does. | F8, `23c8397` |
| 2026-09-27 | Submit WesternCanada, CentralAsia and SouthAsiaEast on v2 (08538 recalibrated first); Alaska, SouthernAndes and RussianArctic wait for the full fixes. | section 1 |
| 2026-09-28 | No disclosure note to GlacierMIP4 about the submitted regions. | section 1 |
| 2026-09-28 | Full no-calving recalibration of LowLatitudes and Antarctic; Greenland uses Lander's 23 September file (frozen); the 57 NorthAsia glaciers outside every box are left out; the new climate path takes lapse rates from the gridded file. | G5, G16, K15, `04a3c33` |
| 2026-09-28 | Keep the corrected first ELA guess; glaciers ending in the sea calve at the grid end; a late spin-up failure keeps the closest attempt, as MATLAB. | F8, F9 |
| 2026-09-28 | Front calving by the same rule as the Δh parameterisation; ELA bias clamp at ±500 m left as is; positive-balance glaciers at the bounds kept as calibrated. | F9, K7, K8 |
| 2026-09-29 | LowLatitudes to be submitted as is (ice created by the limiter after 2230 accepted). | G12 |
| 2026-09-29 | Regional temperature weighted by initial area from now on; submitted regions left as they are. | S4, `ae936f2` |
| 2026-09-29 | Hindcast survey-year convention left as is. | K4 |
| 2026-09-29 | Spin-up limit: a fixed amount of work instead of 180 s wall clock, in its own commit. | F10 |
| 2026-09-29 | Keep this document for the merge into main. | this page |

---

## 8. Notes for the merge into main

### Where the branches stand against main

- `origin/main` is at `4e5d5a1` (2026-09-24). All our branches split from it at `eb035d5` (2026-09-15); the last merges of main into our work were `635a888` and `e45574a` on that day.
- Commits ahead of `origin/main` (`git rev-list --count`, 2026-09-29 about 15:10): `glogemflow-v3` 345 at `ae936f2`, plus the commits of this page; `glogemflow-v3r5` 357 at `b2ed084` (counted about 17:30); `glogemflow-fixes` 334; `glogemflow-fixes-b` 333; `glogemflow-newpath` 315; `GloGEMflow` 310; `glogemflow-stability` 307; tag `gmip4-v1` 297.
- From the merge base to `glogemflow-v3` at `ae936f2` (without this page): 117 files, +22,094 / −379 lines. Added lines by folder: test data 8,221, analysis notebooks (`flow_analysis/`) 4,637, `scripts/` 3,956, `procedures/flow/` 2,692, `procedures/initialise/` 1,142, `procedures/processing/` 650, `procedures/write/` 413, `glogem.pro` 188. `settings.pro` grows by 141 lines.
- **Files that are not model code.** v3 also adds `.vscode/settings.json` (editor settings), `icetemperature_batch.dat` at the repository root (the glenglat borehole list of the temperature module; the model reads its copy from the data folder `dir`, not this one), the `flow_analysis/` notebooks and notes (4,637 lines) and `test/` data (8,221 lines: glenglat borehole elevations and temperature calibration tables, two of them 4,080-line kNN tables). Suggested: leave `.vscode/`, the root copy of `icetemperature_batch.dat` and `flow_analysis/` out of main, and take the `test/` data only together with the temperature module. `config.pro.example` (+19 lines: the batch switch, `use_flow_model`, `write_geometry_output`) can go with the flow model; its comments still use the old name of the Δh parameterisation, which G23 changed elsewhere.
- **Main-only commits.** `86e4f4c` (Alexandra, the `mass_bsl` fix) is on our branches as the identical `811cd41`. `70c5af5` (Lander, "Minor updates") changes only whitespace in the monthly path and adds three files nothing calls yet (`downscale_gcmdata_daily_new.pro`, `downscale_gcmdata_daily_old.pro`, `refreezing_parametrised_new.pro`) plus the backup files of K18. Our branches lack nothing from main that changes model results.

### Committed, but not in production (v3)

- Round 5 (`glogemflow-fixes`: `cc23e6e` G19, `b4589c2` F14, `fee563e` and `b7ac6c5` F9, `9a4b047` F11, `43f3584` F10; `glogemflow-fixes-b`: `5c03128` G12, `66e181f` F5) is merged on `glogemflow-v3r5` (`7a41170`, `b2ed084`); production takes it by fast-forward.
- On `GloGEMflow` only: the 13 englacial temperature commits `cea254f` to `e9c0cca` (G24).
- The branch `fix7-v3tmp` (`452223a`) is a test merge of `b4589c2` onto v3 and has no new content; it can be deleted.

### Whole-branch merge

A test with `git merge-tree` gave:

| Branch merged into main | Conflicts |
|---|---|
| `glogemflow-v3` | 1: `read_climatepast_monthly_new.pro:53`. Keep main's `;print, fn` and add our `era5_pt` line after it. |
| `glogemflow-fixes` or `glogemflow-fixes-b` | 1: `write_netcdf_glacier.pro:66`. Keep ours (`nc_s_mbsl`). |
| `glogemflow-v3` and `glogemflow-fixes-b` together | the same 2 |
| `glogemflow-v3r5` | the same 2 |
| `glogemflow-stability`, `GloGEMflow` | none |

Everything else merges automatically; main has not touched `glogem.pro` since the split. The hard part is not git: a whole-branch merge brings the flow model, the temperature model and the campaign scripts into main.

Bringing the 13 temperature commits into v3 first (merging `GloGEMflow` into `glogemflow-v3`) conflicts in exactly `meltmodel.pro` and `calculatedebrismelt.pro` (`cea254f` against `d62db11`, G24). `glogemflow-fixes` and `glogemflow-fixes-b` each merge into `glogemflow-v3` without conflict.

### Core-only port

If only the core fixes (section 3) go to main first, they have to be applied in dependency order, without the flow-model hunks of `glogem.pro` and `settings.pro`. A trial port onto `origin/main` left those two files out and applied every other file cleanly except the one `print` line above; the `glogem.pro` pieces must be placed by hand. Dependencies found:

1. Climate, old path: `78ffb9d` (G4) → `f129fc5` (G6) → `2c5357b` (G7) → `723a862` (G1) → `8d9d040` (G3). `8d9d040` does not apply without `78ffb9d` and `2c5357b`.
2. Climate, new path: `dac2343` (G1) → `4b4e9e8` (G3, needs `8d9d040`) → `ba586cf` → `9f7314a` → `b139cda` → `04a3c33` (G5). Simplest: take v3's `gradient_variability_monthly.pro` whole.
3. Domains: the grid-box parts of `5dfd530` (its 4 conflicting blocks are flow counters and can be dropped); `b8aa837` (one line).
4. Δh: `44b688a` → `d2b86d9` → `d62db11` → `9394bb6` → `c5d5f5d` (G9 to G11). `d2b86d9`'s one-line root fix and `d62db11` also apply on their own. Porting `44b688a` changes main's behaviour and needs a decision.
5. Output and calibration: `3465fdd` (G15), `cc23e6e` (G19), `cc5a13f` (G17; its `glogem.pro` counter and summary go near `glogem.pro:118` and `:668` by hand).
6. Hindcast: `8cb4ad7`, `b71eeca` (G13); drop the `use_flow_model` file-name switch, which main does not have.
7. Growth limiter: `97658ea` (G12) applies as is; place its call after `glogem.pro:550` by hand. The fixed version of `5c03128` reads `use_flow_model_gl` and `flow_initialised` at `limit_glacier_growth.pro:29`, which main does not define, so it needs a guard first.

The list above misses core fixes that live only in `glogem.pro` or `settings.pro`, and a few others. They would be lost unless carried over, mostly by hand:

- G14: `00c5599` (`rcp_batch = intarr(8)+3` in the GMIP4 block of `settings.pro`) and the `glogem.pro` hunk of `de63c36` (the region-setup GCM read only for CMIP6);
- G13: the `settings.pro` hunks of `8cb4ad7`;
- G4: the `xy_clim` snapshot in `glogem.pro` from `78ffb9d` (without it, step 1 does not fix G4);
- G8: the cell edges in `glogem.pro` from `5dfd530`;
- G17: `9b11fff` (`read_calibration_params.pro`) and `f73a7c2` (`glogem.pro`);
- G21: `748dc8d` (the netCDF writers);
- G22: `780520a` and `ae75e1e`, with the trap below;
- S9: `2196916` (`GLOGEM_LOGDIR` in `glogem.pro`).

**Trap: the climate month counter.** `780520a` moved the per-glacier reset `ccmon=0l` from main's `initialise_firnicetemp_spinup.pro:17` to `initialise_output_arrays.pro:31` (v3), because the first file now only runs with the temperature model on (G22). A merge or port that takes main's `initialise_output_arrays.pro` together with our `glogem.pro` never resets `ccmon`, and every glacier after the first would read the wrong climate months. After any merge, check that `ccmon=0l` runs once per glacier.

### Not fixed on any branch

These need new work before or after the merge:

- G2: the month shift and `gt min_ryear` in the CMIP6 projection branch;
- G20: the monthly time labels in the IDL netCDF writers;
- K1: the Δh advance-scheme runaway;
- K13, K14, K16, K12: the settings rule, the `@`-include pattern (only in our temperature code), the ring-search hang and the swapped melt labels.

### Other things to do at merge time

- Delete the two `~` backup files and tell Lander about the `stop` in `refreezing_parametrised_new.pro` (K18).
- Tell Lander which of his runs carry G1, G3 and K1; that his LowLatitudes and Antarctic ERA5 hindcast files do not match his projections (G5); and that in every GloGEM `.dat` output, his included, the `Icemelt_sfc` file holds snow melt and the `Snowmelt_sfc` file ice melt (K12).
- Tell the users of main that `settings.pro` defaults to `frontal_ablation='y'` (G16).
- Check main-code runs and calibrations made after 2026-09-15 on the old monthly climate path with MIP other than GMIP4 or AMOC (G6).
- Clear every spin-up cache after merging: any change to climate, calibration or flow code invalidates it (F5).
- `cea254f` (only on `GloGEMflow`) conflicts with `d62db11` in `meltmodel.pro` and `calculatedebrismelt.pro` (G24).

### Notes for the MATLAB GloGEMflow side

The IDL port now follows the MATLAB code in the retry after a blow-up, the first ELA guess, the grid lengthening when ice reaches the grid end and the choice of the closest length attempt (F8). It deliberately differs in: a flux-form, ice-conserving thickness update with a flux limiter (F6); a width-aware time step (F8); a spin-up quality gate (F3); a 30 % year-to-year blow-up check (K10); calving at the grid end and the front for glaciers ending in the sea (F9); a runtime growth limiter (G12); glaciers whose spin-up fails run with the Δh parameterisation (MATLAB drops them), and so do glaciers shorter than 1 km. K6 lists where it still deviates without a decision. The MATLAB model had only been validated for CentralEurope; outside the Alps, several of its choices (±500 m ELA range, time-step cap, prefrontal area) are untested.
