(* ::Package:: *)

(* WUFI Data Post-Processor Automated - Production v1.1.1
   Changes relative to Production v1.1:
     - explicit JPEG validation for atomic .jpg.tmp exports;
     - robust fresh-kernel launch postcondition (immune to nonfatal launch messages);
     - bounded graphics parallelism (default 8; warning above validated threshold 12);
     - controller-side graphics progress and permanent stage logging;
     - per-stage timing and requested/launched kernel telemetry;
     - preserved last graphics failure stage across retries;
     - deterministic explicit ticks for date-series plots;
     - release-validation and stress-test support.
   Target: Wolfram Mathematica 12.1
   Compatibility contract:
     - consumes the Production v1.0 Batch Launcher WUFI_export_manifest.wl unchanged;
     - preserves the existing project/case folder layout;
     - always writes the same five WXF files used by WUFI VS Sensor Comparison v1.2.0;
     - GraphicsMode changes only the optional JPG inventory.
*)

$WUFIPostProcessorVersionV11 = "Production-1.1.1-2026-08-12";
$WUFIPostProcessorV11Root = Quiet@Check[DirectoryName[$InputFileName], Directory[]];
If[! StringQ[$WUFIPostProcessorV11Root] || $WUFIPostProcessorV11Root === "",
  $WUFIPostProcessorV11Root = Directory[]
];

metadataPackagePathV11 = FileNameJoin[{$WUFIPostProcessorV11Root, "WUFIModelMetadata.wl"}];
If[! FileExistsQ[metadataPackagePathV11],
  Print["Required shared package not found: ", metadataPackagePathV11];
  Abort[];
];
Get[metadataPackagePathV11];

ClearAll[
  DefaultWUFIPostProcessorSettingsV11,
  ResolveWUFIPostProcessorSettingsV11,
  ValidateWUFIPostProcessorSettingsV11,
  PreflightWUFIPostProcessorV11,
  RunWUFIPostProcessorV11,
  RestartFailedWUFIPostProcessorCasesV11,
  AuditWUFIPostProcessorOutputsV11,
  normalizeOutputRootV11,
  ensureDirectoryV11,
  fileByteCountSafeV11,
  parseTimestampV11,
  xmlDateObjectV11,
  gammaFunctionV11,
  dewPointFunctionV11,
  getTimeSeriesV11,
  validWXFFileQv11,
  validImageFileQv11,
  atomicExportWXFV11,
  atomicExportImageV11,
  caseOutputFoldersV11,
  expectedWXFRecordsV11,
  expectedImageJobsV11,
  expectedOutputRecordsV11,
  outputRecordValidQv11,
  caseOutputAuditV11,
  pathAssessmentV11,
  outputPathPreflightV11,
  loadLIMCurvesV11,
  verbosePrintV11,
  niceNumericTicksV11,
  explicitDateTicksV11,
  explicitDateFrameTicksV11,
  graphicsRuntimeSettingsV11,
  caseGraphicsPayloadV11,
  degreeSymbolV11,
  centerDotSymbolV11,
  temperatureLabelV11,
  volumetricWaterLabelV11,
  arealWaterLabelV11,
  frameLabelV11,
  plotStyleDefaultV11,
  plotStyleDewV11,
  historyColorPaletteV11,
  riskColorPaletteV11,
  plotLegendLIMHistoryV11,
  plotLegendLIMRiskV11,
  dashStyleV11,
  getFilteredSeriesV11,
  getDatePlotSimpleFilteredV11,
  getDatePlotDewPointV11,
  dateFormatV11,
  historyPlotRangeV11,
  riskPlotRangeV11,
  getMouldHistoryPlotV11,
  getMouldRiskPlotV11,
  renderPlotJobV11,
  launchFreshGraphicsKernelsV11,
  runGraphicsPassV11,
  runGraphicsJobsWithRetriesV11,
  processCaseV11,
  checkpointManifestPathsV11,
  jsonSafeV11,
  writeCheckpointManifestV11
];

DefaultWUFIPostProcessorSettingsV11[] := <|
  "DataDirectory" -> "D:\\Science\\NMI\\WEED Project\\Fibrolite Materials RTU 2026\\WUFI\\WUFI_Phase2_Calibration_Sweep_2026-08-06",
  "ManifestFileName" -> "WUFI_export_manifest.wl",
  "OutputRoot" -> Automatic,
  "LIMCurveDirectory" -> FileNameJoin[{$WUFIPostProcessorV11Root, "LIM Curves"}],

  "GraphicsMode" -> "Full",
  "UseParallelGraphics" -> True,
  "GraphicsKernelCount" -> 8,
  "GraphicsKernelWarningThreshold" -> 12,
  "FreshKernelRetries" -> 1,
  "ShowProgress" -> True,
  "VerboseLogging" -> True,
  "ExplicitTimeSeriesTicks" -> True,

  "RestartFailedCases" -> False,
  "SkipValidOutputsOnRestart" -> True,
  "MissingASCPolicy" -> "AbortAll",
  "CaseFailurePolicy" -> "Continue",

  "ImageFileFormat" -> ".jpg",
  "DataFileFormat" -> ".wxf",
  "DataExportFormat" -> "WXF",
  "ExportResolution" -> 500,
  "WindowSize" -> 0.0025,
  "PointCullingFactor" -> 1,
  "FontSizeDateSeries" -> 16,
  "FontSizeMouldPlots" -> 16,
  "ImageSizeSeries" -> 500,
  "ImageSizeMould" -> 500,
  "ImageSizeRisk" -> 500,
  "LegendSizeMouldFactor" -> 0.6,
  "LegendSizeRiskFactor" -> 0.85,
  "TimeFormat" -> {"MonthShort", "/", "YearShort"},

  "MinimumImageWidth" -> 100,
  "MinimumImageHeight" -> 100,
  "MinimumImageByteCount" -> 4096,
  "MinimumWXFByteCount" -> 16,

  "EnforceLegacyWindowsPathLimit" -> True,
  "PathLengthWarningThreshold" -> 240,
  "MaxLegacyWindowsFilePathLength" -> 259,
  "MaxLegacyWindowsDirectoryPathLength" -> 247,
  "MaxWindowsPathComponentLength" -> 255,

  "WritePostprocessManifest" -> True,
  "PostprocessManifestBaseName" -> "WUFI_postprocess_manifest_v1_1_1"
|>;

ResolveWUFIPostProcessorSettingsV11[userSettings_: <||>] := Module[{settings},
  settings = Join[DefaultWUFIPostProcessorSettingsV11[], userSettings];
  settings = Join[
    settings,
    <|
      "OutputRoot" -> normalizeOutputRootV11[settings],
      "ManifestPath" -> FileNameJoin[{
        Lookup[settings, "DataDirectory"],
        Lookup[settings, "ManifestFileName"]
      }]
    |>
  ];
  settings
];

normalizeOutputRootV11[settings_Association] := Module[{root},
  root = Lookup[settings, "OutputRoot", Automatic];
  If[root === Automatic, Lookup[settings, "DataDirectory"], root]
];

ValidateWUFIPostProcessorSettingsV11[settings_Association] := Module[
  {errors = {}, warnings = {}, graphicsMode, missingPolicy, failurePolicy, kernelCount, retries,
   warningThreshold, useParallel, showProgress, verboseLogging, explicitTicks},

  graphicsMode = Lookup[settings, "GraphicsMode", "Full"];
  missingPolicy = Lookup[settings, "MissingASCPolicy", "AbortAll"];
  failurePolicy = Lookup[settings, "CaseFailurePolicy", "Continue"];
  kernelCount = Lookup[settings, "GraphicsKernelCount", 8];
  retries = Lookup[settings, "FreshKernelRetries", 1];
  warningThreshold = Lookup[settings, "GraphicsKernelWarningThreshold", 12];
  useParallel = Lookup[settings, "UseParallelGraphics", True];
  showProgress = Lookup[settings, "ShowProgress", True];
  verboseLogging = Lookup[settings, "VerboseLogging", True];
  explicitTicks = Lookup[settings, "ExplicitTimeSeriesTicks", True];

  If[! MemberQ[{"Full", "Sweep"}, graphicsMode],
    AppendTo[errors, "GraphicsMode must be \"Full\" or \"Sweep\"."]
  ];
  If[! MemberQ[{"AbortAll", "ProcessAvailable"}, missingPolicy],
    AppendTo[errors, "MissingASCPolicy must be \"AbortAll\" or \"ProcessAvailable\"."]
  ];
  If[! MemberQ[{"Continue", "AbortAll"}, failurePolicy],
    AppendTo[errors, "CaseFailurePolicy must be \"Continue\" or \"AbortAll\"."]
  ];
  If[! (kernelCount === Automatic || (IntegerQ[kernelCount] && kernelCount >= 1)),
    AppendTo[errors, "GraphicsKernelCount must be Automatic or a positive integer."]
  ];
  If[! IntegerQ[warningThreshold] || warningThreshold < 1,
    AppendTo[errors, "GraphicsKernelWarningThreshold must be a positive integer."]
  ];
  If[! IntegerQ[retries] || retries < 0,
    AppendTo[errors, "FreshKernelRetries must be a non-negative integer."]
  ];
  If[! BooleanQ[useParallel],
    AppendTo[errors, "UseParallelGraphics must be True or False."]
  ];
  If[! BooleanQ[showProgress],
    AppendTo[errors, "ShowProgress must be True or False."]
  ];
  If[! BooleanQ[verboseLogging],
    AppendTo[errors, "VerboseLogging must be True or False."]
  ];
  If[! BooleanQ[explicitTicks],
    AppendTo[errors, "ExplicitTimeSeriesTicks must be True or False."]
  ];
  If[! StringQ[Lookup[settings, "DataDirectory", Missing[]]],
    AppendTo[errors, "DataDirectory must be a string path."]
  ];
  If[! StringQ[Lookup[settings, "OutputRoot", Missing[]]],
    AppendTo[errors, "OutputRoot must resolve to a string path."]
  ];
  If[Lookup[settings, "DataFileFormat", ".wxf"] =!= ".wxf",
    AppendTo[errors, "DataFileFormat is locked to .wxf for Sensor Comparison v1.2.0 compatibility."]
  ];
  If[Lookup[settings, "DataExportFormat", "WXF"] =!= "WXF",
    AppendTo[errors, "DataExportFormat is locked to WXF for Sensor Comparison v1.2.0 compatibility."]
  ];

  If[
    TrueQ[useParallel] && kernelCount === Automatic,
    AppendTo[
      warnings,
      "GraphicsKernelCount -> Automatic is not the validated production setting. Use 8 by default; 12 is the validated high-throughput setting."
    ]
  ];

  If[
    TrueQ[useParallel] && IntegerQ[kernelCount] && IntegerQ[warningThreshold] && kernelCount > warningThreshold,
    AppendTo[
      warnings,
      "Requested graphics kernel count exceeds the validated threshold of " <>
      ToString[warningThreshold] <>
      ". A 16-kernel reference run failed to complete reliably; counts above 12 are not recommended for production."
    ]
  ];

  <|"Valid" -> (errors === {}), "Errors" -> errors, "Warnings" -> warnings|>
];

