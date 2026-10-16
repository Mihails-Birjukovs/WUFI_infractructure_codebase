# WUFI processing pipeline

This page describes *operating order*, not a replacement for the release-specific Mathematica notebooks. The optional WAC reconstruction and advanced dynamics scripts are separately maintained in the [Python branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools).

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

## 4. Optional Python upstream/downstream processing

To reconstruct WAC climate inputs with `pvlib`, or analyse aligned model/sensor residuals using multiscale methods, DMD, HODMD or DMDc, use [`WUFI_python_tools`](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_python_tools). Python dependencies and examples are **not installed from this Mathematica branch**.

The Python implementation preserves the distinction between retained WAC code, reconstructed research algorithms and new reference methods. Its climate inputs and modal outputs require independent physical/scientific validation.
