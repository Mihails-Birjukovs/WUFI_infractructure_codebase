# WUFI Data Post-Processor Automated — Production v1.1.1

**Target:** Wolfram Mathematica 12.1 / Windows  
**Version string:** `Production-1.1.1-2026-08-12`

Production v1.1.1 is the validated successor to Production v1.1. It preserves the established WUFI Batch Launcher and sensor-comparison data contracts while fixing the v1.1 graphics-export regressions and hardening parallel high-resolution rendering.

## Release status

Production promotion was approved after:

- 14/14 fast smoke tests passed in Mathematica 12.1;
- a corrected explicit-tick graphics stress run produced the complete serial baseline and all 48/48 requested 12-kernel stress images with intact annotations;
- three independent **8-kernel Full-mode five-case validation runs** each completed 5/5 cases, 25/25 WXFs and 265/265 JPGs with zero failed outputs, zero graphics retries, and 8/8 requested kernels launched;
- all 25 WXFs were byte-identical across the three release-validation runs;
- all 265 JPG render payloads were identical across all three runs after stripping non-semantic JPEG APP/COM metadata (creation-time metadata differs by run);
- mean summed five-case processing time was **420.75 s (7.01 min)** with **1.04%** run-to-run CV.

See `Documentation/RELEASE_VALIDATION.md` for the full record.

## Compatibility contract

Production v1.1.1 remains drop-in compatible with the established workflow:

- **WUFI Batch Launcher Production v1.0:** existing `WUFI_export_manifest.wl` contract unchanged.
- **WUFIModelMetadata.wl:** unchanged.
- **WUFI VS Sensor Comparison Production v1.2.0:** project/case directory and WXF paths unchanged.
- Every processed case still exports the five downstream WXF products:
  - `relative_humidity.wxf`
  - `temperature.wxf`
  - `dew_point.wxf`
  - `layer_water_content.wxf`
  - `total_water_content.wxf`

Public Wolfram symbols retain their `...V11` names for source compatibility.

## Graphics execution policy

Validated production default:

```wl
"UseParallelGraphics" -> True
"GraphicsKernelCount" -> 8
"GraphicsKernelWarningThreshold" -> 12
"FreshKernelRetries" -> 1
```

- **8 kernels**: production default; best balance of throughput and resource margin on the validated workstation.
- **12 kernels**: validated high-throughput override; only a small wall-time improvement over 8 kernels.
- **>12 kernels**: not recommended. A 16-kernel reference run stalled in the first case and failed to create some graphics.
- `Automatic` is accepted for compatibility but is not the validated production setting; it previously caused severe Windows/SSD/UI resource interference on the reference workstation.

ASC/data/WXF processing remains serial by design because profiling showed graphics dominate the runtime.

## Explicit time-series ticks

Time-series plots now use deterministic explicit date and numeric frame ticks. Date tick coordinates are supplied as numeric `AbsoluteTime` values. This removes dependence on late automatic tick generation, which had produced rare otherwise-valid parallel renders with missing date/numeric tick labels during RC1 testing.

## Progress and diagnostics

Production v1.1.1 restores controller-side progress and permanent stage logging. Worker kernels do not print progress. Per-case/run manifests record:

- ASC import time;
- data-preparation time;
- WXF export time;
- graphics-kernel launch time;
- graphics-render time;
- output-audit time;
- requested/actually launched graphics-kernel counts;
- graphics pass count and retained failure stage information.

## Graphics modes

- `"Full"`: RH, temperature, dew point, mould history, mould risk, per-layer water content, and total construction water content.
- `"Sweep"`: still exports all five WXFs but limits JPGs to RH + temperature + layer/total water-content graphics.

## Restart/recovery

Use either:

```wl
"RestartFailedCases" -> True
```

or:

```wl
RestartFailedWUFIPostProcessorCasesV11[postProcessorSettings]
```

Restart mode audits the actual output tree, skips complete cases, and preserves already-valid outputs within incomplete cases.

## Files

- `WUFI Data Post-Processor Automated v1.1.1.nb` — main notebook.
- `WUFIDataPostProcessor_v1_1_1.wl` — production implementation.
- `WUFIDataPostProcessorConfig_v1_1_1.wl` — editable user configuration.
- `WUFIDataPostProcessor_v1_1_1_SmokeTests.wl` — fast release/contract tests.
- `WUFIDataPostProcessor_v1_1_1_GraphicsStressTests.wl` — optional heavy graphics regression test; exact imported-pixel hashing is intentionally expensive and is not needed for routine runs.
- `WUFIModelMetadata.wl` — unchanged production metadata module.
- `LIM Curves/` — Full-mode LIM curve resources.
- `Documentation/RELEASE_VALIDATION.md` — production acceptance record.
- `STATIC_AUDIT.json` / `SHA256SUMS.txt` — static source audit and release hashes.

## Configuration note

The packaged user config intentionally preserves the **validated RC2 reference settings** (`Full` mode and the known five-case validation directory) for reproducibility. Edit `DataDirectory`, `GraphicsMode`, and campaign-specific options before using the release on a different run.