ensureDirectoryV11[path_String] := If[
  DirectoryQ[path],
  path,
  CreateDirectory[path, CreateIntermediateDirectories -> True]
];

fileByteCountSafeV11[path_String] := Quiet@Check[
  If[FileExistsQ[path], FileByteCount[path], 0],
  0
];

parseTimestampV11[value_DateObject] := value;
parseTimestampV11[value_String] := DateObject[value];
parseTimestampV11[value_] := DateObject[ToString[value]];

xmlDateObjectV11[value_String] := Quiet@Check[
  DateObject[StringReplace[value, " " -> "T"]],
  Missing["NotAvailable"]
];
xmlDateObjectV11[_] := Missing["NotAvailable"];

{bV11, cV11, dV11} = {18.678, 257.14, 234.5};
gammaFunctionV11[temperature_, relativeHumidity_] :=
  Log[(relativeHumidity/100) Exp[(bV11 - temperature/dV11) (temperature/(cV11 + temperature))]];

dewPointFunctionV11[temperature_, relativeHumidity_] := Module[{gamma},
  gamma = gammaFunctionV11[temperature, relativeHumidity];
  cV11 gamma/(bV11 - gamma)
];

getTimeSeriesV11[dataSeries_] := TimeSeries[#2, {#1}] & @@ Transpose[dataSeries];

validWXFFileQv11[path_String, settings_Association] := Module[{value},
  If[
    ! FileExistsQ[path] ||
    fileByteCountSafeV11[path] < Lookup[settings, "MinimumWXFByteCount", 16],
    Return[False]
  ];
  value = Quiet@Check[Import[path, "WXF"], $Failed];
  value =!= $Failed
];

validImageFileQv11[path_String, settings_Association] := Module[{image, dimensions},
  If[
    ! FileExistsQ[path] ||
    fileByteCountSafeV11[path] < Lookup[settings, "MinimumImageByteCount", 4096],
    Return[False]
  ];
  image = Quiet@Check[Import[path, "JPEG"], $Failed];
  If[image === $Failed || Head[image] =!= Image, Return[False]];
  dimensions = Quiet@Check[ImageDimensions[image], $Failed];
  If[dimensions === $Failed || Length[dimensions] =!= 2, Return[False]];
  dimensions[[1]] >= Lookup[settings, "MinimumImageWidth", 100] &&
  dimensions[[2]] >= Lookup[settings, "MinimumImageHeight", 100]
];

atomicExportWXFV11[target_String, expression_, settings_Association] := Module[
  {temporary = target <> ".tmp", exportResult, validTemporary, validFinal},
  ensureDirectoryV11[DirectoryName[target]];
  If[FileExistsQ[temporary], Quiet@DeleteFile[temporary]];
  exportResult = Quiet@Check[
    Export[temporary, expression, Lookup[settings, "DataExportFormat", "WXF"]],
    $Failed
  ];
  validTemporary = exportResult =!= $Failed && validWXFFileQv11[temporary, settings];
  If[! TrueQ[validTemporary],
    If[FileExistsQ[temporary], Quiet@DeleteFile[temporary]];
    Return[<|"Status" -> "Failed", "Target" -> target, "Stage" -> "WXF temporary export"|>]
  ];
  If[FileExistsQ[target], Quiet@DeleteFile[target]];
  Quiet@Check[RenameFile[temporary, target], $Failed];
  validFinal = validWXFFileQv11[target, settings];
  If[
    TrueQ[validFinal],
    <|"Status" -> "Valid", "Target" -> target|>,
    <|"Status" -> "Failed", "Target" -> target, "Stage" -> "WXF final validation"|>
  ]
];

atomicExportImageV11[target_String, graphic_, settings_Association] := Module[
  {temporary = target <> ".tmp", exportResult, validTemporary, validFinal},
  ensureDirectoryV11[DirectoryName[target]];
  If[FileExistsQ[temporary], Quiet@DeleteFile[temporary]];
  exportResult = Quiet@Check[
    Export[
      temporary,
      graphic,
      "JPEG",
      ImageResolution -> Lookup[settings, "ExportResolution", 500]
    ],
    $Failed
  ];
  validTemporary = exportResult =!= $Failed && validImageFileQv11[temporary, settings];
  If[! TrueQ[validTemporary],
    If[FileExistsQ[temporary], Quiet@DeleteFile[temporary]];
    Return[<|"Status" -> "Failed", "Target" -> target, "Stage" -> "Image temporary export"|>]
  ];
  If[FileExistsQ[target], Quiet@DeleteFile[target]];
  Quiet@Check[RenameFile[temporary, target], $Failed];
  validFinal = validImageFileQv11[target, settings];
  If[
    TrueQ[validFinal],
    <|"Status" -> "Valid", "Target" -> target|>,
    <|"Status" -> "Failed", "Target" -> target, "Stage" -> "Image final validation"|>
  ]
];

caseOutputFoldersV11[caseRecord_Association, settings_Association] := Module[
  {projectFolder, caseFolder},
  projectFolder = FileNameJoin[{
    Lookup[settings, "OutputRoot"],
    SanitizeFileName[Lookup[caseRecord, "ProjectBaseName"]]
  }];
  caseFolder = FileNameJoin[{
    projectFolder,
    Lookup[caseRecord, "CaseFolderName"]
  }];
  <|
    "ProjectFolder" -> projectFolder,
    "CaseFolder" -> caseFolder,
    "WaterFolder" -> FileNameJoin[{caseFolder, "water_content"}],
    "TimeSeriesFolder" -> FileNameJoin[{caseFolder, "time_series"}]
  |>
];

expectedWXFRecordsV11[caseRecord_Association, settings_Association] := Module[
  {folder, extension},
  folder = Lookup[caseOutputFoldersV11[caseRecord, settings], "TimeSeriesFolder"];
  extension = Lookup[settings, "DataFileFormat", ".wxf"];
  {
    <|"OutputType" -> "WXF", "Kind" -> "RelativeHumidity", "Target" -> FileNameJoin[{folder, "relative_humidity" <> extension}]|>,
    <|"OutputType" -> "WXF", "Kind" -> "Temperature", "Target" -> FileNameJoin[{folder, "temperature" <> extension}]|>,
    <|"OutputType" -> "WXF", "Kind" -> "DewPoint", "Target" -> FileNameJoin[{folder, "dew_point" <> extension}]|>,
    <|"OutputType" -> "WXF", "Kind" -> "LayerWaterContent", "Target" -> FileNameJoin[{folder, "layer_water_content" <> extension}]|>,
    <|"OutputType" -> "WXF", "Kind" -> "TotalWaterContent", "Target" -> FileNameJoin[{folder, "total_water_content" <> extension}]|>
  }
];

expectedImageJobsV11[caseRecord_Association, settings_Association] := Module[
  {folders, caseFolder, waterFolder, sensors, layers, extension, mode, sensorJobs, waterJobs},
  folders = caseOutputFoldersV11[caseRecord, settings];
  caseFolder = Lookup[folders, "CaseFolder"];
  waterFolder = Lookup[folders, "WaterFolder"];
  sensors = Lookup[caseRecord, "Sensors", {}];
  layers = Lookup[caseRecord, "Layers", {}];
  extension = Lookup[settings, "ImageFileFormat", ".jpg"];
  mode = Lookup[settings, "GraphicsMode", "Full"];

  sensorJobs = Flatten@Table[
    With[
      {sensorFolder = FileNameJoin[{caseFolder, Lookup[sensors[[i]], "FolderName"]}]},
      Join[
        {
          <|"OutputType" -> "Image", "Kind" -> "Humidity", "Index" -> i, "Target" -> FileNameJoin[{sensorFolder, "humidity" <> extension}]|>,
          <|"OutputType" -> "Image", "Kind" -> "Temperature", "Index" -> i, "Target" -> FileNameJoin[{sensorFolder, "temperature" <> extension}]|>
        },
        If[
          mode === "Full",
          {
            <|"OutputType" -> "Image", "Kind" -> "DewPoint", "Index" -> i, "Target" -> FileNameJoin[{sensorFolder, "dew_point" <> extension}]|>,
            <|"OutputType" -> "Image", "Kind" -> "MouldHistory", "Index" -> i, "Target" -> FileNameJoin[{sensorFolder, "mould_history" <> extension}]|>,
            <|"OutputType" -> "Image", "Kind" -> "MouldRisk", "Index" -> i, "Target" -> FileNameJoin[{sensorFolder, "mould_risk" <> extension}]|>
          },
          {}
        ]
      ]
    ],
    {i, Length[sensors]}
  ];

  waterJobs = Join[
    Table[
      <|
        "OutputType" -> "Image",
        "Kind" -> "LayerWater",
        "Index" -> i,
        "Target" -> FileNameJoin[{
          waterFolder,
          Lookup[layers[[i]], "PlotFileBase"] <> extension
        }]
      |>,
      {i, Length[layers]}
    ],
    {
      <|
        "OutputType" -> "Image",
        "Kind" -> "TotalWater",
        "Index" -> 1,
        "Target" -> FileNameJoin[{waterFolder, "total_construction" <> extension}]
      |>
    }
  ];

  Join[sensorJobs, waterJobs]
];

expectedOutputRecordsV11[caseRecord_Association, settings_Association] := Join[
  expectedWXFRecordsV11[caseRecord, settings],
  expectedImageJobsV11[caseRecord, settings]
];

outputRecordValidQv11[record_Association, settings_Association] := Switch[
  Lookup[record, "OutputType", ""],
  "WXF", validWXFFileQv11[Lookup[record, "Target"], settings],
  "Image", validImageFileQv11[Lookup[record, "Target"], settings],
  _, False
];

caseOutputAuditV11[caseRecord_Association, settings_Association] := Module[
  {records, audited, validCount},
  records = expectedOutputRecordsV11[caseRecord, settings];
  audited = Map[
    Join[#, <|"Valid" -> outputRecordValidQv11[#, settings]|>] &,
    records
  ];
  validCount = Count[Lookup[audited, "Valid", False], True];
  <|
    "Project" -> Lookup[caseRecord, "ProjectBaseName"],
    "CaseIndex" -> Lookup[caseRecord, "CaseIndex"],
    "CaseName" -> Lookup[caseRecord, "CaseName"],
    "ExpectedOutputCount" -> Length[records],
    "ValidOutputCount" -> validCount,
    "Complete" -> (validCount === Length[records]),
    "InvalidOutputs" -> Select[audited, ! TrueQ[Lookup[#, "Valid", False]] &]
  |>
];

pathAssessmentV11[path_String, outputType_String, settings_Association] := Module[
  {length, directoryLength, components, maxComponent, warnings = {}, errors = {}, enforce},
  length = StringLength[path];
  directoryLength = StringLength[DirectoryName[path]];
  components = FileNameSplit[path];
  maxComponent = If[components === {}, 0, Max[StringLength /@ components]];
  enforce = TrueQ[Lookup[settings, "EnforceLegacyWindowsPathLimit", True]];

  If[length >= Lookup[settings, "PathLengthWarningThreshold", 240],
    AppendTo[warnings, "Path is near the traditional Win32 length limit."]
  ];
  If[enforce && outputType === "File" && length > Lookup[settings, "MaxLegacyWindowsFilePathLength", 259],
    AppendTo[errors, "File path exceeds the configured traditional Win32 file-path limit."]
  ];
  If[enforce && directoryLength > Lookup[settings, "MaxLegacyWindowsDirectoryPathLength", 247],
    AppendTo[errors, "Parent directory exceeds the configured traditional Win32 directory-path limit."]
  ];
  If[enforce && maxComponent > Lookup[settings, "MaxWindowsPathComponentLength", 255],
    AppendTo[errors, "A path component exceeds the configured Windows component-length limit."]
  ];

  <|
    "Path" -> path,
    "Length" -> length,
    "DirectoryLength" -> directoryLength,
    "MaxComponentLength" -> maxComponent,
    "Warnings" -> warnings,
    "Errors" -> errors
  |>
];

outputPathPreflightV11[caseRecords_List, settings_Association] := Module[
  {records, paths, assessments, warnings, errors, longest},
  records = Flatten[expectedOutputRecordsV11[#, settings] & /@ caseRecords, 1];
  paths = Flatten[({Lookup[#, "Target"], Lookup[#, "Target"] <> ".tmp"} &) /@ records];
  paths = DeleteDuplicates[paths];
  assessments = pathAssessmentV11[#, "File", settings] & /@ paths;
  warnings = Select[assessments, Lookup[#, "Warnings", {}] =!= {} &];
  errors = Select[assessments, Lookup[#, "Errors", {}] =!= {} &];
  longest = If[assessments === {}, Missing["NotAvailable"], First@MaximalBy[assessments, Lookup[#, "Length", 0] &]];
  <|
    "PlannedPathCount" -> Length[paths],
    "WarningCount" -> Length[warnings],
    "ErrorCount" -> Length[errors],
    "Warnings" -> warnings,
    "Errors" -> errors,
    "LongestPath" -> longest
  |>
];

loadLIMCurvesV11[settings_Association] := Module[{directory, files},
  directory = Lookup[settings, "LIMCurveDirectory"];
  If[! DirectoryQ[directory], Return[Failure["MissingLIMDirectory", <|"Path" -> directory|>]]];
  files = Sort@Select[FileNames["*", directory], FileType[#] === File &];
  If[files === {}, Return[Failure["NoLIMCurves", <|"Path" -> directory|>]]];
  Quiet@Check[Import /@ files, Failure["LIMImportFailed", <|"Files" -> files|>]]
];

verbosePrintV11[settings_Association, args___] := If[
  TrueQ[Lookup[settings, "VerboseLogging", True]],
  Print[args]
];


(* Graphics are rendered directly to disk inside fresh subkernels. The controller
   receives only small status associations, never Graphics expressions. *)
degreeSymbolV11 = FromCharacterCode[176];
centerDotSymbolV11 = FromCharacterCode[183];
temperatureLabelV11 = Row[{"T, ", degreeSymbolV11, "C"}];
volumetricWaterLabelV11 = Row[{"m, kg", centerDotSymbolV11, Superscript["m", -3]}];
arealWaterLabelV11 = Row[{"m, kg", centerDotSymbolV11, Superscript["m", -2]}];
frameLabelV11 = {
  {"Date", "RH, %"},
  {"Date", temperatureLabelV11},
  {"Date", volumetricWaterLabelV11},
  {temperatureLabelV11, "RH, %"},
  {"Date", temperatureLabelV11},
  {"Date", arealWaterLabelV11}
};
plotStyleDefaultV11 = {Black, Orange};
plotStyleDewV11 = {{Orange, Darker[Red]}, {Gray, Black}};
historyColorPaletteV11 = "BlueGreenYellow";
riskColorPaletteV11 = "GrayYellowTones";
plotLegendLIMHistoryV11 = SwatchLegend[{Gray, Blue, Red}, {"LIM 0", "LIM I", "LIM II"}];
plotLegendLIMRiskV11 = SwatchLegend[{Green, Blue, Red}, {"LIM 0", "LIM I", "LIM II"}];
dashStyleV11 = {{Green, Dashing[{0.02, 0.02}]}, {Blue, Dashing[{0.02, 0.02}]}, {Red, Dashing[{0.02, 0.02}]}};

graphicsRuntimeSettingsV11 = <||>;
caseGraphicsPayloadV11 = <||>;

getFilteredSeriesV11[timeSeries_] := Module[{radius, transposed},
  radius = Max[1, Round[Lookup[graphicsRuntimeSettingsV11, "WindowSize", 0.0025] Length[timeSeries]]];
  transposed = Transpose[timeSeries];
  Transpose[{First[transposed], MeanFilter[Last[transposed], radius]}]
];

niceNumericTicksV11[values_List] := Module[
  {numericValues, minValue, maxValue, span, rawStep, power, fraction, step,
   startTick, stopTick, ticks, decimals},

  numericValues = Select[N@Flatten[values], NumericQ];

  If[numericValues === {}, Return[Automatic]];

  {minValue, maxValue} = MinMax[numericValues];

  If[! NumericQ[minValue] || ! NumericQ[maxValue], Return[Automatic]];

  If[minValue == maxValue,
    Return[{{minValue, NumberForm[minValue, {12, 3}]}}]
  ];

  span = maxValue - minValue;
  rawStep = span/6.;
  power = 10.^Floor[Log10[rawStep]];
  fraction = rawStep/power;

  step = Which[
    fraction <= 1., 1. power,
    fraction <= 2., 2. power,
    fraction <= 5., 5. power,
    True, 10. power
  ];

  startTick = Ceiling[minValue/step] step;
  stopTick = Floor[maxValue/step] step;
  ticks = Quiet@Check[Range[startTick, stopTick, step], {}];

  If[ticks === {},
    ticks = {minValue, maxValue}
  ];

  decimals = Max[0, Ceiling[-Log10[step]]];

  ({#1, NumberForm[#1, {Max[12, decimals + 3], decimals}, NumberPadding -> {"", "0"}]} &) /@ Chop[ticks]
];

explicitDateTicksV11[timeSeries_List] := Module[
  {dates, startDate, endDate, startList, endList, firstMonth, lastMonth,
   monthTicks, format},

  dates = Cases[timeSeries[[All, 1]], _DateObject];

  If[dates === {}, Return[Automatic]];

  startDate = First[dates];
  endDate = Last[dates];
  startList = DateList[startDate];
  endList = DateList[endDate];

  firstMonth = DateObject[{startList[[1]], startList[[2]], 1}];
  lastMonth = DateObject[{endList[[1]], endList[[2]], 1}];

  monthTicks = Quiet@Check[
    DateRange[firstMonth, lastMonth, "Month"],
    {}
  ];

  monthTicks = Select[
    monthTicks,
    AbsoluteTime[#] >= AbsoluteTime[startDate] &&
    AbsoluteTime[#] <= AbsoluteTime[endDate] &
  ];

  If[Length[monthTicks] < 2,
    monthTicks = DeleteDuplicates[{startDate, endDate}]
  ];

  format = Lookup[graphicsRuntimeSettingsV11, "TimeFormat", {"MonthShort", "/", "YearShort"}];

  (*({DateList[#1], DateString[#1, format]} &) /@ monthTicks*)
  ({AbsoluteTime[#1], DateString[#1, format]} &) /@ monthTicks
];

explicitDateFrameTicksV11[timeSeries_List] := If[
  TrueQ[Lookup[graphicsRuntimeSettingsV11, "ExplicitTimeSeriesTicks", True]],
  {
    {niceNumericTicksV11[timeSeries[[All, 2]]], None},
    {explicitDateTicksV11[timeSeries], None}
  },
  Automatic
];

explicitDateFrameTicksV11[series1_List, series2_List] := If[
  TrueQ[Lookup[graphicsRuntimeSettingsV11, "ExplicitTimeSeriesTicks", True]],
  {
    {niceNumericTicksV11[Join[series1[[All, 2]], series2[[All, 2]]]], None},
    {explicitDateTicksV11[series1], None}
  },
  Automatic
];

getDatePlotSimpleFilteredV11[
  timeSeries_,
  label_,
  style_,
  legends_: None,
  frameTicks_: Automatic
] := Module[{resolvedFrameTicks},

  resolvedFrameTicks = If[
    frameTicks === Automatic,
    explicitDateFrameTicksV11[timeSeries],
    frameTicks
  ];

  Show[
    {
      DateListPlot[
        timeSeries,
        Joined -> False,
        PlotStyle -> First[style],
        FrameTicks -> None
      ],
      DateListPlot[
        getFilteredSeriesV11[timeSeries],
        Joined -> True,
        PlotStyle -> Last[style],
        PlotLegends -> legends,
        FrameTicks -> None
      ]
    },
    ImageSize -> Lookup[graphicsRuntimeSettingsV11, "ImageSizeSeries", 500],
    Background -> White,
    FrameLabel -> label,
    LabelStyle -> {Black, Bold, Lookup[graphicsRuntimeSettingsV11, "FontSizeDateSeries", 16]},
    GridLines -> Automatic,
    Frame -> True,
    FrameTicks -> resolvedFrameTicks,
    FrameTicksStyle -> {Black, Bold},
    DateTicksFormat -> Lookup[graphicsRuntimeSettingsV11, "TimeFormat", {"MonthShort", "/", "YearShort"}]
  ]
];

getDatePlotDewPointV11[temperatureSeries_, dewPointSeries_] := Module[{frameTicks},

  frameTicks = explicitDateFrameTicksV11[temperatureSeries, dewPointSeries];

  Show[
    {
      getDatePlotSimpleFilteredV11[
        temperatureSeries,
        frameLabelV11[[2]],
        First[plotStyleDewV11],
        None,
        frameTicks
      ],
      getDatePlotSimpleFilteredV11[
        dewPointSeries,
        frameLabelV11[[2]],
        Last[plotStyleDewV11],
        Placed[
          SwatchLegend[Flatten[Last /@ plotStyleDewV11], {"Temperature", "Dew Point"}],
          Top
        ],
        frameTicks
      ]
    },
    ImageSize -> Lookup[graphicsRuntimeSettingsV11, "ImageSizeSeries", 500],
    FrameTicks -> frameTicks,
    PlotRange -> All
  ]
];

dateFormatV11[date_] := DateString[date, {"Day", "/", "Month", "/", "Year"}];

historyPlotRangeV11[dataset_] := Module[{transposed, temperatures, humidity},
  transposed = Transpose[dataset];
  temperatures = First[transposed];
  humidity = Last[transposed];
  {
    {If[Min[temperatures] > 0, Min[temperatures], 0], If[Max[temperatures] < 40, Max[temperatures], 40]},
    MinMax[humidity]
  }
];

riskPlotRangeV11[dataset_] := Module[{transposed, temperatures, humidity},
  transposed = Transpose[dataset];
  temperatures = First[transposed];
  humidity = Last[transposed];
  {
    {If[Min[temperatures] > 0, Min[temperatures], 0], If[Max[temperatures] < 40, Max[temperatures], 40]},
    {If[Min[humidity] > 40, Min[humidity], 40], Max[humidity]}
  }
];

getMouldHistoryPlotV11[mouldSeries_, startDate_, endDate_, colorTable_, dateLegend_, curvesLIM_] := Show[
  {
    ListPlot[
      Table[
        Style[mouldSeries[[k]], colorTable[[k]]],
        {k, 1, Length[mouldSeries], Max[1, Lookup[graphicsRuntimeSettingsV11, "PointCullingFactor", 1]]}
      ],
      PlotLegends -> dateLegend,
      PlotStyle -> {PointSize[Medium], Opacity[0.8]},
      LabelStyle -> {Black, Bold, Lookup[graphicsRuntimeSettingsV11, "FontSizeMouldPlots", 16]},
      GridLines -> Automatic,
      Background -> None,
      ColorFunctionScaling -> True,
      Frame -> True,
      FrameTicksStyle -> {Black, Bold}
    ],
    ListLinePlot[
      curvesLIM,
      InterpolationOrder -> 2,
      PlotStyle -> {Gray, Blue, Red},
      PlotLegends -> plotLegendLIMHistoryV11
    ]
  },
  PlotRange -> historyPlotRangeV11[mouldSeries],
  PlotLabel -> dateFormatV11[startDate] <> " - " <> dateFormatV11[endDate],
  FrameLabel -> frameLabelV11[[4]],
  ImageSize -> Lookup[graphicsRuntimeSettingsV11, "ImageSizeMould", 500]
];

getMouldRiskPlotV11[mouldSeries_, startDate_, endDate_, curvesLIM_] := Show[
  {
    SmoothDensityHistogram[
      mouldSeries,
      PlotRange -> riskPlotRangeV11[mouldSeries],
      PlotLegends -> BarLegend[
        riskColorPaletteV11,
        LegendMarkerSize -> Lookup[graphicsRuntimeSettingsV11, "LegendSizeRisk", 425]
      ],
      ColorFunction -> riskColorPaletteV11,
      PlotLabel -> dateFormatV11[startDate] <> " - " <> dateFormatV11[endDate],
      MeshStyle -> White,
      MaxRecursion -> 5,
      PerformanceGoal -> "Quality",
      Mesh -> 5,
      GridLines -> Automatic,
      LabelStyle -> {Black, Bold, Lookup[graphicsRuntimeSettingsV11, "FontSizeMouldPlots", 16]},
      FrameLabel -> frameLabelV11[[4]],
      PlotPoints -> 150,
      FrameTicksStyle -> {Black, Bold}
    ],
    ListLinePlot[
      curvesLIM,
      InterpolationOrder -> 1,
      PlotStyle -> dashStyleV11,
      PlotLegends -> plotLegendLIMRiskV11
    ]
  },
  ImageSize -> Lookup[graphicsRuntimeSettingsV11, "ImageSizeRisk", 500],
  LabelStyle -> {Black, Bold, Lookup[graphicsRuntimeSettingsV11, "FontSizeMouldPlots", 16]},
  FrameTicksStyle -> {Black, Bold}
];

renderPlotJobV11[job_Association] := Module[
  {kind, index, target, plot, temperatureSeries, humiditySeries, dewPointSeries, waterSeries, totalWaterSeries,
   mouldSeries, startDate, endDate, colorTable, monthSpan, dateLegend, curvesLIM, result},
  kind = Lookup[job, "Kind"];
  index = Lookup[job, "Index", 1];
  target = Lookup[job, "Target"];
  temperatureSeries = Lookup[caseGraphicsPayloadV11, "TemperatureSeries", {}];
  humiditySeries = Lookup[caseGraphicsPayloadV11, "HumiditySeries", {}];
  dewPointSeries = Lookup[caseGraphicsPayloadV11, "DewPointSeries", {}];
  waterSeries = Lookup[caseGraphicsPayloadV11, "WaterSeries", {}];
  totalWaterSeries = Lookup[caseGraphicsPayloadV11, "WaterTotalSeries", {}];
  startDate = Lookup[caseGraphicsPayloadV11, "StartDate", Missing[]];
  endDate = Lookup[caseGraphicsPayloadV11, "EndDate", Missing[]];
  colorTable = Lookup[caseGraphicsPayloadV11, "ColorTable", {}];
  monthSpan = Lookup[caseGraphicsPayloadV11, "MonthSpan", 0];
  curvesLIM = Lookup[caseGraphicsPayloadV11, "CurvesLIM", {}];

  plot = Quiet@Check[
    Switch[kind,
      "Humidity",
        getDatePlotSimpleFilteredV11[humiditySeries[[index]], frameLabelV11[[1]], plotStyleDefaultV11, None],
      "Temperature",
        getDatePlotSimpleFilteredV11[temperatureSeries[[index]], frameLabelV11[[2]], plotStyleDefaultV11, None],
      "DewPoint",
        getDatePlotDewPointV11[temperatureSeries[[index]], dewPointSeries[[index]]],
      "MouldHistory",
        mouldSeries = Transpose[{temperatureSeries[[index, All, 2]], humiditySeries[[index, All, 2]]}];
        dateLegend = BarLegend[
          {historyColorPaletteV11, {0, monthSpan}},
          LegendMarkerSize -> Lookup[graphicsRuntimeSettingsV11, "LegendSizeMould", 300],
          LegendLabel -> "Months"
        ];
        getMouldHistoryPlotV11[mouldSeries, startDate, endDate, colorTable, dateLegend, curvesLIM],
      "MouldRisk",
        mouldSeries = Transpose[{temperatureSeries[[index, All, 2]], humiditySeries[[index, All, 2]]}];
        getMouldRiskPlotV11[mouldSeries, startDate, endDate, curvesLIM],
      "LayerWater",
        getDatePlotSimpleFilteredV11[waterSeries[[index]], frameLabelV11[[3]], plotStyleDefaultV11, None],
      "TotalWater",
        getDatePlotSimpleFilteredV11[totalWaterSeries, frameLabelV11[[6]], plotStyleDefaultV11, None],
      _,
        $Failed
    ],
    $Failed
  ];

  If[plot === $Failed,
    Return[Join[job, <|"Status" -> "Failed", "Stage" -> "Plot construction"|>]]
  ];

  result = atomicExportImageV11[target, plot, graphicsRuntimeSettingsV11];
  Join[job, KeyTake[result, {"Status", "Stage"}]]
];

launchFreshGraphicsKernelsV11[settings_Association] := Module[
  {count, kernels},

  Quiet[CloseKernels[]];

  count = Lookup[settings, "GraphicsKernelCount", 8];

  Quiet[
    If[
      TrueQ[Lookup[settings, "UseParallelGraphics", True]],
      If[count === Automatic, LaunchKernels[], LaunchKernels[count]],
      LaunchKernels[1]
    ]
  ];

  kernels = Quiet[Kernels[]];

  If[kernels === {}, $Failed, kernels]
];

runGraphicsPassV11[jobs_List, payload_Association, settings_Association] := Module[
  {
    kernels, requestedCount, launchedCount = 0, graphicsSettings,
    launchStart, launchSeconds, renderStart, renderSeconds = 0.,
    evaluations, remaining, waitResult, passResults = {}, passFailed = False,
    completedCount = 0, totalCount, showProgress, progressBody, caseOrdinal,
    caseTotal, caseName
  },

  totalCount = Length[jobs];
  requestedCount = If[
    TrueQ[Lookup[settings, "UseParallelGraphics", True]],
    Lookup[settings, "GraphicsKernelCount", 8],
    1
  ];

  If[
    jobs === {},
    Return[
      <|
        "Results" -> {},
        "GraphicsKernelCountRequested" -> requestedCount,
        "GraphicsKernelCountLaunched" -> 0,
        "GraphicsKernelLaunchTimeSeconds" -> 0.,
        "GraphicsRenderTimeSeconds" -> 0.
      |>
    ]
  ];

  launchStart = AbsoluteTime[];
  kernels = launchFreshGraphicsKernelsV11[settings];
  launchSeconds = AbsoluteTime[] - launchStart;

  If[
    kernels === $Failed || kernels === {},
    Return[
      <|
        "Results" -> (
          Join[#, <|"Status" -> "Failed", "Stage" -> "Kernel launch"|>] & /@ jobs
        ),
        "GraphicsKernelCountRequested" -> requestedCount,
        "GraphicsKernelCountLaunched" -> 0,
        "GraphicsKernelLaunchTimeSeconds" -> launchSeconds,
        "GraphicsRenderTimeSeconds" -> 0.
      |>
    ]
  ];

  launchedCount = Length[kernels];

  If[
    IntegerQ[requestedCount] && launchedCount < requestedCount,
    Print[
      "WARNING: requested ", requestedCount,
      " graphics kernel(s), but only ", launchedCount, " launched."
    ]
  ];

  verbosePrintV11[
    settings,
    "Graphics kernels launched: ",
    launchedCount,
    If[IntegerQ[requestedCount], "/" <> ToString[requestedCount], ""],
    "."
  ];

  caseGraphicsPayloadV11 = payload;
  graphicsSettings = <|
    "WindowSize" -> Lookup[settings, "WindowSize", 0.0025],
    "PointCullingFactor" -> Lookup[settings, "PointCullingFactor", 1],
    "FontSizeDateSeries" -> Lookup[settings, "FontSizeDateSeries", 16],
    "FontSizeMouldPlots" -> Lookup[settings, "FontSizeMouldPlots", 16],
    "ImageSizeSeries" -> Lookup[settings, "ImageSizeSeries", 500],
    "ImageSizeMould" -> Lookup[settings, "ImageSizeMould", 500],
    "ImageSizeRisk" -> Lookup[settings, "ImageSizeRisk", 500],
    "LegendSizeMould" -> Lookup[settings, "LegendSizeMouldFactor", 0.6] Lookup[settings, "ImageSizeMould", 500],
    "LegendSizeRisk" -> Lookup[settings, "LegendSizeRiskFactor", 0.85] Lookup[settings, "ImageSizeRisk", 500],
    "TimeFormat" -> Lookup[settings, "TimeFormat", {"MonthShort", "/", "YearShort"}],
    "ExportResolution" -> Lookup[settings, "ExportResolution", 500],
    "MinimumImageWidth" -> Lookup[settings, "MinimumImageWidth", 100],
    "MinimumImageHeight" -> Lookup[settings, "MinimumImageHeight", 100],
    "MinimumImageByteCount" -> Lookup[settings, "MinimumImageByteCount", 4096],
    "ExplicitTimeSeriesTicks" -> Lookup[settings, "ExplicitTimeSeriesTicks", True]
  |>;
  graphicsRuntimeSettingsV11 = graphicsSettings;

  DistributeDefinitions[
    caseGraphicsPayloadV11,
    graphicsRuntimeSettingsV11,
    degreeSymbolV11,
    centerDotSymbolV11,
    temperatureLabelV11,
    volumetricWaterLabelV11,
    arealWaterLabelV11,
    frameLabelV11,
    plotStyleDefaultV11,
    plotStyleDewV11,
    historyColorPaletteV11,
    riskColorPaletteV11,
    plotLegendLIMHistoryV11,
    plotLegendLIMRiskV11,
    dashStyleV11,
    ensureDirectoryV11,
    fileByteCountSafeV11,
    validImageFileQv11,
    atomicExportImageV11,
    getFilteredSeriesV11,
    niceNumericTicksV11,
    explicitDateTicksV11,
    explicitDateFrameTicksV11,
    getDatePlotSimpleFilteredV11,
    getDatePlotDewPointV11,
    dateFormatV11,
    historyPlotRangeV11,
    riskPlotRangeV11,
    getMouldHistoryPlotV11,
    getMouldRiskPlotV11,
    renderPlotJobV11
  ];

(*  evaluations = Quiet[
    Map[
      Function[
        jobItem,
        ParallelSubmit[{jobItem}, renderPlotJobV11[jobItem]]
      ],
      jobs
    ]
  ];*)
  
  evaluations =
 Quiet@Table[
   ParallelSubmit[
    {jobItem},renderPlotJobV11[jobItem]
    ],{jobItem, jobs}
   ];
  

  If[
    ! ListQ[evaluations] ||
    ! AllTrue[evaluations, MatchQ[#, _EvaluationObject] &],
    Quiet[CloseKernels[]];
    Clear[caseGraphicsPayloadV11, graphicsRuntimeSettingsV11];
    ClearSystemCache[];
    Return[
      <|
        "Results" -> (
          Join[#, <|"Status" -> "Failed", "Stage" -> "Parallel graphics submit"|>] & /@ jobs
        ),
        "GraphicsKernelCountRequested" -> requestedCount,
        "GraphicsKernelCountLaunched" -> launchedCount,
        "GraphicsKernelLaunchTimeSeconds" -> launchSeconds,
        "GraphicsRenderTimeSeconds" -> 0.
      |>
    ]
  ];

  remaining = evaluations;
  showProgress = TrueQ[Lookup[settings, "ShowProgress", True]];
  caseOrdinal = Lookup[settings, "CurrentCaseOrdinal", Missing["NotAvailable"]];
  caseTotal = Lookup[settings, "TotalCaseCount", Missing["NotAvailable"]];
  caseName = Lookup[settings, "CurrentCaseName", ""];

  progressBody := While[
    remaining =!= {},

    waitResult = Quiet[
      WaitNext[remaining]
    ];

    If[
      ! ListQ[waitResult] ||
      Length[waitResult] =!= 3,

      passFailed = True;
      Break[]
    ];

    AppendTo[passResults, waitResult[[1]]];
    remaining = waitResult[[3]];
    completedCount++;
  ];

  renderStart = AbsoluteTime[];

  CheckAbort[
    If[
      showProgress,
      Monitor[
        progressBody,
        Column[
          {
            Row[
              {
                "Case ",
                If[IntegerQ[caseOrdinal], caseOrdinal, "?"],
                "/",
                If[IntegerQ[caseTotal], caseTotal, "?"],
                If[StringQ[caseName] && caseName =!= "", ": " <> caseName, ""]
              }
            ],
            Row[{"Graphics: ", completedCount, " / ", totalCount}],
            ProgressIndicator[completedCount, {0, totalCount}, ImageSize -> 350],
            Row[
              {
                "Elapsed graphics time: ",
                NumberForm[AbsoluteTime[] - renderStart, {Infinity, 1}],
                " s"
              }
            ]
          }
        ]
      ],
      progressBody
    ],

    Quiet[CloseKernels[]];
    Clear[caseGraphicsPayloadV11, graphicsRuntimeSettingsV11];
    ClearSystemCache[];
    Abort[]
  ];

  renderSeconds = AbsoluteTime[] - renderStart;

  Quiet[CloseKernels[]];
  Clear[caseGraphicsPayloadV11, graphicsRuntimeSettingsV11];
  ClearSystemCache[];

  If[
    TrueQ[passFailed] ||
    ! ListQ[passResults] ||
    Length[passResults] =!= Length[jobs],

    passResults = Join[
      Select[passResults, AssociationQ],
      (
        Join[#, <|"Status" -> "Failed", "Stage" -> "Parallel graphics pass"|>] & /@
        Select[
          jobs,
          ! MemberQ[Lookup[Select[passResults, AssociationQ], "Target", {}], Lookup[#, "Target"]] &
        ]
      )
    ]
  ];

  <|
    "Results" -> passResults,
    "GraphicsKernelCountRequested" -> requestedCount,
    "GraphicsKernelCountLaunched" -> launchedCount,
    "GraphicsKernelLaunchTimeSeconds" -> launchSeconds,
    "GraphicsRenderTimeSeconds" -> renderSeconds
  |>
];

runGraphicsJobsWithRetriesV11[jobs_List, payload_Association, settings_Association] := Module[
  {
    pending, completed = {}, passData, passResults, failedTargets,
    retries, retryIndex, lastFailureByTarget = <||>, finalFailures,
    requestedCount, maxLaunched = 0, launchSecondsTotal = 0.,
    renderSecondsTotal = 0., passCount = 0
  },

  pending = jobs;
  retries = Lookup[settings, "FreshKernelRetries", 1];
  requestedCount = If[
    TrueQ[Lookup[settings, "UseParallelGraphics", True]],
    Lookup[settings, "GraphicsKernelCount", 8],
    1
  ];

  For[
    retryIndex = 0,
    retryIndex <= retries && pending =!= {},
    retryIndex++,

    If[
      retryIndex > 0,
      Print[
        "Retrying ", Length[pending],
        " failed image(s) in a fresh graphics-kernel pool (attempt ",
        retryIndex, "/", retries, ")."
      ]
    ];

    passData = runGraphicsPassV11[pending, payload, settings];
    passCount++;

    passResults = Lookup[passData, "Results", {}];
    maxLaunched = Max[maxLaunched, Lookup[passData, "GraphicsKernelCountLaunched", 0]];
    launchSecondsTotal += Lookup[passData, "GraphicsKernelLaunchTimeSeconds", 0.];
    renderSecondsTotal += Lookup[passData, "GraphicsRenderTimeSeconds", 0.];

    completed = Join[
      completed,
      Select[passResults, TrueQ[Lookup[#, "Status", ""] === "Valid"] &]
    ];

    Scan[
      Function[
        failureResult,
        If[
          AssociationQ[failureResult] &&
          ! TrueQ[Lookup[failureResult, "Status", ""] === "Valid"] &&
          StringQ[Lookup[failureResult, "Target", Missing[]]],

          AssociateTo[
            lastFailureByTarget,
            Lookup[failureResult, "Target"] -> failureResult
          ]
        ]
      ],
      passResults
    ];

    failedTargets = Lookup[
      Select[
        passResults,
        ! TrueQ[Lookup[#, "Status", ""] === "Valid"] &
      ],
      "Target",
      {}
    ];

    pending = Select[
      jobs,
      MemberQ[failedTargets, Lookup[#, "Target"]] &
    ];
  ];

  finalFailures = Map[
    Function[
      job,
      Module[{target, lastFailure},
        target = Lookup[job, "Target"];
        lastFailure = Lookup[lastFailureByTarget, target, <||>];

        Join[
          job,
          <|
            "Status" -> "Failed",
            "Stage" -> "Exhausted fresh-kernel retries",
            "LastFailureStage" -> Lookup[lastFailure, "Stage", "Unknown"]
          |>
        ]
      ]
    ],
    pending
  ];

  <|
    "Results" -> Join[completed, finalFailures],
    "GraphicsKernelCountRequested" -> requestedCount,
    "GraphicsKernelCountLaunched" -> maxLaunched,
    "GraphicsKernelLaunchTimeSeconds" -> launchSecondsTotal,
    "GraphicsRenderTimeSeconds" -> renderSecondsTotal,
    "GraphicsPassCount" -> passCount
  |>
];

processCaseV11[caseRecord_Association, settings_Association, curvesLIM_] := Module[
  {
    caseStart, result, projectBase, caseIndex, caseName, ascFileName, ascPath, rows, validation,
    timestamps, sensors, layers, temperatureColumns, humidityColumns, waterColumns, totalWaterColumn,
    temperatureData, humidityData, waterData, waterTotalData, dewPointData,
    temperatureSeries, humiditySeries, dewPointSeries, waterSeries, waterTotalSeries,
    startDate, endDate, monthSpan, colorGrading, colorTable, folders, wxfRecords,
    wxfExpressions, wxfResults, imageJobs, imageJobsToRun, imageSkippedCount, imageResults,
    graphicsRun, payload, restart, skipValid, expectedStart, expectedEnd, timestampWarnings,
    failedOutputs, finalAudit, status, ascImportStart, ascImportTime = 0.,
    dataPreparationStart, dataPreparationTime = 0., wxfExportStart, wxfExportTime = 0.,
    graphicsStageStart, graphicsStageTime = 0., auditStart, auditTime = 0.,
    validWXFCount, validImageCount, caseOrdinal, caseTotal
  },

  caseStart = AbsoluteTime[];
  projectBase = Lookup[caseRecord, "ProjectBaseName"];
  caseIndex = Lookup[caseRecord, "CaseIndex"];
  caseName = Lookup[caseRecord, "CaseName"];
  ascFileName = Lookup[caseRecord, "ExpectedASCFileName"];
  ascPath = FileNameJoin[{Lookup[settings, "DataDirectory"], ascFileName}];
  restart = TrueQ[Lookup[settings, "RestartFailedCases", False]];
  skipValid = restart && TrueQ[Lookup[settings, "SkipValidOutputsOnRestart", True]];
  caseOrdinal = Lookup[settings, "CurrentCaseOrdinal", Missing["NotAvailable"]];
  caseTotal = Lookup[settings, "TotalCaseCount", Missing["NotAvailable"]];

  Print["========================"];
  Print[
    "Processing ",
    If[IntegerQ[caseOrdinal], "case " <> ToString[caseOrdinal] <> "/" <> ToString[caseTotal] <> ": ", ""],
    projectBase, " / C", caseIndex, " / ", caseName
  ];
  verbosePrintV11[settings, "ASC: ", ascFileName];

  If[! FileExistsQ[ascPath],
    result = <|
      "Status" -> "Failed",
      "Project" -> projectBase,
      "CaseIndex" -> caseIndex,
      "CaseName" -> caseName,
      "Issue" -> "ASC file not found",
      "ASCFile" -> ascFileName
    |>;
    Return[Join[result, <|"ProcessingTimeSeconds" -> (AbsoluteTime[] - caseStart)|>]]
  ];

  ascImportStart = AbsoluteTime[];
  rows = Quiet@Check[Import[ascPath, "Table"], $Failed];
  ascImportTime = AbsoluteTime[] - ascImportStart;

  If[rows === $Failed,
    result = <|
      "Status" -> "Failed", "Project" -> projectBase, "CaseIndex" -> caseIndex,
      "CaseName" -> caseName, "Issue" -> "ASC import failed", "ASCFile" -> ascFileName,
      "ASCImportTimeSeconds" -> ascImportTime
    |>;
    Return[Join[result, <|"ProcessingTimeSeconds" -> (AbsoluteTime[] - caseStart)|>]]
  ];

  verbosePrintV11[
    settings,
    "ASC imported: ",
    Length[rows],
    " x ",
    If[rows === {}, 0, Length[First[rows]]],
    " in ",
    NumberForm[ascImportTime, {Infinity, 2}],
    " s."
  ];

  dataPreparationStart = AbsoluteTime[];

  validation = ValidateASCRows[rows, caseRecord];

  If[! TrueQ[Lookup[validation, "Valid", False]],
    dataPreparationTime = AbsoluteTime[] - dataPreparationStart;
    result = <|
      "Status" -> "Failed", "Project" -> projectBase, "CaseIndex" -> caseIndex,
      "CaseName" -> caseName, "Issue" -> "ASC validation failed", "Validation" -> validation,
      "ASCFile" -> ascFileName, "ASCImportTimeSeconds" -> ascImportTime,
      "DataPreparationTimeSeconds" -> dataPreparationTime
    |>;
    Return[Join[result, <|"ProcessingTimeSeconds" -> (AbsoluteTime[] - caseStart)|>]]
  ];

  timestamps = parseTimestampV11 /@ rows[[All, 1]];
  sensors = Lookup[caseRecord, "Sensors", {}];
  layers = Lookup[caseRecord, "Layers", {}];
  temperatureColumns = Lookup[sensors, "TemperatureColumn"];
  humidityColumns = Lookup[sensors, "RelativeHumidityColumn"];
  waterColumns = Lookup[layers, "WaterContentColumn"];
  totalWaterColumn = Lookup[caseRecord, "TotalWaterContentColumn"];

  temperatureData = Transpose[rows[[All, temperatureColumns]]];
  humidityData = Transpose[rows[[All, humidityColumns]]];
  waterData = Transpose[rows[[All, waterColumns]]];
  waterTotalData = rows[[All, totalWaterColumn]];
  dewPointData = MapThread[
    MapThread[dewPointFunctionV11, {#1, #2}] &,
    {temperatureData, humidityData}
  ];

  temperatureSeries = Transpose[{timestamps, #}] & /@ temperatureData;
  humiditySeries = Transpose[{timestamps, #}] & /@ humidityData;
  dewPointSeries = Transpose[{timestamps, #}] & /@ dewPointData;
  waterSeries = Transpose[{timestamps, #}] & /@ waterData;
  waterTotalSeries = Transpose[{timestamps, waterTotalData}];
  startDate = First[timestamps];
  endDate = Last[timestamps];

  folders = caseOutputFoldersV11[caseRecord, settings];
  ensureDirectoryV11[Lookup[folders, "TimeSeriesFolder"]];
  ensureDirectoryV11[Lookup[folders, "WaterFolder"]];

  dataPreparationTime = AbsoluteTime[] - dataPreparationStart;

  verbosePrintV11[
    settings,
    "Data preparation complete in ",
    NumberForm[dataPreparationTime, {Infinity, 2}],
    " s."
  ];

  (* Preserve the exact five downstream WXF names and TimeSeries structure. *)
  wxfRecords = expectedWXFRecordsV11[caseRecord, settings];
  wxfExpressions = <|
    "RelativeHumidity" -> (getTimeSeriesV11 /@ humiditySeries),
    "Temperature" -> (getTimeSeriesV11 /@ temperatureSeries),
    "DewPoint" -> (getTimeSeriesV11 /@ dewPointSeries),
    "LayerWaterContent" -> (getTimeSeriesV11 /@ waterSeries),
    "TotalWaterContent" -> getTimeSeriesV11[waterTotalSeries]
  |>;

  wxfExportStart = AbsoluteTime[];

  wxfResults = Map[
    Function[
      record,
      If[
        skipValid && validWXFFileQv11[Lookup[record, "Target"], settings],
        Join[record, <|"Status" -> "SkippedValid"|>],
        Join[
          record,
          atomicExportWXFV11[
            Lookup[record, "Target"],
            Lookup[wxfExpressions, Lookup[record, "Kind"]],
            settings
          ]
        ]
      ]
    ],
    wxfRecords
  ];

  wxfExportTime = AbsoluteTime[] - wxfExportStart;
  validWXFCount = Count[
    Lookup[wxfResults, "Status", ""],
    "Valid" | "SkippedValid"
  ];

  verbosePrintV11[
    settings,
    "WXF exports valid: ",
    validWXFCount,
    "/",
    Length[wxfRecords],
    " in ",
    NumberForm[wxfExportTime, {Infinity, 2}],
    " s."
  ];

  If[
    AnyTrue[
      wxfResults,
      ! MemberQ[{"Valid", "SkippedValid"}, Lookup[#, "Status", ""]] &
    ],

    Print["ERROR: one or more required WXF exports failed. Graphics for this case will not be generated."];

    auditStart = AbsoluteTime[];
    finalAudit = caseOutputAuditV11[caseRecord, settings];
    auditTime = AbsoluteTime[] - auditStart;

    result = <|
      "Status" -> "Failed",
      "Project" -> projectBase,
      "CaseIndex" -> caseIndex,
      "CaseName" -> caseName,
      "ASCFile" -> ascFileName,
      "Rows" -> Length[rows],
      "Columns" -> Lookup[validation, "ActualColumnCount"],
      "SensorCount" -> Length[sensors],
      "LayerCount" -> Length[layers],
      "OutputFolder" -> Lookup[folders, "CaseFolder"],
      "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
      "WXFResults" -> wxfResults,
      "OutputAudit" -> finalAudit,
      "Warnings" -> {},
      "ASCImportTimeSeconds" -> ascImportTime,
      "DataPreparationTimeSeconds" -> dataPreparationTime,
      "WXFExportTimeSeconds" -> wxfExportTime,
      "GraphicsKernelLaunchTimeSeconds" -> 0.,
      "GraphicsRenderTimeSeconds" -> 0.,
      "GraphicsStageTimeSeconds" -> 0.,
      "OutputAuditTimeSeconds" -> auditTime
    |>;

    Return[Join[result, <|"ProcessingTimeSeconds" -> (AbsoluteTime[] - caseStart)|>]]
  ];

  imageJobs = expectedImageJobsV11[caseRecord, settings];
  imageJobsToRun = If[
    skipValid,
    Select[
      imageJobs,
      ! validImageFileQv11[Lookup[#, "Target"], settings] &
    ],
    imageJobs
  ];
  imageSkippedCount = Length[imageJobs] - Length[imageJobsToRun];

  monthSpan = If[
    Lookup[settings, "GraphicsMode"] === "Full",
    Quiet@Check[QuantityMagnitude[DateDifference[startDate, endDate, "Month"]], 0],
    0
  ];

  colorTable = If[
    Lookup[settings, "GraphicsMode"] === "Full",
    colorGrading = If[Length[timestamps] > 1, Subdivide[0., 1., Length[timestamps] - 1], {0.}];
    Blend[historyColorPaletteV11, #] & /@ colorGrading,
    {}
  ];

  payload = <|
    "TemperatureSeries" -> temperatureSeries,
    "HumiditySeries" -> humiditySeries,
    "DewPointSeries" -> dewPointSeries,
    "WaterSeries" -> waterSeries,
    "WaterTotalSeries" -> waterTotalSeries,
    "StartDate" -> startDate,
    "EndDate" -> endDate,
    "MonthSpan" -> monthSpan,
    "ColorTable" -> colorTable,
    "CurvesLIM" -> If[Lookup[settings, "GraphicsMode"] === "Full", curvesLIM, {}]
  |>;

  verbosePrintV11[
    settings,
    "Graphics jobs: ",
    Length[imageJobsToRun],
    If[
      imageSkippedCount > 0,
      " (" <> ToString[imageSkippedCount] <> " already-valid image(s) skipped)",
      ""
    ],
    "."
  ];

  graphicsStageStart = AbsoluteTime[];
  graphicsRun = runGraphicsJobsWithRetriesV11[imageJobsToRun, payload, settings];
  graphicsStageTime = AbsoluteTime[] - graphicsStageStart;
  imageResults = Lookup[graphicsRun, "Results", {}];

  validImageCount = Count[Lookup[imageResults, "Status", ""], "Valid"];

  verbosePrintV11[
    settings,
    "Graphics valid this run: ",
    validImageCount,
    "/",
    Length[imageJobsToRun],
    " in ",
    NumberForm[graphicsStageTime, {Infinity, 2}],
    " s."
  ];

  expectedStart = xmlDateObjectV11[
    Lookup[caseRecord, "CalculationStart", Missing["NotAvailable"]]
  ];
  expectedEnd = xmlDateObjectV11[
    Lookup[caseRecord, "CalculationEnd", Missing["NotAvailable"]]
  ];

  timestampWarnings = DeleteCases[
    {
      If[
        Head[expectedStart] === DateObject &&
        Abs[AbsoluteTime[startDate] - AbsoluteTime[expectedStart]] > 1,

        "ASC first timestamp differs from the XML calculation start.",
        Nothing
      ],
      If[
        Head[expectedEnd] === DateObject &&
        Abs[AbsoluteTime[endDate] - AbsoluteTime[expectedEnd]] > 1,

        "ASC last timestamp differs from the XML calculation end.",
        Nothing
      ]
    },
    Nothing
  ];

  If[timestampWarnings =!= {}, Print /@ timestampWarnings];

  auditStart = AbsoluteTime[];
  finalAudit = caseOutputAuditV11[caseRecord, settings];
  auditTime = AbsoluteTime[] - auditStart;

  failedOutputs = Lookup[finalAudit, "InvalidOutputs", {}];
  status = If[
    TrueQ[Lookup[finalAudit, "Complete", False]],
    "Processed",
    "Failed"
  ];

  result = <|
    "Status" -> status,
    "Project" -> projectBase,
    "CaseIndex" -> caseIndex,
    "CaseName" -> caseName,
    "ASCFile" -> ascFileName,
    "Rows" -> Length[rows],
    "Columns" -> Lookup[validation, "ActualColumnCount"],
    "SensorCount" -> Length[sensors],
    "LayerCount" -> Length[layers],
    "OutputFolder" -> Lookup[folders, "CaseFolder"],
    "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
    "WXFExpectedCount" -> Length[wxfRecords],
    "ImageExpectedCount" -> Length[imageJobs],
    "ImageRenderedThisRun" -> Length[imageJobsToRun],
    "ImageSkippedValid" -> imageSkippedCount,
    "ImageFailureCount" -> Count[Lookup[imageResults, "Status", ""], "Failed"],
    "ImageFailures" -> Select[imageResults, Lookup[#, "Status", ""] === "Failed" &],
    "FailedOutputCount" -> Length[failedOutputs],
    "Warnings" -> timestampWarnings,
    "OutputAudit" -> finalAudit,
    "GraphicsKernelCountRequested" -> Lookup[graphicsRun, "GraphicsKernelCountRequested", 0],
    "GraphicsKernelCountLaunched" -> Lookup[graphicsRun, "GraphicsKernelCountLaunched", 0],
    "GraphicsPassCount" -> Lookup[graphicsRun, "GraphicsPassCount", 0],
    "ASCImportTimeSeconds" -> ascImportTime,
    "DataPreparationTimeSeconds" -> dataPreparationTime,
    "WXFExportTimeSeconds" -> wxfExportTime,
    "GraphicsKernelLaunchTimeSeconds" -> Lookup[graphicsRun, "GraphicsKernelLaunchTimeSeconds", 0.],
    "GraphicsRenderTimeSeconds" -> Lookup[graphicsRun, "GraphicsRenderTimeSeconds", 0.],
    "GraphicsStageTimeSeconds" -> graphicsStageTime,
    "OutputAuditTimeSeconds" -> auditTime,
    "ProcessingTimeSeconds" -> (AbsoluteTime[] - caseStart)
  |>;

  Print[
    If[status === "Processed", "Completed: ", "FAILED: "],
    Lookup[folders, "CaseFolder"],
    " (",
    NumberForm[Lookup[result, "ProcessingTimeSeconds"], {Infinity, 1}],
    " s)"
  ];
  Print["========================"];

  result
];

checkpointManifestPathsV11[settings_Association] := Module[{base},
  base = FileNameJoin[{
    Lookup[settings, "OutputRoot"],
    Lookup[settings, "PostprocessManifestBaseName", "WUFI_postprocess_manifest_v1_1_1"]
  }];
  <|"WL" -> base <> ".wl", "JSON" -> base <> ".json"|>
];

jsonSafeV11[value_DateObject] := DateString[value, {"ISODate", "T", "Time", "Z"}];
jsonSafeV11[value_Missing] := Null;
jsonSafeV11[value_Failure] := ToString[value, InputForm];
jsonSafeV11[value_Association] := Association[KeyValueMap[#1 -> jsonSafeV11[#2] &, value]];
jsonSafeV11[value_List] := jsonSafeV11 /@ value;
jsonSafeV11[value_] := value;

writeCheckpointManifestV11[manifest_Association, settings_Association] := Module[
  {paths, temporaryWL, temporaryJSON, wlOK, jsonOK},
  If[! TrueQ[Lookup[settings, "WritePostprocessManifest", True]], Return[<||>]];
  paths = checkpointManifestPathsV11[settings];
  temporaryWL = Lookup[paths, "WL"] <> ".tmp";
  temporaryJSON = Lookup[paths, "JSON"] <> ".tmp";
  ensureDirectoryV11[DirectoryName[Lookup[paths, "WL"]]];
  If[FileExistsQ[temporaryWL], Quiet@DeleteFile[temporaryWL]];
  If[FileExistsQ[temporaryJSON], Quiet@DeleteFile[temporaryJSON]];

  wlOK = Quiet@Check[Put[manifest, temporaryWL]; FileExistsQ[temporaryWL], False];
  jsonOK = Quiet@Check[Export[temporaryJSON, jsonSafeV11[manifest], "JSON"]; FileExistsQ[temporaryJSON], False];

  If[TrueQ[wlOK],
    If[FileExistsQ[Lookup[paths, "WL"]], Quiet@DeleteFile[Lookup[paths, "WL"]]];
    Quiet@RenameFile[temporaryWL, Lookup[paths, "WL"]]
  ];
  If[TrueQ[jsonOK],
    If[FileExistsQ[Lookup[paths, "JSON"]], Quiet@DeleteFile[Lookup[paths, "JSON"]]];
    Quiet@RenameFile[temporaryJSON, Lookup[paths, "JSON"]]
  ];
  paths
];

PreflightWUFIPostProcessorV11[userSettings_: <||>] := Module[
  {settings, settingsValidation, manifestPath, manifest, readyProjects, allCases, requestedCases,
   restart, audits, completeCases, missingASC, pathPreflight, limStatus, errors = {}, warnings = {}},
  settings = ResolveWUFIPostProcessorSettingsV11[userSettings];
  settingsValidation = ValidateWUFIPostProcessorSettingsV11[settings];
  warnings = Join[warnings, Lookup[settingsValidation, "Warnings", {}]];
  If[! TrueQ[Lookup[settingsValidation, "Valid", False]],
    Return[
      <|
        "Status" -> "Blocked",
        "Settings" -> settings,
        "Warnings" -> warnings,
        "Errors" -> Lookup[settingsValidation, "Errors", {}]
      |>
    ]
  ];

  manifestPath = Lookup[settings, "ManifestPath"];
  If[! FileExistsQ[manifestPath],
    Return[<|"Status" -> "Blocked", "Settings" -> settings, "Errors" -> {"Manifest not found: " <> manifestPath}|>]
  ];

  manifest = Quiet@Check[LoadWUFIManifest[manifestPath], $Failed];
  If[manifest === $Failed || ! AssociationQ[manifest],
    Return[<|"Status" -> "Blocked", "Settings" -> settings, "Errors" -> {"Could not load the WUFI manifest."}|>]
  ];

  readyProjects = Select[Lookup[manifest, "Projects", {}], TrueQ[Lookup[#, "ReadyForBatch", False]] &];
  allCases = Flatten[Lookup[readyProjects, "Cases", {}], 1];
  restart = TrueQ[Lookup[settings, "RestartFailedCases", False]];
  audits = If[restart, caseOutputAuditV11[#, settings] & /@ allCases, {}];
  completeCases = If[restart, Pick[allCases, Lookup[audits, "Complete", False], True], {}];
  requestedCases = If[restart, Pick[allCases, Lookup[audits, "Complete", False], False], allCases];

  missingASC = Select[
    requestedCases,
    ! FileExistsQ[FileNameJoin[{Lookup[settings, "DataDirectory"], Lookup[#, "ExpectedASCFileName"]}]] &
  ];
  If[missingASC =!= {},
    AppendTo[warnings, ToString[Length[missingASC]] <> " requested ASC file(s) are missing."];
    If[Lookup[settings, "MissingASCPolicy"] === "AbortAll",
      AppendTo[errors, "MissingASCPolicy is AbortAll and one or more requested ASC files are missing."]
    ]
  ];

  pathPreflight = outputPathPreflightV11[requestedCases, settings];
  If[Lookup[pathPreflight, "WarningCount", 0] > 0,
    AppendTo[warnings, "One or more planned output paths are near the configured legacy Windows limit."]
  ];
  If[Lookup[pathPreflight, "ErrorCount", 0] > 0,
    AppendTo[errors, "One or more planned output paths violate the configured Windows path safeguards."]
  ];

  limStatus = If[
    Lookup[settings, "GraphicsMode"] === "Full",
    If[DirectoryQ[Lookup[settings, "LIMCurveDirectory"]], "Available", "Missing"],
    "NotRequiredInSweepMode"
  ];
  If[Lookup[settings, "GraphicsMode"] === "Full" && limStatus === "Missing",
    AppendTo[errors, "Full graphics mode requires the LIM Curves directory."]
  ];

  <|
    "Status" -> If[errors === {}, "Ready", "Blocked"],
    "Version" -> $WUFIPostProcessorVersionV11,
    "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
    "RestartFailedCases" -> restart,
    "ManifestPath" -> manifestPath,
    "ReadyProjectCount" -> Length[readyProjects],
    "ManifestCaseCount" -> Length[allCases],
    "RequestedCaseCount" -> Length[requestedCases],
    "SkippedCompleteCaseCount" -> Length[completeCases],
    "MissingASCCount" -> Length[missingASC],
    "LIMCurves" -> limStatus,
    "PathPreflight" -> pathPreflight,
    "Warnings" -> warnings,
    "Errors" -> errors,
    "Settings" -> settings,
    "Manifest" -> manifest,
    "RequestedCases" -> requestedCases,
    "SkippedCompleteCases" -> completeCases
  |>
];

RunWUFIPostProcessorV11[userSettings_: <||>] := Module[
  {runStart, preflight, settings, requestedCases, curvesLIM, processableCases,
   missingCases, results = {}, caseResult, failurePolicy, checkpoint, failedCount, completedCount,
   postprocessManifest, skippedCompleteCount, status, i, finalResult},

  runStart = AbsoluteTime[];
  preflight = PreflightWUFIPostProcessorV11[userSettings];
  If[Lookup[preflight, "Status", "Blocked"] =!= "Ready",
    Return[Join[preflight, <|"ProcessingTimeSeconds" -> (AbsoluteTime[] - runStart)|>]]
  ];
  settings = Lookup[preflight, "Settings"];
  requestedCases = Lookup[preflight, "RequestedCases", {}];
  skippedCompleteCount = Lookup[preflight, "SkippedCompleteCaseCount", 0];

  Print["WUFI Data Post-Processor ", $WUFIPostProcessorVersionV11];
  Print["Graphics mode: ", Lookup[settings, "GraphicsMode"], "."];
  Print[
    "Graphics execution: fresh subkernel pool per case; ",
    If[TrueQ[Lookup[settings, "UseParallelGraphics", True]], "parallel", "single-subkernel"],
    "."
  ];
  Print[
    "Graphics kernels requested: ",
    If[
      TrueQ[Lookup[settings, "UseParallelGraphics", True]],
      Lookup[settings, "GraphicsKernelCount", 8],
      1
    ],
    "."
  ];
  If[Lookup[preflight, "Warnings", {}] =!= {},
    Print /@ Lookup[preflight, "Warnings", {}]
  ];
  If[TrueQ[Lookup[settings, "RestartFailedCases", False]],
    Print["Restart mode: ", skippedCompleteCount, " already-complete case(s) skipped."]
  ];

  If[requestedCases === {},
    postprocessManifest = <|
      "Version" -> $WUFIPostProcessorVersionV11,
      "Status" -> "NothingToDo",
      "GeneratedAt" -> DateString[Now, {"ISODate", "T", "Time"}],
      "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
      "GraphicsKernelCountRequested" -> If[
        TrueQ[Lookup[settings, "UseParallelGraphics", True]],
        Lookup[settings, "GraphicsKernelCount", 8],
        1
      ],
      "GraphicsKernelCountLaunchedMax" -> 0,
      "RequestedCaseCount" -> 0,
      "SkippedCompleteCaseCount" -> skippedCompleteCount,
      "Results" -> {}
    |>;
    checkpoint = writeCheckpointManifestV11[postprocessManifest, settings];
    Return[Join[
      postprocessManifest,
      <|"PostprocessManifest" -> checkpoint, "ProcessingTimeSeconds" -> (AbsoluteTime[] - runStart)|>
    ]]
  ];

  missingCases = Select[
    requestedCases,
    ! FileExistsQ[FileNameJoin[{Lookup[settings, "DataDirectory"], Lookup[#, "ExpectedASCFileName"]}]] &
  ];
  processableCases = If[
    Lookup[settings, "MissingASCPolicy"] === "ProcessAvailable",
    Select[requestedCases, ! MemberQ[missingCases, #] &],
    requestedCases
  ];

  curvesLIM = If[
    Lookup[settings, "GraphicsMode"] === "Full",
    loadLIMCurvesV11[settings],
    {}
  ];
  If[Head[curvesLIM] === Failure,
    Return[<|
      "Status" -> "Blocked", "Issue" -> "LIM curve loading failed", "Failure" -> curvesLIM,
      "ProcessingTimeSeconds" -> (AbsoluteTime[] - runStart)
    |>]
  ];

  Print["Processing ", Length[processableCases], " case(s)..."];
  failurePolicy = Lookup[settings, "CaseFailurePolicy", "Continue"];

  For[i = 1, i <= Length[processableCases], i++,
    caseResult = processCaseV11[
      processableCases[[i]],
      Join[
        settings,
        <|
          "CurrentCaseOrdinal" -> i,
          "TotalCaseCount" -> Length[processableCases],
          "CurrentCaseName" -> Lookup[processableCases[[i]], "CaseName", ""]
        |>
      ],
      curvesLIM
    ];
    AppendTo[results, caseResult];

    postprocessManifest = <|
      "Version" -> $WUFIPostProcessorVersionV11,
      "Status" -> "Running",
      "GeneratedAt" -> DateString[Now, {"ISODate", "T", "Time"}],
      "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
      "GraphicsKernelCountRequested" -> If[
        TrueQ[Lookup[settings, "UseParallelGraphics", True]],
        Lookup[settings, "GraphicsKernelCount", 8],
        1
      ],
      "GraphicsKernelCountLaunchedMax" -> Max[
        Prepend[Lookup[results, "GraphicsKernelCountLaunched", 0], 0]
      ],
      "RestartFailedCases" -> Lookup[settings, "RestartFailedCases"],
      "RequestedCaseCount" -> Length[requestedCases],
      "SkippedCompleteCaseCount" -> skippedCompleteCount,
      "CompletedSoFar" -> Count[Lookup[results, "Status", ""], "Processed"],
      "FailedSoFar" -> Count[Lookup[results, "Status", ""], "Failed"],
      "Results" -> results
    |>;
    writeCheckpointManifestV11[postprocessManifest, settings];

    If[Lookup[caseResult, "Status", "Failed"] === "Failed" && failurePolicy === "AbortAll",
      Print["CaseFailurePolicy is AbortAll; stopping after failed case."];
      Break[]
    ];
  ];

  Quiet@Check[CloseKernels[], Null];
  failedCount = Count[Lookup[results, "Status", ""], "Failed"];
  completedCount = Count[Lookup[results, "Status", ""], "Processed"];
  status = If[failedCount === 0 && completedCount === Length[processableCases] && missingCases === {}, "Completed", "CompletedWithFailures"];

  postprocessManifest = <|
    "Version" -> $WUFIPostProcessorVersionV11,
    "Status" -> status,
    "GeneratedAt" -> DateString[Now, {"ISODate", "T", "Time"}],
    "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
    "GraphicsKernelCountRequested" -> If[
      TrueQ[Lookup[settings, "UseParallelGraphics", True]],
      Lookup[settings, "GraphicsKernelCount", 8],
      1
    ],
    "GraphicsKernelCountLaunchedMax" -> Max[
      Prepend[Lookup[results, "GraphicsKernelCountLaunched", 0], 0]
    ],
    "RestartFailedCases" -> Lookup[settings, "RestartFailedCases"],
    "RequestedCaseCount" -> Length[requestedCases],
    "ProcessableCaseCount" -> Length[processableCases],
    "SkippedCompleteCaseCount" -> skippedCompleteCount,
    "MissingASCCount" -> Length[missingCases],
    "CompletedCaseCount" -> completedCount,
    "FailedCaseCount" -> failedCount,
    "Results" -> results
  |>;
  checkpoint = writeCheckpointManifestV11[postprocessManifest, settings];

  finalResult = Join[
    postprocessManifest,
    <|
      "OutputRoot" -> Lookup[settings, "OutputRoot"],
      "PostprocessManifest" -> checkpoint,
      "PreflightWarnings" -> Lookup[preflight, "Warnings", {}],
      "ProcessingTimeSeconds" -> (AbsoluteTime[] - runStart)
    |>
  ];
  finalResult
];

RestartFailedWUFIPostProcessorCasesV11[userSettings_: <||>] := RunWUFIPostProcessorV11[
  Join[
    userSettings,
    <|"RestartFailedCases" -> True, "SkipValidOutputsOnRestart" -> True|>
  ]
];

AuditWUFIPostProcessorOutputsV11[userSettings_: <||>] := Module[
  {settings, manifestPath, manifest, readyProjects, cases, audits},
  settings = ResolveWUFIPostProcessorSettingsV11[userSettings];
  manifestPath = Lookup[settings, "ManifestPath"];
  If[! FileExistsQ[manifestPath], Return[Failure["MissingManifest", <|"Path" -> manifestPath|>]]];
  manifest = LoadWUFIManifest[manifestPath];
  readyProjects = Select[Lookup[manifest, "Projects", {}], TrueQ[Lookup[#, "ReadyForBatch", False]] &];
  cases = Flatten[Lookup[readyProjects, "Cases", {}], 1];
  audits = caseOutputAuditV11[#, settings] & /@ cases;
  <|
    "Version" -> $WUFIPostProcessorVersionV11,
    "GraphicsMode" -> Lookup[settings, "GraphicsMode"],
    "CaseCount" -> Length[cases],
    "CompleteCaseCount" -> Count[Lookup[audits, "Complete", False], True],
    "IncompleteCaseCount" -> Count[Lookup[audits, "Complete", False], False],
    "Audits" -> audits
  |>
];
