# WUFI vs Sensor Comparison — Production v1.2.0

**Release date:** 2026-08-05  
**Target:** Wolfram Mathematica 12.1 on Windows  
**Package version:** `Production-1.2.0-2026-08-05`

This is the final production release of the automated sensor quality-control, hourly aggregation, sensor-only reporting, selected-case WUFI-versus-sensor comparison, and validated graphics-export framework.

Production v1.2.0 is a metadata-only promotion of the fully accepted v1.2.0 RC3 implementation. No sensor-processing, WUFI-loading, temporal/spatial matching, metric, WXF, plotting, rasterization, graphics-audit, kernel-lifecycle, or orchestration algorithm was changed.

The accepted RC3 run established:

- 46/46 smoke tests passed;
- 13/13 equivalence gates passed;
- 5/5 WUFI cases completed with zero top-level or nested failures;
- 30 WXF files produced;
- 17 QC rows and 24 comparison rows produced;
- 24/24 UTC alignment checks passed with zero maximum timestamp offset;
- 99 expected, actual, and valid JPGs, with zero missing, unexpected, or invalid figures;
- every graphics batch reported `BatchStatus -> "Passed"` and `BatchInvariantPassedQ -> True`;
- graphics export counts were complete: 10 for the REF sensor batch, 17 for the hemp sensor batch, 12 for each REF comparison case, and 24 for the hemp comparison case;
- no failed or unclassified graphics task results.

Production v1.1.0 remains the archived validated optimized baseline. Production v1.0.0 remains the immutable numerical reference baseline.

## Active files

- `MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb` — cache-free operator notebook.
- `MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl` — production loader/driver.
- `SensorComparisonConfig_v1_2.wl` — user-editable paths and graphics lifecycle settings.
- `SensorDataUtilities_v1_2.wl` — processing, cached aggregation, comparison, graphics batching, bookkeeping invariants, and audits.
- `HygrothermalPlottingUtilities_v1_2.wl` — plotting and checked staged raster/WXF exports.
- `Smoke_Tests_v1_2.wl` — 46-test smoke/regression suite.
- `Equivalence_Tests_v1_2.wl` — 13 release gates against the frozen Production v1.0.0 output.
- `validate_wolfram_sources.py` — static source/package validator.
- `canonical_sensor_registry_2026-07-30.*` — frozen 17-sensor registry.
- `TestAssets.7z` — immutable runtime fixtures; extract as `TestAssets` beside the test scripts.
- `PRODUCTION_RELEASE_MANIFEST_v1.2.0.json` — final release identity and acceptance evidence.

## Expected installation structure

Place the extracted folder under the shared `Tools` directory, beside `LIM Curves`:

```text
D:\Science\NMI\WEED Project\Tools\
├─ LIM Curves\
└─ WUFI VS Sensor Comparison Automated v1.2.0\
   ├─ MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb
   ├─ MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl
   ├─ SensorComparisonConfig_v1_2.wl
   ├─ SensorDataUtilities_v1_2.wl
   ├─ HygrothermalPlottingUtilities_v1_2.wl
   ├─ Smoke_Tests_v1_2.wl
   ├─ Equivalence_Tests_v1_2.wl
   ├─ canonical_sensor_registry_2026-07-30.*
   ├─ TestAssets.7z
   ├─ Documentation\
   └─ Logs & Notes\
```

The supplied configuration expects the established project structure under:

```text
D:\Science\NMI\WEED Project\Fibrolite Materials RTU 2026\
```

Review `SensorComparisonConfig_v1_2.wl` whenever the package or data folders are moved.

## First production use

1. Extract the package without renaming its internal `.wl` or `.nb` files.
2. Extract `TestAssets.7z` beside the smoke/equivalence scripts when tests are required.
3. Review all absolute paths in `SensorComparisonConfig_v1_2.wl`.
4. Use a new empty output folder. The supplied default is:

```text
...\Sensors VS WUFI\Output_v1_2_Run1
```

5. Start a fresh Mathematica 12.1 kernel.
6. Open `MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb`.
7. Evaluate the driver-loading cell and require preflight status `"Ready"`.
8. Run `Smoke_Tests_v1_2.wl` and require **46/46**.
9. Run:

```wl
comparisonResult =
  RunSensorComparison@sensorComparisonSettings; // AbsoluteTiming
```

10. Require:
    - status `"Completed"`;
    - 5 completed cases, 0 failed cases, and 0 nested failures;
    - 17 QC rows and 24 comparison rows;
    - 30 WXF files;
    - 24/24 alignment checks with zero maximum timestamp offset;
    - graphics audit: expected 99, actual 99, valid 99, missing 0, unexpected 0, invalid 0;
    - every graphics batch passes its accounting invariants;
    - manifest versions `Production-1.2.0-2026-08-05`.

## Equivalence testing

`Equivalence_Tests_v1_2.wl` compares the production candidate output against frozen Production v1.0.0 output. Its default candidate root is `Output_v1_2_Run1`. Review both root variables before running and require **13/13** passes.

## Promotion integrity

The executable implementation is the accepted v1.2.0 RC3 code. Promotion changes are limited to:

- final production version strings and visible release labels;
- the clean default output directory name `Output_v1_2_Run1`;
- production release documentation and manifest;
- production expectations in the equivalence/static-validation scripts;
- removal of generated Mathematica notebook cache/outline blocks after title metadata changed.

Removing the generated notebook cache is necessary because byte-position offsets become stale when notebook title text changes. It does not alter any notebook cell or computational expression.
