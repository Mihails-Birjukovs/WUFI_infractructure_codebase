# Mathematica production toolchain

The established tools live in the [WUFI Mathematica branch](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools) and were developed for Windows WUFI Pro automation and original-sensor comparison.

| Component | Release | Entry point |
| --- | --- | --- |
| Batch launcher and metadata | v1.0 | [Launcher notebook](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools/Mathematica_tools) and WUFIModelMetadata.wl |
| ASC post-processor | v1.1.1 | [Release folder](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools/Mathematica_tools) |
| WUFI versus sensor comparison | v1.2.0 | [Release folder](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/tree/WUFI_mathematica_tools/Mathematica_tools) |
| WUFI main-project XML extraction | Windows script | [extract_all_wufi_xml.bat](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/extract_all_wufi_xml.bat) |

## 1. Launcher and manifest

Place the launcher notebook and **WUFIModelMetadata.wl** where its project-folder assumptions are satisfied; the notebook expects same-stem .w6p/.xml pairs. Configure modelDirectory, executable command (wufiCommand), and WUFI switches. In a trusted notebook session, inspect the manifest and generated batch content before execution. The launcher is **not** a substitute for confirming boundary conditions and monitored depths.

## 2. ASC post-processing

After a completed simulation, configure the neighboring **WUFIDataPostProcessorConfig_v1_1_1.wl** and load the implementation and config in a fresh Mathematica kernel:

~~~wl
Get@FileNameJoin[{NotebookDirectory[], "WUFIDataPostProcessor_v1_1_1.wl"}];
Get@FileNameJoin[{NotebookDirectory[], "WUFIDataPostProcessorConfig_v1_1_1.wl"}];
postProcessorPreflight = PreflightWUFIPostProcessorV11[postProcessorSettings];
postProcessorPreflight["Status"]
~~~

Run only after status **Ready**:

~~~wl
postProcessingRun = RunWUFIPostProcessorV11[postProcessorSettings];
KeyTake[postProcessingRun, {"Status", "CompletedCaseCount",
  "FailedCaseCount", "OutputRoot"}]
~~~

Full/Sweep graphics modes differ in plotted outputs, not the standard five WXF products. Keep **LIM Curves** available for full graphics.

## 3. Sensor comparison

Load the comparison implementation and configuration, supplying registry, selected-sensor WXFs, post-processed model WXFs and actual case names:

~~~wl
Get@FileNameJoin[{NotebookDirectory[],
  "MongoDB_Data_Analysis_WUFI_Comparison_v1_2.wl"}];
sensorComparisonPreflight = SensorComparisonPreflight[sensorComparisonSettings];
sensorComparisonPreflight["Status"]
sensorComparisonPreflight["Errors"]
~~~

Run **RunSensorComparison** only when preflight is Ready. The historical five-case release acceptance and later final two-case REF/HEMP production are distinct archives; they are not interchangeable validation counts.

## Known configuration hazards

- Absolute Windows paths in committed configuration files reflect the original research workstation and **must be adapted**.
- The sensor comparison LIMCurveDirectory default may resolve into **Mathematica_tools/LIM Curves** although the repository's shared folder is at root; correct the path explicitly rather than silently moving data.
- Timezone normalization, near-wall gates, measurement saturation and historical sensor-ID mapping require independent QC.
- Some release test assets are archived separately, and test runners may require unpacking them first.

[Read the source branch's complete installation guide](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/INSTALLATION.md) and [workflow](https://github.com/Mihails-Birjukovs/WUFI_infractructure_codebase/blob/WUFI_mathematica_tools/docs/WORKFLOWS.md).
