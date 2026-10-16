# WUFI processing pipeline

This page describes *operating order*, not a replacement for the release-specific Mathematica notebooks.

```text
Audited sensor/meteo data -> hourly WAC (Python, optional preprocessing)
                                     |
WUFI .w6p + matched XML sidecars -----+--> Batch Launcher / WUFI --> .ASC outputs
                                                                |
                                        WUFI Data Post-Processor --> WXF + JPG
                                                                |
Raw/cached sensor data + registry --------------------------------+--> sensor QC,
                                                       UTC alignment and model comparison
                                                                |
                                      aligned analysis series --> multiscale / DMD / DMDc
```

## 1. Prepare WUFI projects

Use actual WUFI `.w6p` files and one **same-stem** XML per project. To extract XML on Windows, place `extract_all_wufi_xml.bat` in the folder containing the `.w6p` files and run it there. It extracts the main project XML via PowerShell and validates before replacing a matching existing `.xml`. Review its status and retain backups of original projects.

Open `WUFI Batch Launcher Automated v1.nb` in Mathematica. Edit the initialization settings (`modelDirectory`, `wufiCommand`, switches); keep `WUFIModelMetadata.wl` discoverable. Evaluate sequentially, inspect `BuildWUFIManifest` results, ensure requested cases and monitor metadata are correct, then generate the manifest and WUFI batch file. Examine the written batch file *before* executing it: the utility prepares commands but does not infer scientific validity of projects.

The shared metadata API includes `BuildWUFIManifest`, `WriteWUFIManifest`, `WriteWUFIBatchFile`, `LoadWUFIManifest`, and `ValidateASCRows`. The manifest is the contract used downstream.

## 2. Process WUFI ASC outputs

Open `WUFI Data Post-Processor Automated v1.1.1.nb` and configure the neighboring `WUFIDataPostProcessorConfig_v1_1_1.wl`. Run in a fresh Mathematica kernel:

```wl
Get@FileNameJoin[{NotebookDirectory[], "WUFIDataPostProcessor_v1_1_1.wl"}];
Get@FileNameJoin[{NotebookDirectory[], "WUFIDataPostProcessorConfig_v1_1_1.wl"}];
postProcessorPreflight = PreflightWUFIPostProcessorV11[postProcessorSettings];
postProcessorPreflight["Status"]
```

Require `"Ready"` before evaluating:

```wl
postProcessingRun = RunWUFIPostProcessorV11[postProcessorSettings];
KeyTake[postProcessingRun, {"Status", "CompletedCaseCount", "FailedCaseCount", "OutputRoot"}]
```

Each successfully processed case supplies `relative_humidity.wxf`, `temperature.wxf`, `dew_point.wxf`, `layer_water_content.wxf`, `total_water_content.wxf` and mode-dependent plots. The five WXF products also exist in `"Sweep"` mode. For interrupted campaigns use `RestartFailedWUFIPostProcessorCasesV11[postProcessorSettings]` or `"RestartFailedCases" -> True` in settings; audit with `AuditWUFIPostProcessorOutputsV11[postProcessorSettings]`.

## 3. Compare with measured sensors

Open `MongoDB_Data_Analysis_WUFI_Comparison_v1_2.nb`, edit and load the driver and configuration. **Do not** regenerate cached JSON/MX/WXF during routine comparison unless required by a deliberate data update:

```wl
Get@FileNameJoin[{NotebookDirectory[], "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl"}];
sensorComparisonPreflight = SensorComparisonPreflight[sensorComparisonSettings];
sensorComparisonPreflight["Status"]
sensorComparisonPreflight["Errors"]
```

After `"Ready"`:

```wl
comparisonResult = RunSensorComparison[sensorComparisonSettings];
KeyDrop[comparisonResult, {"RunResults"}] // Dataset
```

Select cases using the **exact** case identifiers in `"SelectedCases"`. The REF/HEMP production examples use:

```wl
sensorComparisonSettings = Join[sensorComparisonSettings, <|
  "SelectedCases" -> {
    "Wall_REF_P5_L125_CV100_M200_W0_V070_A00",
    "Wall_hemp_P5_CORR_M200_S125_LT1000_W0_V070_A00"
  }
|>];
```

The comparison release has a frozen historical **five-case** validation record, but the committed project configuration currently selects **two** final wall cases. Do not expect five cases in a two-case run.

## 4. Climate reconstruction with Python

The `wac_from_audit.py` command expects an **already hourly audited CSV** containing:

`TIME`, `source_available`, `source_GHI`, `TA`, `HREL`, `WD`, `WS`, `PMSL`.

`TIME` is the **end-labelled fixed-standard-time** hour. `source_available` is a boolean/0/1 availability flag for the measured GHI. `source_GHI` is measured hourly global horizontal irradiance (W/m²), not a diffuse component. The tool applies solar geometry, astronomical night zeroing, same-clock-hour *bracketed* clearness-index interpolation for **internal** gaps, and `pvlib.irradiance.erbs` for the global/diffuse split. The WAC file contains eight fields:

`TIME TA HREL ISGH ISD WD WS PMSL`

The original project workflow zero-padded outside its verified source span. That policy preserves historical reproduction but is **not** suitable as a general-purpose meteorological gap filler. Inspect the source coverage and replace missing daylight data with credible external meteorological data where practical.

## 5. Modal and multiscale diagnostics

Export physically aligned **hourly** sensor and model series after QC, with explicit missing-data treatment; do not apply interpolation or standardization without documenting it. Use the Python reference implementations on approved local data:

- Multiscale: centered rolling means with a 72 h slow cutoff and 12 h event cutoff (robustness grid 48/72/96 h and 8/12/18 h).
- DMD/HODMD: SVD-based modal decomposition of snapshots (with time-delay embedding for HODMD).
- Delay DMDc: regression of the next state on lag-embedded state and exterior forcing; evaluate forced-response gain, timing and persistence.

These methods provide *diagnostic associations*, not causal identification of a particular leak/interface path. For the REF/HEMP report, distinguish historical saved tables/figures from the **reconstructed** reproducibility implementations (see [provenance](PROVENANCE.md)).
